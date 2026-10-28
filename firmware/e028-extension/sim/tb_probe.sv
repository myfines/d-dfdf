`timescale 1ns/1ps
module tb_probe;
reg clk=0;always #5 clk=~clk;
tri1 a,b,c,d,e,f;wire[3:0]led;
audio_probe_top #(.SLOT_FRAMES(96)) dut(.clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ESP_RX(1'b1),.K230_RX(1'b1),.ADC_SCL(a),.ADC_SDA(b),.OPTICAL_SCL(c),.OPTICAL_SDA(d),.OLED_SCL(e),.OLED_SDA(f),.led(led));
initial begin
 wait(dut.slot==1);#1;if(dut.mask!==32'h1000||dut.tone!==0)$fatal(1,"piano segment");
 wait(dut.slot==3);#1;if(dut.tone!==1)$fatal(1,"organ segment");
 wait(dut.slot==5);#1;if(dut.tone!==2)$fatal(1,"strings segment");
 wait(dut.slot==7);#1;if(dut.tone!==3)$fatal(1,"bass segment");
 wait(dut.slot==9);#1;if(dut.mask!==32'h891000)$fatal(1,"chord segment");
 wait(dut.slot==16);repeat(10000)@(posedge clk);
 if(dut.mask!==0||dut.slot!==16)$fatal(1,"probe did not stop");
 if({a,b,c,d,e,f}!==6'b111111)$fatal(1,"probe drives peripheral buses");
 $display("PASS probe sequence, automatic stop, peripheral high impedance");$finish;
end
initial begin #20000000;$fatal(1,"probe timeout");end
endmodule
