`timescale 1ns/1ps
module tb_gesture_link #(parameter integer RX_TICKS=16,TX_TICKS=16);
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,rx=1;wire active,update;wire [7:0] seq,confidence;wire [9:0] pinch,y;
 gesture_uart_rx #(.BIT_TICKS(RX_TICKS),.LEASE_TICKS(20000*RX_TICKS/16),.GAP_TICKS(2000*RX_TICKS/16)) dut(clk,reset_n,rx,active,update,seq,pinch,y,confidence);
 reg [7:0] vectors[0:119];integer accepted=0;
 always @(posedge clk)if(update)accepted=accepted+1;
 task byte_send(input [7:0] value,input good_stop);integer bitn;begin
  @(negedge clk);rx=0;repeat(TX_TICKS)@(negedge clk);
  for(bitn=0;bitn<8;bitn=bitn+1)begin rx=value[bitn];repeat(TX_TICKS)@(negedge clk);end
  rx=good_stop;repeat(TX_TICKS)@(negedge clk);rx=1;repeat(4)@(negedge clk);
 end endtask
 task packet(input integer slot);integer i;begin for(i=0;i<12;i=i+1)byte_send(vectors[slot*12+i],1);repeat(8)@(negedge clk);end endtask
 initial begin
  $readmemh("E:/gaoyun/tools/smoke/gesture-vectors.hex",vectors);
  repeat(4)@(negedge clk);reset_n=1;
  byte_send(8'h33,1);byte_send(8'ha5,1);packet(0);
  if(!active||seq!=254||pinch!=750||y!=250||confidence!=95||accepted!=1)$fatal(1,"Python->UART valid frame");
  packet(0);if(accepted!=1)$fatal(1,"duplicate accepted");
  packet(1);if(accepted!=1||pinch!=750)$fatal(1,"corrupt frame applied");
  packet(2);if(seq!=255||accepted!=2)$fatal(1,"forward seq");
  packet(3);if(seq!=0||pinch!=1000||accepted!=3)$fatal(1,"wrap seq");
  packet(2);if(seq!=0||accepted!=3)$fatal(1,"old seq replay");
  packet(4);if(accepted!=3)$fatal(1,"unknown version");
  packet(5);if(accepted!=3)$fatal(1,"out of range");
  byte_send(8'ha5,1);byte_send(8'h5a,1);byte_send(1,1);repeat(2100*RX_TICKS/16)@(negedge clk);
  packet(6);if(active||pinch!=0||y!=0||accepted!=4)$fatal(1,"lost hand release / gap recovery");
  packet(7);if(!active||accepted!=5)$fatal(1,"recover hand");
  repeat(21000*RX_TICKS/16)@(negedge clk);if(active||pinch!=0||confidence!=0)$fatal(1,"lease release");
  packet(0);if(!active||seq!=254||accepted!=6)$fatal(1,"sender restart after timeout");
  packet(8);if(accepted!=6)$fatal(1,"reserved flag");
  // Bad stop bit must not create a phantom complete packet.
  byte_send(8'ha5,0);repeat(2100*RX_TICKS/16)@(negedge clk);packet(2);
  if(seq!=255||accepted!=7)$fatal(1,"framing error recovery");
  packet(9);if(active||pinch!=0||accepted!=8)$fatal(1,"low confidence release");
  packet(6);if(active||accepted!=9)$fatal(1,"sequence advance after confidence loss");
  packet(7);if(!active||accepted!=10)$fatal(1,"confidence recovery");
  repeat(6)packet(7);
  repeat(9000*RX_TICKS/16)@(negedge clk);if(active)$fatal(1,"duplicates kept lease alive");
  reset_n=0;repeat(4)@(negedge clk);if(active)$fatal(1,"reset release");
  $display("PASS gesture: Python CRC vectors through serial RX, noise, duplicate, corruption, wrap, replay, version, range, loss, gap, timeout, restart, flags, framing, reset");$finish;
 end
 initial begin #(3000000*RX_TICKS/16);$fatal(1,"gesture sim timeout");end
endmodule
