`timescale 1ns/1ps
module tb_control_ownership;
reg clk=0; always #5 clk=~clk;
instrument_core #(.ENABLE_UI(0),.ENABLE_OPTICAL(0),.ENABLE_GESTURE(0),.LEASE_TICKS(12)) dut(
 .clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ADC_SCL(),.ADC_SDA(),.OPTICAL_SCL(),.OPTICAL_SDA(),.OLED_SCL(),.OLED_SDA(),.ESP_RX(1'b1),.K230_RX(1'b1));
task command(input [7:0] kind,input [31:0] value);
begin
 @(negedge clk);force dut.cmd_valid=1;force dut.cmd_kind=kind;force dut.cmd_value=value;
 @(negedge clk);release dut.cmd_valid;release dut.cmd_kind;release dut.cmd_value;
end endtask
initial begin
 force dut.reset_n=0;force dut.cmd_valid=0;repeat(3) @(negedge clk);
 force dut.reset_n=1;force dut.controls_valid=1;force dut.axis_x=12'd925;
 force dut.gesture_active=1;force dut.gesture_color=12'd1100;
 command("Q",0);#1;
 if(!dut.remote_active || dut.brightness!=dut.local_brightness || $signed(dut.bend)!=1000)
  $fatal(1,"connection/lease masks local brightness or joystick");
 command("Y",210);command("B",8692);#1;
 if(dut.brightness!=210 || $signed(dut.bend)!=500)$fatal(1,"explicit controls not applied");
 command("L",0);command("Q",0);#1;
 if(dut.brightness!=dut.local_brightness || $signed(dut.bend)!=1000)$fatal(1,"release retains stale ownership");
 command("Y",200);command("B",8192);repeat(15) @(negedge clk);
 command("Q",0);#1;
 if(dut.brightness!=dut.local_brightness || $signed(dut.bend)!=1000)$fatal(1,"expiry retains stale ownership");
 $display("PASS lease-only connection preserves local controls; explicit commands own dimension until release/expiry");$finish;
end
endmodule
