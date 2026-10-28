`timescale 1ns/1ps
// UART transport for the shared gesture parser; E025 assigns its input to M14.
module gesture_uart_rx #(
 parameter integer MIN_CONFIDENCE=60,BIT_TICKS=234,LEASE_TICKS=6750000,GAP_TICKS=540000
)(input wire clk,reset_n,rx,output wire active,update,
 output wire [7:0] seq,output wire [9:0] pinch,y,output wire [7:0] confidence);
 wire valid;wire [7:0] data;
 uart8n1 #(.BIT_TICKS(BIT_TICKS)) serial(.clk(clk),.reset_n(reset_n),.rx(rx),.tx_start(1'b0),.tx_data(8'd0),.rx_valid(valid),.rx_data(data));
 gesture_packet_rx #(.MIN_CONFIDENCE(MIN_CONFIDENCE),.LEASE_TICKS(LEASE_TICKS),.GAP_TICKS(GAP_TICKS)) parser(clk,reset_n,valid,data,active,update,seq,pinch,y,confidence);
endmodule
