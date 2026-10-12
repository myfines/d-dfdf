`timescale 1ns/1ps
// Four independent voices at 46,875 frames/s. Controls fail neutral.
// Peak output is limited to one quarter scale; this is still a line-level DAC.
module voice_lane #(
    parameter integer RELEASE_FRAMES=235,
    parameter integer ATTACK_STEP=6,
    parameter [31:0] NOTE_INCREMENT=32'd47943389,
    parameter [31:0] PAGE1_INCREMENT=32'd50794208,PAGE2_INCREMENT=32'd76105296
)(input wire clk,reset_n,frame_tick,input wire key_n,
  input wire controls_valid,input wire [11:0] axis_x,axis_y,input wire octave_down,
  output wire signed [15:0] sample,output wire active,
  input wire runtime_enable,input wire [1:0] timbre,input wire [8:0] attack_config,
  input wire [15:0] decay_config,input wire [8:0] sustain_config,input wire [15:0] release_config,
  input wire [1:0] note_page,input wire external_enable,input wire [31:0] external_increment,
  input wire force_trigger);
    reg btn_meta,btn_sync;
    reg [31:0] phase;
    wire [8:0] envelope;
    reg sounding;
    reg [15:0] release_count;
    wire [31:0] base_inc=external_enable?external_increment:
        note_page==1 ?PAGE1_INCREMENT:note_page==2 ?PAGE2_INCREMENT:NOTE_INCREMENT;
    wire [11:0] bounded_x=axis_x>1650?12'd1650:axis_x;
    wire signed [12:0] delta=$signed({1'b0,bounded_x})-13'sd825;
    wire signed [12:0] bend=(!controls_valid || (delta>=-25 && delta<=25))?13'sd0:delta;
    wire signed [45:0] bend_product=$signed({1'b0,base_inc})*bend;
    wire signed [45:0] adjusted=$signed({1'b0,base_inc})+(bend_product>>>13);
    wire [31:0] phase_inc=octave_down?(adjusted[31:0]>>1):adjusted[31:0];
    wire [19:0] color_scaled=axis_y*8'd159;
    wire [7:0] mix=(!controls_valid)?8'd0:(color_scaled[19:10]>255)?8'd255:color_scaled[17:10];
    wire [8:0] triangle_weight=9'd256-{1'b0,mix};
    wire signed [15:0] triangle;
    wave_source oscillator(phase,timbre,triangle);
    reg [8:0] note_attack,note_sustain;
    reg [15:0] note_decay,note_release;
    localparam [8:0] DEFAULT_ATTACK=ATTACK_STEP;
    wire signed [15:0] saw=$signed(phase[31:16]);
    wire signed [25:0] blend_sum=triangle*$signed({1'b0,triangle_weight})+
                                saw*$signed({2'b00,mix});
    // Bounds of the two weighted 16-bit waves keep the retained result in range.
    wire signed [15:0] blend=$signed(blend_sum[23:8]);
    wire signed [26:0] gain_product=blend*$signed({1'b0,envelope});
    assign sample=$signed(gain_product[25:10]);
    adsr_runtime env(clk,reset_n,frame_tick,sounding,
        note_attack,note_decay,note_sustain,note_release,envelope,active);
    always @(posedge clk) begin
        if(!reset_n) begin
            btn_meta<=1;btn_sync<=1;phase<=0;
            sounding<=0;release_count<=0;
            note_attack<=DEFAULT_ATTACK;note_decay<=16;note_sustain<=160;note_release<=4;
        end else begin
            btn_meta<=key_n;btn_sync<=btn_meta;
            if(frame_tick) begin
                if(force_trigger)begin sounding<=0;release_count<=0;end
                else if(!btn_sync) begin
                    sounding<=1;release_count<=0;
                    if(!sounding)begin
                        note_attack<=runtime_enable?attack_config:DEFAULT_ATTACK;
                        note_decay<=runtime_enable?decay_config:16'd16;
                        note_sustain<=runtime_enable?sustain_config:9'd160;
                        note_release<=runtime_enable?release_config:16'd4;
                    end
                end
                else if(sounding) begin
                    if(release_count==RELEASE_FRAMES) sounding<=0;
                    else release_count<=release_count+1'b1;
                end
                if(sounding || envelope!=0 || !btn_sync)phase<=phase+phase_inc;
            end
        end
    end
endmodule

// Each lane retains its note index; /4 reserves headroom even with all keys held.
module voice_engine #(
    parameter integer RELEASE_FRAMES=235,
    parameter integer ATTACK_STEP=6
)(input wire clk,reset_n,frame_tick,input wire [3:0] btn_n,
  input wire controls_valid,input wire [11:0] axis_x,axis_y,input wire octave_down,
  output wire signed [15:0] sample,output wire active,
  input wire runtime_enable,input wire [1:0] timbre,input wire [8:0] attack_config,
  input wire [15:0] decay_config,input wire [8:0] sustain_config,input wire [15:0] release_config,
  input wire [1:0] note_page,input wire external_enable,input wire [3:0] external_keys_n,
  input wire [11:0] external_notes,input wire [3:0] external_triggers);
    function [31:0] optical_increment;
        input [1:0] page;input [2:0] note;
        begin case({page,note})
            5'd0:optical_increment=32'd47943392;
            5'd1:optical_increment=32'd53814638;
            5'd2:optical_increment=32'd60404889;
            5'd3:optical_increment=32'd63996750;
            5'd4:optical_increment=32'd71833923;
            5'd5:optical_increment=32'd80630853;
            5'd6:optical_increment=32'd90505072;
            5'd7:optical_increment=32'd95886784;
            5'd8:optical_increment=32'd47943392;
            5'd9:optical_increment=32'd50794254;
            5'd10:optical_increment=32'd53814638;
            5'd11:optical_increment=32'd57014623;
            5'd12:optical_increment=32'd60404889;
            5'd13:optical_increment=32'd63996750;
            5'd14:optical_increment=32'd67802195;
            5'd15:optical_increment=32'd71833923;
            5'd16:optical_increment=32'd71833923;
            5'd17:optical_increment=32'd76105391;
            5'd18:optical_increment=32'd80630853;
            5'd19:optical_increment=32'd85425413;
            5'd20:optical_increment=32'd90505072;
            5'd21:optical_increment=32'd95886784;
            5'd22:optical_increment=32'd101588509;
            5'd23:optical_increment=32'd107629276;
            default:optical_increment=32'd47943389;
        endcase end
    endfunction
    wire signed [15:0] lane_sample[0:3];
    wire [3:0] lane_active;
    genvar n;
    generate for(n=0;n<4;n=n+1) begin: voices
        reg [31:0] optical_inc;
        always @(posedge clk)begin
            if(!reset_n)optical_inc<=32'd47943389;
            else if(frame_tick && external_enable)optical_inc<=optical_increment(note_page,external_notes[n*3+:3]);
        end
        localparam [31:0] NOTE_INC=n==0?32'd47943389:n==1?32'd53814635:
                                     n==2?32'd60404887:32'd71833926;
        localparam [31:0] PAGE1_INC=n==0 ?32'd50794254:n==1 ?32'd57014623:n==2 ?32'd63996750:32'd67802195;
        localparam [31:0] PAGE2_INC=n==0 ?32'd76105391:n==1 ?32'd80630853:n==2 ?32'd85425413:32'd90505072;
        voice_lane #(.RELEASE_FRAMES(RELEASE_FRAMES),.ATTACK_STEP(ATTACK_STEP),
                     .NOTE_INCREMENT(NOTE_INC),.PAGE1_INCREMENT(PAGE1_INC),.PAGE2_INCREMENT(PAGE2_INC)) lane(
            clk,reset_n,frame_tick,external_enable?external_keys_n[n]:btn_n[n],controls_valid,axis_x,axis_y,octave_down,
            lane_sample[n],lane_active[n],runtime_enable,timbre,
            attack_config,decay_config,sustain_config,release_config,note_page,
            external_enable,optical_inc,external_enable && external_triggers[n]);
    end endgenerate
    wire signed [17:0] mix_sum=
        $signed({{2{lane_sample[0][15]}},lane_sample[0]})+
        $signed({{2{lane_sample[1][15]}},lane_sample[1]})+
        $signed({{2{lane_sample[2][15]}},lane_sample[2]})+
        $signed({{2{lane_sample[3][15]}},lane_sample[3]});
    assign sample=$signed(mix_sum[17:2]);
    assign active=|lane_active;
endmodule
