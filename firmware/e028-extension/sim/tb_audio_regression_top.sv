`timescale 1ns/1ps
module tb_audio_regression_top;
 reg clk=0;always #5 clk=~clk;
 wire scl,sda,oscl,osda,dscl,dsda,bck,lrck,data,pa,hb,hw,hd,ut,et;
 wire [3:0] led;
 audio_regression_top #(.SLOT_FRAMES(2)) dut(clk,4'b1111,1'b1,
  scl,sda,oscl,osda,dscl,dsda,1'b1,1'b1,bck,lrck,data,pa,hb,hw,hd,led,ut,et);
 initial begin
  wait(dut.slot==2);#1;if(dut.bend!=8191)$fatal(1,"up bend");
  wait(dut.slot==3);#1;if(dut.bend!=-8192)$fatal(1,"down bend");
  wait(dut.slot==7);#1;if(dut.fx!=0 || dut.mask!=32'h1000)$fatal(1,"settled dry stimulus");
  wait(dut.slot==8);#1;if(dut.fx!=2 || dut.mask!=32'h1000)$fatal(1,"delay stimulus");
  wait(dut.slot==9);#1;if(dut.fx!=2 || dut.mask!=0)$fatal(1,"delay release");
  wait(dut.slot==14);#1;if(dut.mask!=32'h00891000)$fatal(1,"chord");
  wait(dut.slot==16);#1;if(dut.mask!=32'hFFFFFFFF)$fatal(1,"32 notes");
  wait(dut.slot==18);repeat(1200) @(negedge clk);
  if(dut.slot!=18 || dut.mask!=0 || dut.fx!=0)$fatal(1,"not bounded");
  if(scl!==1'bz || sda!==1'bz || et!==1'bz)$fatal(1,"peripheral driven");
  $display("PASS autonomous probe sequence, bends, chord, 32notes, bounded stop, buses high impedance");$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
