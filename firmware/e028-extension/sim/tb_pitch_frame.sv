`timescale 1ns/1ps
module tb_pitch_frame;
reg clk=0,reset_n=0,tick=0;always #5 clk=~clk;
reg signed [13:0] bend=0;
wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(tick),.gate_mask(32'hFFFFFFFF),
 .timbre(2'd1),.velocity(8'd100),.bend(bend),.vibrato(8'd0),
 .brightness(8'd128),.expression(8'd8),.tremolo(8'd0),.sample(sample));
reg [31:0] center_increment;
initial begin
 repeat(3) @(negedge clk);reset_n=1;
 @(negedge clk);tick=1;@(negedge clk);tick=0;
 wait(dut.state==1 && dut.voice_index==0);#1;center_increment=dut.increment_final;
 bend=8191;#1;
 if(dut.increment_final!=center_increment)$fatal(1,"pitch changed within accepted frame");
 repeat(570) @(negedge clk);
 if(dut.state!=0)$fatal(1,"frame budget exceeded");
 tick=1;@(negedge clk);tick=0;
 wait(dut.state==1 && dut.voice_index==0);#1;
 if(dut.increment_final<=center_increment)$fatal(1,"next frame bend not applied");
 $display("PASS pitch commits at frame boundary, voices share ratio, 576clock budget");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
