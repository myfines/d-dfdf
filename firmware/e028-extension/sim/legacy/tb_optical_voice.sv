`timescale 1ns/1ps
module tb_optical_voice;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;reg [7:0] keys=255;
wire [3:0] slots,triggers;wire [11:0] notes;wire signed [15:0] sample;wire active;
optical_key_allocator allocator(clk,rst,tick,keys,slots,notes,triggers);
voice_engine #(.ATTACK_STEP(128),.RELEASE_FRAMES(3)) dut(clk,rst,tick,4'd15,1'b0,12'd825,12'd0,1'b0,sample,active,
 1'b0,2'd1,9'd6,16'd16,9'd160,16'd4,2'd0,1'b1,slots,notes,triggers);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
integer k,n,c;real freq;reg signed [15:0] prev;
initial begin
repeat(3)@(negedge clk);rst=1;
for(k=0;k<8;k=k+1)begin
keys=255;repeat(1400)frame();keys=~(8'b1<<k);repeat(600)frame();c=0;prev=sample;
for(n=0;n<5000;n=n+1)begin frame();if(prev<0 && sample>=0)c=c+1;prev=sample;end
case(k)0:freq=523.251;1:freq=587.330;2:freq=659.255;3:freq=698.456;4:freq=783.991;5:freq=880;6:freq=987.767;7:freq=1046.502;endcase
if($itor(c)<freq*5000/46875-1.1 || $itor(c)>freq*5000/46875+1.1)$fatal(1,"Optical note %d wrong pitch: %d",k,c);
end
keys=0;repeat(600)frame();for(n=0;n<1000;n=n+1)begin frame();if(sample>8192 || sample< -8192 || $isunknown(sample))$fatal(1,"Chord overflow");end
keys=255;repeat(1400)frame();if(active || sample!==0)$fatal(1,"Optical release not silent");
$display("PASS optical voices: all eight pitches, reused four slots, bounded multikey output, release silence");$finish;
end
endmodule
