`timescale 1ns/1ps
// 27MHz/234 = 115384 baud (<0.2% from 115200). RX checks stop bit.
module uart8n1 #(parameter integer BIT_TICKS=234)(
 input wire clk,reset_n,rx,tx_start,input wire [7:0] tx_data,
 output reg tx,output wire tx_busy,output reg rx_valid,output reg [7:0] rx_data);
 reg [9:0] tx_shift;reg [3:0] tx_left;reg [15:0] tx_count,rx_count;
 reg rx_meta,rx_sync;reg [1:0] state;reg [2:0] bit_index;reg [7:0] rx_shift;
 assign tx_busy=tx_left!=0;
 always @(posedge clk)begin
  if(!reset_n)begin tx<=1;tx_left<=0;tx_count<=0;tx_shift<=10'h3ff;
   rx_meta<=1;rx_sync<=1;state<=0;rx_count<=0;bit_index<=0;rx_shift<=0;rx_data<=0;rx_valid<=0;end
  else begin
   rx_meta<=rx;rx_sync<=rx_meta;rx_valid<=0;
   if(tx_left==0)begin if(tx_start)begin tx_shift<={1'b1,tx_data,1'b0};tx<=0;tx_left<=10;tx_count<=BIT_TICKS-1;end end
   else if(tx_count!=0)tx_count<=tx_count-1'b1;
   else begin tx_count<=BIT_TICKS-1;tx_shift<={1'b1,tx_shift[9:1]};tx<=tx_shift[1];tx_left<=tx_left-1'b1;end
   case(state)
    0:if(!rx_sync)begin rx_count<=BIT_TICKS/2-1;state<=1;end
    1:if(rx_count!=0)rx_count<=rx_count-1'b1;else if(rx_sync)state<=0;else begin state<=2;rx_count<=BIT_TICKS-1;bit_index<=0;end
    2:if(rx_count!=0)rx_count<=rx_count-1'b1;else begin rx_shift[bit_index]<=rx_sync;rx_count<=BIT_TICKS-1;if(bit_index==7)state<=3;else bit_index<=bit_index+1'b1;end
    3:if(rx_count!=0)rx_count<=rx_count-1'b1;else begin if(rx_sync)begin rx_data<=rx_shift;rx_valid<=1;end state<=0;end
   endcase
  end
 end
endmodule
