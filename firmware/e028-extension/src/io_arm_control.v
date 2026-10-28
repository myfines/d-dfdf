`timescale 1ns/1ps
module io_arm_control(input wire clk,reset_n,sw_n,input wire [3:0] keys_n,
 output reg armed,command_in_progress);
 reg previous_sw;
 always @(posedge clk)begin
  if(!reset_n)begin armed<=0;command_in_progress<=0;previous_sw<=1;end
  else begin
   previous_sw<=sw_n;
   if(previous_sw && !sw_n)command_in_progress<=keys_n==4'b1001;
   if(!previous_sw && sw_n)begin
    if(command_in_progress)armed<=!armed;
    command_in_progress<=0;
   end
  end
 end
endmodule
