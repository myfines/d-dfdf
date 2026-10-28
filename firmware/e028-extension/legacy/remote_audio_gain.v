`timescale 1ns/1ps
// Slew one gain unit per audio frame (~5.4ms full-scale); never increases peak.
module remote_audio_gain(input wire clk,reset_n,frame_tick,input wire [7:0] target,
 input wire signed [15:0] sample,output wire signed [15:0] result);
 reg [7:0] gain;wire signed [24:0] product=sample*$signed({1'b0,gain});
 assign result=gain==255?sample:product[23:8];
 always @(posedge clk)if(!reset_n)gain<=255;else if(frame_tick)begin
  if(gain<target)gain<=gain+1'b1;else if(gain>target)gain<=gain-1'b1;
 end
endmodule
