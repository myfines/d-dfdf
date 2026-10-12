`timescale 1ns/1ps
// Four independent voices at 46,875 frames/s. Controls fail neutral.
// Peak output is limited to one quarter scale; this is still a line-level DAC.
module voice_lane #(
    parameter integer RELEASE_FRAMES=235,
    parameter integer ATTACK_STEP=6,
    parameter [31:0] NOTE_INCREMENT=32'd47943389
)(input wire clk,reset_n,frame_tick,input wire key_n,
  input wire controls_valid,input wire [11:0] axis_x,axis_y,input wire octave_down,
  output wire signed [15:0] sample,output wire active);
    reg btn_meta,btn_sync;
    reg [31:0] phase;
    wire [8:0] envelope;
    reg sounding;
    reg [15:0] release_count;
    wire [31:0] base_inc=NOTE_INCREMENT;
    wire [11:0] bounded_x=axis_x>1650?12'd1650:axis_x;
    wire signed [12:0] delta=$signed({1'b0,bounded_x})-13'sd825;
    wire signed [12:0] bend=(!controls_valid || (delta>=-25 && delta<=25))?13'sd0:delta;
    wire signed [45:0] bend_product=$signed({1'b0,base_inc})*bend;
    wire signed [45:0] adjusted=$signed({1'b0,base_inc})+(bend_product>>>13);
    wire [31:0] phase_inc=octave_down?(adjusted[31:0]>>1):adjusted[31:0];
    wire [19:0] color_scaled=axis_y*8'd159;
    wire [7:0] mix=(!controls_valid)?8'd0:(color_scaled[19:10]>255)?8'd255:color_scaled[17:10];
    wire [8:0] triangle_weight=9'd256-{1'b0,mix};
    wire [14:0] triangle_magnitude=phase[30]?~phase[29:15]:phase[29:15];
    // Folding the phase bits gives a continuous two's-complement triangle,
    // with range -32768..32767 and no arithmetic narrowing.
    wire signed [15:0] triangle=$signed({phase[31],triangle_magnitude^{15{phase[31]}}});
    wire signed [15:0] saw=$signed(phase[31:16]);
    wire signed [25:0] blend_sum=triangle*$signed({1'b0,triangle_weight})+
                                saw*$signed({2'b00,mix});
    // Bounds of the two weighted 16-bit waves keep the retained result in range.
    wire signed [15:0] blend=$signed(blend_sum[23:8]);
    wire signed [26:0] gain_product=blend*$signed({1'b0,envelope});
    assign sample=$signed(gain_product[25:10]);
    adsr_envelope #(.ATTACK_STEP(ATTACK_STEP)) env(
        clk,reset_n,frame_tick,sounding,envelope,active);
    always @(posedge clk) begin
        if(!reset_n) begin
            btn_meta<=1;btn_sync<=1;phase<=0;
            sounding<=0;release_count<=0;
        end else begin
            btn_meta<=key_n;btn_sync<=btn_meta;
            if(frame_tick) begin
                if(!btn_sync) begin sounding<=1;release_count<=0;end
                else if(sounding) begin
                    if(release_count==RELEASE_FRAMES) sounding<=0;
                    else release_count<=release_count+1'b1;
                end
                phase<=phase+phase_inc;
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
  output wire signed [15:0] sample,output wire active);
    wire signed [15:0] lane_sample[0:3];
    wire [3:0] lane_active;
    genvar n;
    generate for(n=0;n<4;n=n+1) begin: voices
        localparam [31:0] NOTE_INC=n==0?32'd47943389:n==1?32'd53814635:
                                     n==2?32'd60404887:32'd71833926;
        voice_lane #(.RELEASE_FRAMES(RELEASE_FRAMES),.ATTACK_STEP(ATTACK_STEP),
                     .NOTE_INCREMENT(NOTE_INC)) lane(
            clk,reset_n,frame_tick,btn_n[n],controls_valid,axis_x,axis_y,octave_down,
            lane_sample[n],lane_active[n]);
    end endgenerate
    wire signed [17:0] mix_sum=
        $signed({{2{lane_sample[0][15]}},lane_sample[0]})+
        $signed({{2{lane_sample[1][15]}},lane_sample[1]})+
        $signed({{2{lane_sample[2][15]}},lane_sample[2]})+
        $signed({{2{lane_sample[3][15]}},lane_sample[3]});
    assign sample=$signed(mix_sum[17:2]);
    assign active=|lane_active;
endmodule
