`timescale 1ns/1ps
module tb_practice_guide;
 reg playing=1,valid=1;reg[4:0] note=12;reg[1:0] bank=0;reg[159:0] mapping;
 wire[7:0] target;wire[1:0] suggested;wire found;integer i;
 practice_guide dut(playing,valid,note,bank,mapping,target,suggested,found);
 initial begin
  for(i=0;i<32;i=i+1)mapping[i*5+:5]=i;
  #1;if(target!=0||suggested!=1||!found)$fatal(1,"must request bank2 for C4");
  bank=1;#1;if(target!=8'h10||suggested!=1)$fatal(1,"C4 is key5 in bank2");
  mapping[0+:5]=12;bank=0;#1;if(target!=1||suggested!=0)$fatal(1,"respect custom map and prefer current bank");
  mapping[5+:5]=12;#1;if(target!=3)$fatal(1,"duplicate mappings should show both possible keys");
  valid=0;#1;if(target!=0||found)$fatal(1,"rest must not highlight key8");
  valid=1;playing=0;#1;if(target!=0||found)$fatal(1,"stopped must clear targets");
  playing=1;note=0;#1;if(target!=0||found)$fatal(1,"unmapped note must be explicit");
  $display("PASS practice guide: bank, remapping, duplicates, rest, stop, unavailable");$finish;
 end
endmodule
