`timescale 1ns/1ps
module tb_gesture_expression;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,frame_tick=1,active=0;reg [9:0] pinch=0,y=0;
wire [7:0] gain;wire [11:0] color;
gesture_expression dut(clk,reset_n,frame_tick,active,pinch,y,gain,color);
initial begin
 repeat(3)@(negedge clk);reset_n=1;
 repeat(3)@(negedge clk);if(gain!=255)$fatal(1,"inactive must preserve local gain");
 active=1;pinch=1000;y=1000;repeat(500)@(negedge clk);
 if(gain!=255||color<1648||color>1650)$fatal(1,"full gesture bounds");
 pinch=0;y=0;repeat(500)@(negedge clk);
 if(gain!=0||color!=0)$fatal(1,"closed gesture");
 active=0;@(negedge clk);if(gain!=255)$fatal(1,"lost hand local fallback");
 active=1;pinch=1023;y=1023;repeat(500)@(negedge clk);
 if(gain!=255||color>1650)$fatal(1,"defensive clamp");
 $display("PASS gesture expression: neutral fallback, bounds, smoothing");$finish;
end
endmodule
