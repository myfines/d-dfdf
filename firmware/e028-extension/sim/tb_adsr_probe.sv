`timescale 1ns/1ps
module tb_adsr_probe;
reg clk=0;always #5 clk=~clk;
wire a,b,c,d,e,f,bck,ws,data,pa,hb,hw,hd,ut,et;wire[3:0]led;
audio_adsr_top #(.SLOT_FRAMES(2)) dut(clk,4'hf,1'b1,a,b,c,d,e,f,1'b1,1'b1,bck,ws,data,pa,hb,hw,hd,led,ut,et);
initial begin
 wait(dut.slot==1);#1;if(dut.config_value!=20'h505FF || dut.mask!=32'h1000)$fatal(1,"fast attack");
 wait(dut.slot==3);#1;if(dut.config_value!=20'hE05FF)$fatal(1,"slow attack");
 wait(dut.slot==5);#1;if(dut.config_value!=20'h05540)$fatal(1,"fast decay");
 wait(dut.slot==7);#1;if(dut.config_value!=20'h0E540)$fatal(1,"slow decay");
 wait(dut.slot==9);#1;if(dut.config_value[7:0]!=64)$fatal(1,"low sustain");
 wait(dut.slot==11);#1;if(dut.config_value[7:0]!=192)$fatal(1,"high sustain");
 wait(dut.slot==13);#1;if(dut.config_value[11:8]!=5)$fatal(1,"short release");
 wait(dut.slot==15);#1;if(dut.config_value[11:8]!=14)$fatal(1,"long release");
 wait(dut.slot==18);repeat(1200)@(negedge clk);
 if(dut.mask!=0 || dut.slot!=18 || a!==1'bz || et!==1'bz)$fatal(1,"bounded stop or bus isolation");
 $display("PASS ADSR probe pairs, independent parameter stimulus, bounded stop and high impedance");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
