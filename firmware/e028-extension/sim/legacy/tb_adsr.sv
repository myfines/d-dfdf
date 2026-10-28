`timescale 1ns/1ps
module tb_adsr;
reg clk=0,rst=0,tick=0,gate=0;always #5 clk=~clk;
wire [8:0] level;wire active;
adsr_envelope #(.ATTACK_STEP(64),.DECAY_INTERVAL(2),.SUSTAIN_LEVEL(128),.RELEASE_INTERVAL(2)) dut(clk,rst,tick,gate,level,active);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
integer i,prev;
initial begin
repeat(3)@(negedge clk);rst=1;repeat(5)frame();if(level!==0 || active)$fatal(1,"Idle not silent");
gate=1;repeat(4)frame();if(level!==256)$fatal(1,"Attack did not reach peak");
prev=level;for(i=0;i<260;i=i+1)begin frame();if(level>prev || level<128)$fatal(1,"Decay wrong");prev=level;end
if(level!==128)$fatal(1,"Sustain target wrong");repeat(20)frame();if(level!==128)$fatal(1,"Sustain unstable");
gate=0;prev=level;repeat(20)begin frame();if(level>prev)$fatal(1,"Release rose");prev=level;end
gate=1;prev=level;frame();if(level<=prev)$fatal(1,"Retrigger failed");
gate=0;repeat(550)frame();if(level!==0 || active)$fatal(1,"Release not silent");
$display("PASS ADSR: peak, decay, stable sustain, release, retrigger, idle");$finish;
end
endmodule
