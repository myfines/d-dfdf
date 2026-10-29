`timescale 1ns/1ps
module tb_adsr_core;
reg clk=0;always #5 clk=~clk;
wire a,b,c,d,e,f,bck,ws,data,pa,hb,hw,hd,ut,et;wire[3:0]led;
instrument_core #(.SAFE_STARTUP(0),.ENABLE_OPTICAL(0),.ENABLE_UI(0),.ENABLE_GESTURE(0),.LINK_MODE(1)) dut(
 .clk(clk),.btn_n(4'hf),.JOY_SW_N(1'b1),.ADC_SCL(a),.ADC_SDA(b),
 .OPTICAL_SCL(c),.OPTICAL_SDA(d),.OLED_SCL(e),.OLED_SDA(f),.ESP_RX(1'b1),.K230_RX(1'b1),
 .PCM_BCK(bck),.PCM_LRCK(ws),.PCM_DATA(data),.PA_EN(pa),.HP_BCK(hb),.HP_WS(hw),.HP_DIN(hd),
 .led(led),.UART_TX(ut),.ESP_TX(et));
reg[7:0]kind;reg[31:0]value;
task command;input[7:0]k;input[31:0]v;begin
 @(negedge clk);kind=k;value=v;force dut.cmd_kind=kind;force dut.cmd_value=value;force dut.cmd_valid=1;
 @(negedge clk);release dut.cmd_valid;release dut.cmd_kind;release dut.cmd_value;
end endtask
initial begin
 wait(dut.reset_n);repeat(10)@(negedge clk);
 // Skip the one-second physical arming guard only in this wiring test.
 // Arming behavior/latency are covered separately, not inferred here.
 force dut.arm_inhibit=0;
 command("G",32'h19CDA074);command("M",32'h1000);
 repeat(576*4)@(negedge clk);
 if(!dut.custom_adsr || dut.custom_adsr_config!=20'h9CDA0)$fatal(1,"core bank binding failed");
 if(dut.synth.env_adsr[12]!=21'h19CDA0)$fatal(1,"core envelope not latched by voice");
 command("G",0);command("M",0);repeat(576*2)@(negedge clk);
 command("M",32'h40000);repeat(576*2)@(negedge clk);
 if(dut.synth.env_adsr[18][20])$fatal(1,"core preset restore failed");
 $display("PASS core command bank->frame->voice ADSR binding and preset restore; command-level simulation only");$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
