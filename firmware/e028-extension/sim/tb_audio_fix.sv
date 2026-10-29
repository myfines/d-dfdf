`timescale 1ns/1ps
module tb_audio_fix;
reg clk=0,reset_n=0;always #5 clk=~clk;
reg signed [13:0] bend=0;
wire signed[15:0] sample;wire active,on;wire[5:0] voices;wire[4:0] idx;wire[15:0] latency;
synth32 synth(clk,reset_n,1'b0,32'd0,2'd0,8'd100,bend,8'd0,8'd128,8'd255,8'd0,sample,active,voices,on,idx,latency,1'b0,20'd0);
wire signed[15:0] l,r;
fx_engine fx(clk,reset_n,1'b0,16'sd0,3'd2,l,r);
integer i; real expected,error,maxerror;integer failures=0;
initial begin
repeat(3) @(negedge clk);reset_n=1;repeat(3) @(negedge clk);
force fx.delay_q=-16'sd8000;force fx.dry_hold=16'sd0;#1;
if(fx.delay_next != -3000) begin $display("FAIL negative feedback: %0d expected -3000",fx.delay_next);failures=failures+1;end
maxerror=0;
for(i=-8192;i<=8191;i=i+1) begin bend=i;#1;expected=65536.0*$pow(2.0,(i<0?i/8192.0:i/8191.0)/6.0);error=1200.0*$ln(synth.ratio/expected)/$ln(2.0);if(error<0)error=-error;if(error>maxerror)maxerror=error;end
$display("bend max error cents=%f",maxerror);
if(maxerror>2.0) begin $display("FAIL bend precision");failures=failures+1;end
if(failures) $fatal(1,"audio regressions=%0d",failures);
$display("PASS audio signed feedback and bend sweep");$finish;end
endmodule
