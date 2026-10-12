`timescale 1ns/1ps
module tb_effect;
reg clk=0,rst=0,tick=0,en=1;always #5 clk=~clk;
reg signed [15:0] dry=0;wire signed [15:0] wet;
short_delay #(.DEPTH(8)) dut(clk,rst,tick,en,dry,wet);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
integer i;
initial begin
repeat(3)@(negedge clk);rst=1;repeat(9)frame();if(wet!==0)$fatal(1,"Uninitialized memory leaked");
dry=8000;frame();dry=0;
for(i=0;i<7;i=i+1)begin frame();if(wet!==0)$fatal(1,"Echo arrived early");end
frame();if(wet!==2000)$fatal(1,"Echo delay or gain wrong %d",wet);
frame();if(wet!==0)$fatal(1,"Echo pulse too long");
en=0;dry=-8192;#1;if(wet!==dry)$fatal(1,"Bypass wrong");
$display("PASS delay: initialized silence, delayed impulse, gain, exact bypass");$finish;
end
endmodule
