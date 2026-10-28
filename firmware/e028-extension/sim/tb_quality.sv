`timescale 1ns/1ps
module tb_quality;
reg clk=0, reset_n=0; always #5 clk=~clk;
reg [7:0] bright=0; wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(1'b0),.gate_mask(32'd0),.timbre(2'd0),.velocity(8'd128),.bend(14'sd0),.vibrato(8'd0),.brightness(bright),.expression(8'd255),.tremolo(8'd0),.sample(sample));
integer i, sum, prev, errors;
initial begin
 errors=0; sum=0; prev=0;
 for(i=0;i<256;i=i+1) begin
  bright=i; #1;
  if(dut.filter_alpha<prev) begin $display("FAIL filter nonmonotonic %0d",i); errors=errors+1; end
  prev=dut.filter_alpha;
 end
 for(i=0;i<32;i=i+1) begin
  sum=sum+$signed(dut.lfo_sine(i))+$signed(dut.lfo_sine(i+32));
 end
 if(sum!=0) begin $display("FAIL LFO asymmetric sum=%0d",sum);errors=errors+1;end
 if(errors) $fatal(1,"quality errors=%0d",errors);
 $display("PASS quality monotonic brightness and symmetric LFO");$finish;
end
endmodule
