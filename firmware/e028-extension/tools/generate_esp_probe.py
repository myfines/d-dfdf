"""Minimal AT-only UART query, SRAM only; never changes ESP configuration."""
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=Path('E:/gaoyun/private/esp-web')
source='''`timescale 1ns/1ps
module esp_probe_top #(parameter integer QUERY_TICKS=54000000)(input wire clk,input wire[3:0]btn_n,input wire JOY_SW_N,
 inout wire ADC_SCL,ADC_SDA,OPTICAL_SCL,OPTICAL_SDA,OLED_SCL,OLED_SDA,
 input wire ESP_RX,K230_RX,output wire PCM_BCK,PCM_LRCK,PCM_DATA,
 output wire PA_EN,HP_BCK,HP_WS,HP_DIN,output wire[3:0]led,output wire UART_TX,ESP_TX);
 reg[15:0]boot=0;always @(posedge clk)if(!(&boot))boot<=boot+1'b1;
 wire reset_n=&boot;
 reg start=0;reg[7:0]data=0;wire busy,valid;reg ready=0;wire[7:0]received,diagnostic;
 reg[15:0]rx_count=0,tx_count=0;reg[7:0]last_rx=0,last_tx=0;
 uart8n1 link(clk,reset_n,ESP_RX,start,data,ESP_TX,busy,valid,received);
 reg[31:0]timer=0;reg sending=0;reg[1:0]ordinal=0;
 always @(posedge clk)begin
  start<=0;
  if(!reset_n)begin timer<=0;sending<=0;ordinal<=0;data<=0;ready<=0;end
  else begin
   if(valid && last_rx==8'h4f && received==8'h4b)ready<=1;
   if(!sending)begin
    if(timer==QUERY_TICKS-1)begin timer<=0;sending<=1;ordinal<=0;end
    else timer<=timer+1'b1;
   end
   if(sending && !busy && !start)begin
    case(ordinal)0:data<=8'h41;1:data<=8'h54;2:data<=8'h0d;3:data<=8'h0a;endcase
    start<=1;
    if(ordinal==3)sending<=0;else ordinal<=ordinal+1'b1;
   end
  end
 end
 always @(posedge clk)begin
  if(!reset_n)begin rx_count<=0;tx_count<=0;last_rx<=0;last_tx<=0;end
  else begin
   if(valid)begin rx_count<=rx_count+1'b1;last_rx<=received;end
   if(start)begin tx_count<=tx_count+1'b1;last_tx<=data;end
  end
 end
 assign diagnostic={ready,rx_count!=0,tx_count>=8&&!ready,ESP_RX,ESP_TX,3'd0};
 wire[63:0]status={8'h52,diagnostic,rx_count,tx_count,last_rx,last_tx};
 e050_packet_uart observer(clk,reset_n,8'd32,status,,,UART_TX);
 assign ADC_SCL=1'bz;assign ADC_SDA=1'bz;assign OPTICAL_SCL=1'bz;assign OPTICAL_SDA=1'bz;
 assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;
 assign PCM_BCK=1'bz;assign PCM_LRCK=1'bz;assign PCM_DATA=1'bz;
 assign PA_EN=0;assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
 assign led=~diagnostic[3:0];
endmodule
'''
initializer='--initializer' in sys.argv
if initializer:
    start=source.index(' reg start=0;')
    end=source.index(' always @(posedge clk)begin\n  if(!reset_n)begin rx_count',start)
    source=source[:start]+''' wire start,busy,valid,ready;wire[7:0]data,received,diagnostic,native_diagnostic;
 reg[15:0]rx_count=0,tx_count=0;reg[7:0]last_rx=0,last_tx=0;
 uart8n1 link(clk,reset_n,ESP_RX,start,data,ESP_TX,busy,valid,received);
 esp_at_control #(.TELEMETRY_BYTES(96)) wifi(.clk(clk),.reset_n(reset_n),
 .rx_valid(valid),.rx_data(received),.tx_busy(busy),.tx_start(start),.tx_data(data),
 .ready(ready),.diagnostic(native_diagnostic),.telemetry_data(8'd0));
'''+source[end:]
    source=source.replace("assign diagnostic={ready,rx_count!=0,tx_count>=8&&!ready,ESP_RX,ESP_TX,3'd0};", "assign diagnostic={native_diagnostic[7:5],ESP_RX,ESP_TX,native_diagnostic[2:0]};").replace("8'h52", "8'h53")
    source+='''\n// HTTP response ROM is irrelevant to AT initialization. No HTTP test claim.
module esp_http_rom(input wire clk,input wire[13:0]address,output wire[7:0]data);
assign data=0;
endmodule
'''
(PRIVATE/'esp_probe_top.v').write_text(source,encoding='utf-8')
build='''set root [file normalize [file join [file dirname [info script]] ..]]
create_project -name esp_diagnostic_e052 -dir "$::env(FPGA_WEB_PRIVATE)/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
foreach f {uart8n1.v diagnostic_oled_uart.v} {add_file "$root/src/$f"}
add_file "$::env(FPGA_WEB_PRIVATE)/esp_probe_top.v"
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module esp_probe_top
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE052
run all
'''
if initializer:
    build=build.replace('uart8n1.v diagnostic_oled_uart.v','uart8n1.v diagnostic_oled_uart.v esp_at_control.v esp_volume_parser.v esp_http_request.v').replace('0xE052','0xE053')
(ROOT/'tools/build_esp_probe.tcl').write_text(build,encoding='utf-8')
