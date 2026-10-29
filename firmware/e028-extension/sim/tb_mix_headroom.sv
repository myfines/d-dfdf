`timescale 1ns/1ps
module tb_mix_headroom;
reg clk=0,reset_n=0;always #5 clk=~clk;
reg [7:0] expression=8;
wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(1'b0),.gate_mask(32'd0),
 .timbre(2'd1),.velocity(8'd255),.bend(14'sd0),.vibrato(8'd0),
 .brightness(8'd255),.expression(expression),.tremolo(8'd0),.sample(sample));
integer stimulus,level,polarity,expected,filtered,actual,expression_int;
initial begin
 repeat(3) @(negedge clk);reset_n=1;repeat(3) @(negedge clk);
 force dut.mix_sum=stimulus;
 force dut.lowpass=0;
 for(level=0;level<3;level=level+1)begin
  expression=level==0 ? 8 : level==1 ? 64 : 255;
  expression_int=expression;
  for(polarity=0;polarity<2;polarity=polarity+1)begin
   stimulus=polarity ? -1048576 : 1048544;#2;
   // Maximum 32 coherent voices, fixed4x mixer headroom. Apply the
   // requested expression BEFORE narrowing to16bits, not afterwards.
   filtered=((stimulus>>>2)*255)>>>8;
   expected=(filtered*expression_int)>>>8;
   if(expected>32767)expected=32767;
   if(expected< -32768)expected=-32768;
   actual=$signed(dut.expression_sample);
   if(actual!=expected)$fatal(1,"early mix clipping: input=%0d expression=%0d expected=%0d actual=%0d",stimulus,expression,expected,actual);
  end
 end
 expression=0;#2;if(dut.expression_sample!=0)$fatal(1,"zero expression not silent");
 $display("PASS 32voice headroom before expression, both polarities, final saturation, mute");$finish;
end
endmodule
