`timescale 1ns/1ps
module tb_e050_uart;
 reg clk=0,rst=0;always #5 clk=~clk;
 wire[6:0]index;wire capture,tx,received;wire[7:0]byte_value;
 wire[7:0]data=index==0?"A":index==95?8'd10:"0";
 reg[7:0]bytes[0:113];integer count=0;
 e050_packet_uart dut(clk,rst,data,64'h500103030C011001,index,capture,tx);
 uart8n1 receiver(clk,rst,tx,1'b0,8'd0,,,received,byte_value);
 always @(posedge clk)if(received && count<114)begin bytes[count]=byte_value;count=count+1;end
 initial begin
  repeat(4)@(negedge clk);rst=1;wait(count==114);#1;
  if(bytes[0]!="A"||bytes[95]!=10||bytes[96]!="Z"||bytes[113]!=10)$fatal(1,"A/Z framing");
  if({bytes[97],bytes[98],bytes[99],bytes[100],bytes[101],bytes[102],bytes[103],bytes[104],bytes[105],bytes[106],bytes[107],bytes[108],bytes[109],bytes[110],bytes[111],bytes[112]}!="500103030C011001")$fatal(1,"OLED status UART bytes");
  $display("PASS E050 diagnostic UART: real TX/RX A frame and frozen OLED Z status");$finish;
 end
 initial begin #12000000;$fatal(1,"diagnostic UART timeout");end
endmodule
