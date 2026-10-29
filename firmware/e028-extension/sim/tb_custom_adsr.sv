`timescale 1ns/1ps
module tb_custom_adsr;
reg clk=0,reset_n=0,tick=0;always #5 clk=~clk;
reg [31:0] gate_mask=0;reg custom=1;reg [19:0] config_value=20'h34540;
wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(tick),.gate_mask(gate_mask),
 .timbre(2'd1),.velocity(8'd128),.bend(14'sd0),.vibrato(8'd0),
 .brightness(8'd128),.expression(8'd8),.tremolo(8'd0),.sample(sample),
 .custom_adsr(custom),.adsr_config(config_value));
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(574)@(negedge clk);end endtask
integer i;
initial begin
 repeat(3)@(negedge clk);reset_n=1;gate_mask=32'h1000;
 for(i=0;i<8;i=i+1)frame();
 if(dut.env_level[12]!=32768)$fatal(1,"attack timing wrong %0d",dut.env_level[12]);
 for(i=0;i<40;i=i+1)frame();
 if(dut.env_level[12]!=16448 || dut.env_state[12]!=3)$fatal(1,"decay/sustain wrong %0d",dut.env_level[12]);
 config_value=20'h00080;gate_mask=32'h41000;
 for(i=0;i<5;i=i+1)frame();
 if(dut.env_level[18]!=32896)$fatal(1,"new voice config not applied");
 if(dut.env_level[12]!=16448 || dut.env_adsr[12]!=21'h134540)$fatal(1,"held voice config changed");
 gate_mask=32'h40000;
 for(i=0;i<20;i=i+1)frame();
 if(dut.env_level[12]!=0 || dut.env_state[12]!=0)$fatal(1,"release did not finish");
 if(dut.env_level[18]!=32896)$fatal(1,"release cut other voice");
 custom=0;gate_mask=0;for(i=0;i<5;i=i+1)frame();
 gate_mask=32'h1000;frame();if(dut.env_adsr[12][20])$fatal(1,"preset fallback failed");
 $display("PASS custom ADSR attack/decay/sustain/release timing, pervoice config, selective release, presets");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
