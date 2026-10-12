`timescale 1ns/1ps
module tb_poly;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;
reg [3:0] keys=15;wire signed [15:0] mixed,c,g;wire active,ac,ag;
voice_engine #(.RELEASE_FRAMES(3),.ATTACK_STEP(128)) dut(clk,rst,tick,keys,1'b0,12'd825,12'd0,1'b0,mixed,active);
voice_engine #(.RELEASE_FRAMES(3),.ATTACK_STEP(128)) refc(clk,rst,tick,{3'b111,keys[0]},1'b0,12'd825,12'd0,1'b0,c,ac);
voice_engine #(.RELEASE_FRAMES(3),.ATTACK_STEP(128)) refg(clk,rst,tick,{keys[3],3'b111},1'b0,12'd825,12'd0,1'b0,g,ag);
integer i,expected;
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
initial begin
repeat(5)@(negedge clk);rst=1;keys=4'b0110;
repeat(400)frame();
for(i=0;i<1000;i=i+1)begin
frame();expected=$signed(c)+$signed(g);
if(mixed<expected-1 || mixed>expected+1)$fatal(1,"Chord lost a held voice: got %d expected sum %d",mixed,expected);
end
keys=4'b0111;repeat(400)frame();
for(i=0;i<300;i=i+1)begin frame();if(mixed!==g)$fatal(1,"Releasing C interrupted sustained G");end
keys=0;repeat(400)frame();
for(i=0;i<5000;i=i+1)begin frame();if(mixed>8192 || mixed< -8192)$fatal(1,"Four voice mix exceeds quarter scale");end
keys=15;repeat(400)frame();if(mixed!==0 || active)$fatal(1,"All voices must release to silence");
$display("PASS poly: independent C+G superposition, selective release, four voice headroom, silence");$finish;
end
initial begin #2000000;$fatal(1,"poly timeout");end
endmodule
