`timescale 1ns/1ps
module tb_remote_gain;
reg clk=0;always #5 clk=~clk;reg reset_n=0,frame=1;reg [7:0] target=255;reg signed [15:0] sample=8192;wire signed [15:0] result;
remote_audio_gain dut(clk,reset_n,frame,target,sample,result);
initial begin repeat(3)@(negedge clk);reset_n=1;#1;if(result!=sample)$fatal(1,"Default gain not transparent");
target=0;repeat(260)@(negedge clk);if(result!=0)$fatal(1,"Mute failed");
target=255;repeat(260)@(negedge clk);sample=-8192;#1;if(result!=-8192)$fatal(1,"Signed/unity gain failed");
$display("PASS gain unity, slew, mute, negative sample");$finish;end
endmodule
