`timescale 1ns/1ps
module tb_pages;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;
reg [3:0] keys=15;reg [1:0] page=0;
wire signed [15:0] sample;wire active;
voice_engine #(.ATTACK_STEP(128),.RELEASE_FRAMES(3)) dut(clk,rst,tick,keys,1'b0,12'd825,12'd0,1'b0,sample,active,1'b0,2'd1,9'd6,16'd16,9'd160,16'd4,page);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
real freq;integer n,p,k,c;reg signed [15:0] prev;
initial begin
repeat(3)@(negedge clk);rst=1;
for(p=0;p<3;p=p+1)begin
page=p;
for(k=0;k<4;k=k+1)begin
 keys=15;repeat(1200)frame();keys=~(4'b0001<<k);repeat(500)frame();prev=sample;c=0;
 for(n=0;n<5000;n=n+1)begin frame();if(prev<0 && sample>=0)c=c+1;prev=sample;end
 case(p*4+k)
 0:freq=523.251;1:freq=587.330;2:freq=659.255;3:freq=783.991;
 4:freq=554.365;5:freq=622.254;6:freq=698.456;7:freq=739.989;
 8:freq=830.609;9:freq=880;10:freq=932.328;11:freq=987.767;
 endcase
 if($itor(c)<freq*5000/46875-1.1 || $itor(c)>freq*5000/46875+1.1)$fatal(1,"Wrong page note %d: %d",p*4+k,c);
end end
$display("PASS pages: all 12 chromatic pitches selectable with four keys");$finish;
end
endmodule
