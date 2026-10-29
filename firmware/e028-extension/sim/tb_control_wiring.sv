`timescale 1ns/1ps
module tb_control_wiring;
reg clk=0;always #5 clk=~clk;
instrument_core #(.ENABLE_UI(0),.ENABLE_OPTICAL(0),.ENABLE_GESTURE(0)) dut(
 .clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ADC_SCL(),.ADC_SDA(),.OPTICAL_SCL(),.OPTICAL_SDA(),.OLED_SCL(),.OLED_SDA(),.ESP_RX(1'b1),.K230_RX(1'b1));
integer a;
initial begin
force dut.remote_active=0;force dut.controls_valid=1;force dut.axis_y=12'd825;
force dut.gesture_active=1;force dut.gesture_pinch=10'd1000;force dut.gesture_color=12'd1100;#2;
if(dut.velocity!=159)$fatal(1,"core velocity still truncated");
if(dut.vibrato!=0||dut.tremolo!=0)$fatal(1,"pinch implicitly modulates pitch/amplitude");
if(dut.brightness<169||dut.brightness>172)$fatal(1,"core brightness still wraps");
force dut.remote_active=1;force dut.remote_vibrato=8'd80;force dut.remote_brightness=8'd210;#2;
if(dut.vibrato!=80||dut.brightness!=210)$fatal(1,"explicit remote controls lost");
$display("PASS production wiring normalized velocity, no pinch modulation coupling, explicit remote controls retained");$finish;
end
endmodule
