`timescale 1ns/1ps
module tb_fx_gain;
reg clk=0,reset_n=0,tick=0;
always #5 clk=~clk;
reg signed [15:0] dry=0;
reg [2:0] enable=0;
wire signed [15:0] l,r;
fx_engine dut(clk,reset_n,tick,dry,enable,l,r);
integer mode,polarity,value;
task frame; input integer v; begin
 @(negedge clk);dry=v;tick=1;
 @(negedge clk);tick=0;repeat(8) @(negedge clk);
end endtask
initial begin
 repeat(3) @(negedge clk);reset_n=1;
 for(mode=0;mode<8;mode=mode+1) begin
  for(polarity=0;polarity<2;polarity=polarity+1) begin
   reset_n=0;repeat(3) @(negedge clk);reset_n=1;
   enable=mode;dry=0;repeat(2200) @(negedge clk);
   value=polarity ? -12000 : 12000;
   frame(value);
   if(l!==value || r!==value)
    $fatal(1,"dry gain changed mode=%0d input=%0d L=%0d R=%0d",mode,value,l,r);
  end
 end
 // Explicit output overload must saturate instead of wrapping polarity.
 force dut.dry_hold=16'sd32767;force dut.chorus_q=16'sd32767;
 force dut.delay_q=16'sd32767;force dut.rev1_q=16'sd32767;
 force dut.rev2_q=16'sd32767;enable=7;#1;
 if(dut.sat16(dut.mix_l)!==16'sd32767 || dut.sat16(dut.mix_r)!==16'sd32767)
  $fatal(1,"positive overload did not saturate");
 force dut.dry_hold=-16'sd32768;force dut.chorus_q=-16'sd32768;
 force dut.delay_q=-16'sd32768;force dut.rev1_q=-16'sd32768;
 force dut.rev2_q=-16'sd32768;#1;
 if(dut.sat16(dut.mix_l)!==-16'sd32768 || dut.sat16(dut.mix_r)!==-16'sd32768)
  $fatal(1,"negative overload did not saturate");
 $display("PASS dry gain identical across 8 modes, both polarities, overload saturation");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
