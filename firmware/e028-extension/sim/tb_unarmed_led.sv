`timescale 1ns/1ps
module tb_unarmed_led;
reg clk=0;always #5 clk=~clk;
wire[3:0]led;
instrument_core #(.ENABLE_UI(0),.ENABLE_OPTICAL(0),.ENABLE_GESTURE(0)) dut(
 .clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ADC_SCL(),.ADC_SDA(),.OPTICAL_SCL(),.OPTICAL_SDA(),.OLED_SCL(),.OLED_SDA(),.ESP_RX(1'b1),.K230_RX(1'b1),.led(led));
initial begin
 repeat(33000)@(negedge clk);
 if(dut.armed!==0 || dut.frame_tick!==0)$fatal(1,"fixture should remain safely unarmed");
 force dut.heartbeat=24'd0;#1;if(led!==4'b0111)$fatal(1,"unarmed indicator missing");
 force dut.heartbeat=24'h400000;#1;if(led!==4'b1111)$fatal(1,"unarmed heartbeat frozen with audio reset");
 release dut.heartbeat;
 $display("PASS unarmed active-low LED heartbeat independent of audio frame/reset");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
