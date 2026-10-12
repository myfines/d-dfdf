`timescale 1ns/1ps
module tb_idle_activity;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;
wire signed [15:0] s,voice_sample,delay_sample;wire active,busy,voice_active;
voice_engine voice(clk,rst,tick,4'd15,1'b0,12'd825,12'd0,1'b0,voice_sample,voice_active,
 1'b0,2'd0,9'd6,16'd16,9'd160,16'd4,2'd0);
short_delay #(.DEPTH(8)) effect(clk,rst,tick,1'b0,16'sd0,delay_sample);
spectrum_bank bank(clk,rst,tick,32'd0,s,active,busy);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(110)@(negedge clk);end endtask
integer i;reg [31:0] saved;
initial begin
repeat(3)@(negedge clk);rst=1;repeat(3)frame();saved=bank.phases[3];
for(i=0;i<30;i=i+1)begin frame();if(voice.voices[0].lane.phase!==0 || effect.filled!==0 || effect.index!==0)$fatal(1,"Inactive keyboard/effect still updating");
if(bank.phases[3]!==saved || bank.phase_reg!==0 || busy)$fatal(1,"Inactive 32-voice bank still switching");end
$display("PASS idle activity: inactive bank/keyboard/effect state frozen");$finish;
end
endmodule
