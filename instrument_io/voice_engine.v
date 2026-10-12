`timescale 1ns/1ps
// Four-key monophonic bring-up voice at 46,875 frames/s. Controls fail neutral.
// Peak output is limited to one quarter scale; this is still a line-level DAC.
module voice_engine #(
    parameter integer RELEASE_FRAMES=235,
    parameter integer ATTACK_STEP=6
)(input wire clk,reset_n,frame_tick,input wire [3:0] btn_n,
  input wire controls_valid,input wire [11:0] axis_x,axis_y,input wire octave_down,
  output wire signed [15:0] sample,output wire active);
    reg [3:0] btn_meta,btn_sync;
    reg [31:0] phase;
    reg [8:0] envelope;
    reg sounding;
    reg [15:0] release_count;
    reg [2:0] held;
    wire [2:0] pressed=!btn_sync[0]?0:!btn_sync[1]?1:!btn_sync[2]?2:!btn_sync[3]?3:4;
    wire [2:0] note=(pressed!=4)?pressed:held;
    wire [31:0] base_inc=note==0?32'd47943389:note==1?32'd53814635:
                             note==2?32'd60404887:32'd71833926;
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
    localparam [8:0] ATTACK_VALUE=ATTACK_STEP;
    localparam [8:0] ATTACK_LIMIT=9'd256-ATTACK_VALUE;
    wire [9:0] attack_sum={1'b0,envelope}+{1'b0,ATTACK_VALUE};
    wire signed [15:0] saw=$signed(phase[31:16]);
    wire signed [25:0] blend_sum=triangle*$signed({1'b0,triangle_weight})+
                                saw*$signed({2'b00,mix});
    // Bounds of the two weighted 16-bit waves keep the retained result in range.
    wire signed [15:0] blend=$signed(blend_sum[23:8]);
    wire signed [26:0] gain_product=blend*$signed({1'b0,envelope});
    assign sample=$signed(gain_product[25:10]);
    assign active=(envelope!=0);
    always @(posedge clk) begin
        if(!reset_n) begin
            btn_meta<=15;btn_sync<=15;phase<=0;envelope<=0;
            sounding<=0;release_count<=0;held<=0;
        end else begin
            btn_meta<=btn_n;btn_sync<=btn_meta;
            if(frame_tick) begin
                if(pressed!=4) begin sounding<=1;release_count<=0;held<=pressed;end
                else if(sounding) begin
                    if(release_count==RELEASE_FRAMES) sounding<=0;
                    else release_count<=release_count+1'b1;
                end
                if(sounding) begin
                    if(envelope>=ATTACK_LIMIT) envelope<=9'd256;
                    else envelope<=attack_sum[8:0];
                end else if(envelope!=0) envelope<=envelope-1'b1;
                phase<=phase+phase_inc;
            end
        end
    end
endmodule
