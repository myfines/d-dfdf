`timescale 1ns/1ps
module tb_audio_delivery_probe;
reg clk=0;always #5 clk=~clk;
audio_delivery_probe #(.SLOT_FRAMES(4)) dut(.clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ESP_RX(1'b1),.K230_RX(1'b1));
initial begin
 wait(dut.slot==7);#1;if(dut.tone!=3||dut.vibrato!=0||dut.fx!=0)$fatal(1,"Bass incorrectly modulated");
 wait(dut.slot==10);#1;if(dut.expression!=80)$fatal(1,"half pinch");
 wait(dut.slot==11);#1;if(dut.expression!=40)$fatal(1,"quarter pinch");
 wait(dut.slot==12);#1;if(dut.expression!=0)$fatal(1,"mute pinch");
 wait(dut.slot==13);#1;if(dut.expression!=160)$fatal(1,"hand loss unity");
 wait(dut.slot==24);#1;if(dut.mask!=32'hffffffff)$fatal(1,"32 notes");
 wait(dut.slot==28);#1;if(dut.vibrato!=80)$fatal(1,"explicit vibrato comparison");
 wait(dut.slot==30);repeat(10000)@(negedge clk);
 if(dut.slot!=30||dut.mask!=0||dut.ESP_TX!==1'bz)$fatal(1,"probe not bounded/isolated");
 $display("PASS delivery probe four tones, volume sequence, explicit modulation, bounded stop and isolated ESP");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
