`timescale 1ns/1ps
module tb_direct_record_wiring;
reg clk=0;always #5 clk=~clk;
instrument_core #(.ENABLE_UI(1),.ENABLE_WEB_RELAY(0),.ENABLE_OPTICAL(0),.ENABLE_GESTURE(1)) dut(
 .clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ADC_SCL(),.ADC_SDA(),.OPTICAL_SCL(),.OPTICAL_SDA(),.OLED_SCL(),.OLED_SDA(),.ESP_RX(1'b1),.K230_RX(1'b1));
task command(input [31:0] value);
begin @(negedge clk);force dut.cmd_valid=1;force dut.cmd_kind="C";force dut.cmd_value=value;
 @(negedge clk);force dut.cmd_valid=0;release dut.cmd_kind;release dut.cmd_value;end endtask
task capture;
begin repeat(100)@(negedge clk);force dut.telemetry_capture=1;@(negedge clk);force dut.telemetry_capture=0;end endtask
initial begin
 force dut.reset_n=0;force dut.io_reset_n=0;force dut.cmd_valid=0;force dut.telemetry_capture=0;force dut.telemetry_index=0;
 repeat(3)@(negedge clk);force dut.reset_n=1;force dut.io_reset_n=1;
 command(32'h10020012);capture();#1;
 if(dut.telemetry_byte!="A")$fatal(1,"AP direct recording telemetry disabled");
 command(0);#1;
 if(dut.telemetry_byte!="A")$fatal(1,"mode command tears an in-flight telemetry frame");
 capture();#1;if(dut.telemetry_byte!="G")$fatal(1,"AP normal telemetry not restored");
 command(32'h10010011);capture();repeat(100)@(negedge clk);
 force dut.telemetry_index=7;#1;if(dut.telemetry_byte!="0")$fatal(1,"record busy flags upper digit");
 force dut.telemetry_index=8;#1;if(dut.telemetry_byte!="1")$fatal(1,"direct record start not accepted");
 $display("PASS production AP recorder enabled, A/G frames frozen until capture, start busy telemetry");$finish;
end
endmodule
