`timescale 1ns/1ps
// 32 independent phases/envelopes, 96 fabric cycles per stereo frame.
// Time slots share arithmetic but never share oscillator state.
module spectrum_bank(input wire clk,reset_n,frame_tick,input wire [31:0] gates,
 output reg signed [15:0] sample,output reg active,output wire busy);
 localparam IDLE=0,READ=1,CALC=2,ACCUM=3;
 reg [1:0] state;reg [4:0] index;
 reg [31:0] phases[0:31];reg [8:0] levels[0:31];
 reg [31:0] phase_reg,gate_frame;reg [8:0] level_reg;
 reg signed [30:0] sum;reg frame_active;
 wire signed [15:0] wave;
 wave_source oscillator(phase_reg,2'd1,wave);
 wire signed [25:0] product=wave*$signed({1'b0,level_reg});
 wire signed [30:0] next_sum=sum+{{5{product[25]}},product};
 wire [8:0] next_level=gate_frame[index]?(level_reg>=250 ?9'd256:level_reg+9'd6):
                                      (level_reg==0 ?9'd0:level_reg-1'b1);
 assign busy=state!=IDLE;
 function [31:0] increment;
 input [4:0] n;
 begin case(n)
  5'd0:increment=32'd11819750; // 129 Hz
  5'd1:increment=32'd14660155; // 160 Hz
  5'd2:increment=32'd17500560; // 191 Hz
  5'd3:increment=32'd20340965; // 222 Hz
  5'd4:increment=32'd23181370; // 253 Hz
  5'd5:increment=32'd26021775; // 284 Hz
  5'd6:increment=32'd28862180; // 315 Hz
  5'd7:increment=32'd31702585; // 346 Hz
  5'd8:increment=32'd34542990; // 377 Hz
  5'd9:increment=32'd37383395; // 408 Hz
  5'd10:increment=32'd40223800; // 439 Hz
  5'd11:increment=32'd43064205; // 470 Hz
  5'd12:increment=32'd45904610; // 501 Hz
  5'd13:increment=32'd48745015; // 532 Hz
  5'd14:increment=32'd51585421; // 563 Hz
  5'd15:increment=32'd54425826; // 594 Hz
  5'd16:increment=32'd57266231; // 625 Hz
  5'd17:increment=32'd60106636; // 656 Hz
  5'd18:increment=32'd62947041; // 687 Hz
  5'd19:increment=32'd65787446; // 718 Hz
  5'd20:increment=32'd68627851; // 749 Hz
  5'd21:increment=32'd71468256; // 780 Hz
  5'd22:increment=32'd74308661; // 811 Hz
  5'd23:increment=32'd77149066; // 842 Hz
  5'd24:increment=32'd79989471; // 873 Hz
  5'd25:increment=32'd82829876; // 904 Hz
  5'd26:increment=32'd85670281; // 935 Hz
  5'd27:increment=32'd88510686; // 966 Hz
  5'd28:increment=32'd91351091; // 997 Hz
  5'd29:increment=32'd94191496; // 1028 Hz
  5'd30:increment=32'd97031901; // 1059 Hz
  5'd31:increment=32'd99872306; // 1090 Hz
  default:increment=0;
 endcase end
 endfunction
 integer k;
 always @(posedge clk)begin
  if(!reset_n)begin
   state<=IDLE;index<=0;sample<=0;active<=0;phase_reg<=0;level_reg<=0;gate_frame<=0;sum<=0;frame_active<=0;
   for(k=0;k<32;k=k+1)begin phases[k]<=0;levels[k]<=0;end
  end else case(state)
   IDLE:if(frame_tick && (gates!=0 || active))begin gate_frame<=gates;sum<=0;frame_active<=0;index<=0;state<=READ;end
   READ:begin phase_reg<=phases[index];level_reg<=levels[index];state<=CALC;end
   CALC:begin phases[index]<=phase_reg+increment(index);levels[index]<=next_level;state<=ACCUM;end
   ACCUM:begin
    sum<=next_sum;frame_active<=frame_active || level_reg!=0;
    if(index==31)begin sample<=next_sum[30:15];active<=frame_active || level_reg!=0;state<=IDLE;end
    else begin index<=index+1'b1;state<=READ;end
   end
   default:state<=IDLE;
  endcase
 end
endmodule
