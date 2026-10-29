`timescale 1ns/1ps
module tb_adsr_long_release;
reg clk=0,reset_n=0,tick=0;always #5 clk=~clk;
reg [31:0] gates=0;reg [19:0] cfg=20'h00E40;
wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(tick),.gate_mask(gates),
.timbre(2'd1),.velocity(8'd120),.bend(14'sd0),.vibrato(8'd0),.brightness(8'd128),
.expression(8'd8),.tremolo(8'd0),.sample(sample),.custom_adsr(1'b1),.adsr_config(cfg));
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(574)@(negedge clk);end endtask
integer i,previous_level;
initial begin
repeat(3)@(negedge clk);reset_n=1;gates=32'h1000;
repeat(10)frame();
if(dut.env_level[12]!=16448)$fatal(1,"low sustain incorrect");
cfg=20'h00EC0;gates=32'h41000;repeat(10)frame();
if(dut.env_level[18]!=49344 || dut.env_level[12]!=16448)$fatal(1,"sustain ratio/config isolation incorrect");
gates=32'h40000;frame();
previous_level=16448;
for(i=0;i<8224;i=i+1)begin
 frame();
 if(dut.env_level[12]!=previous_level-2)$fatal(1,"R14 release frame %0d got %0d expected %0d",i,dut.env_level[12],previous_level-2);
 if(dut.env_level[18]!=49344)$fatal(1,"release affected held voice");
 previous_level=previous_level-2;
end
if(dut.env_state[12]!=0)$fatal(1,"release did not finish");
$display("PASS actual engine R14: 8224 frames, 175.445ms at 46875Hz from S64; sustain ratio exactly 3; held voice unaffected");$finish;
end
initial begin #60000000;$fatal(1,"timeout");end
endmodule
