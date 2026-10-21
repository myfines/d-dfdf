`timescale 1ns/1ps
module k230_usb_host_generated(input wire usb_clk,usb_rst,input wire [7:0] ulpi_data_i,input wire ulpi_dir,ulpi_nxt,data__ready,
 output wire [7:0] ulpi_data_o,output wire ulpi_data_oe,ulpi_stp,output reg data__valid=0,output reg [7:0] data__payload=0,output reg ready=0);
 assign ulpi_data_o=0;assign ulpi_data_oe=0;assign ulpi_stp=0;
endmodule
module tb_probe_report;
 reg clk=0,usb_clk=0;always #18.518 clk=~clk;always #8.333 usb_clk=~usb_clk;
 wire [7:0] bus;wire serial;wire rv;wire [7:0] rd;reg [7:0] captured[0:17];integer count=0,i;reg [7:0] check;
 host_probe_top dut(.clk(clk),.ulpi_clk(usb_clk),.ulpi_dir(1'b0),.ulpi_nxt(1'b0),.ulpi_data(bus),.UART_TX(serial));
 uart8n1 #(.BIT_TICKS(521)) monitor(.clk(usb_clk),.reset_n(~dut.usb_reset[1]),.rx(serial),.tx_start(1'b0),.tx_data(8'd0),.rx_valid(rv),.rx_data(rd));
 always @(posedge usb_clk)if(rv)begin captured[count]=rd;count=count+1;end
 reg [7:0] vectors[0:23];
 initial begin
  $readmemh("E:/gaoyun/tools/smoke/usb-gesture-received.hex",vectors);
  repeat(4)@(negedge usb_clk);if(dut.ulpi_rst!==0)$fatal(1,"RESETB must assert low");
  force dut.power_count=20'h80000;
  repeat(8)@(negedge usb_clk);if(dut.ulpi_rst!==1||dut.usb_reset[1]!==0)$fatal(1,"RESETB release");dut.host.ready=1;
  for(i=0;i<24;i=i+1)begin
   @(negedge usb_clk);dut.host.data__payload=vectors[i];dut.host.data__valid=1;
   @(negedge usb_clk);dut.host.data__valid=0;
   if(i==11)wait(count==9);
  end
  wait(count==18);
  if(captured[0]!=8'ha6||captured[1]!=0||captured[2]!=1||captured[3]!=95||captured[4]!=2||captured[5]!=238||captured[6]!=0||captured[7]!=250)$fatal(1,"valid gesture report");
  if(captured[9]!=8'ha6||captured[10]!=1||captured[11]!=0||captured[12]!=0)$fatal(1,"lost hand report");
  check=0;for(i=0;i<8;i=i+1)check=check^captured[i];if(check!=captured[8])$fatal(1,"report XOR1");
  check=0;for(i=9;i<17;i=i+1)check=check^captured[i];if(check!=captured[17])$fatal(1,"report XOR2");
  $display("PASS probe diagnostic: captured HS USB bytes -> actual RTL gesture CRC -> serialized UART reports with XOR, valid and lost hand");$finish;
 end
 initial begin #10000000;$fatal(1,"probe report timeout");end
endmodule
