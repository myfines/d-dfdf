`timescale 1ns/1ps
// Expression never generates a note or amplifies beyond the local signal.
module gesture_expression(input wire clk,reset_n,frame_tick,active,
 input wire [9:0] pinch,y,output wire [7:0] gain,output reg [11:0] color);
 wire [9:0] bounded_pinch=pinch>1000?10'd1000:pinch;
 wire [9:0] bounded_y=y>1000?10'd1000:y;
 wire [18:0] gain_product=bounded_pinch*9'd261+19'd512;
 wire [20:0] color_product=bounded_y*11'd1690;
 wire [11:0] target_color=color_product[20:10];
 assign gain=active?gain_product[17:10]:8'd255;
 always @(posedge clk)begin
  if(!reset_n)color<=825;
  else if(frame_tick)begin
   if(!active)color<=825;
   else if(color+12'd4<target_color)color<=color+12'd4;
   else if(color>target_color+12'd4)color<=color-12'd4;
   else color<=target_color;
  end
 end
endmodule
