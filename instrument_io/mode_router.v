`timescale 1ns/1ps
// Fade-out, switch at zero, fade-in. Output register isolates the gain multiplier.
module mode_router #(parameter integer STEP=8)(input wire clk,reset_n,frame_tick,
 input wire [1:0] desired,input wire signed [15:0] keyboard_sample,bank_sample,
 output reg signed [15:0] sample);
 reg [1:0] current;reg [8:0] gain;
 localparam [8:0] GAIN_STEP=STEP,LIMIT=256-STEP;
 wire signed [15:0] source=current==2 ?bank_sample:current==1 ?16'sd0:keyboard_sample;
 wire signed [25:0] product=source*$signed({1'b0,gain});
 always @(posedge clk)begin
  if(!reset_n)begin current<=0;gain<=0;sample<=0;end
  else if(frame_tick)begin
   sample<=product[23:8];
   if(current!=desired)begin
    if(gain==0)current<=desired;
    else gain<=gain<=GAIN_STEP?9'd0:gain-GAIN_STEP;
   end else if(gain<LIMIT)gain<=gain+GAIN_STEP;
   else gain<=256;
  end
 end
endmodule
