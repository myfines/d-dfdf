`timescale 1ns/1ps
module tb_uart8n1;
reg clk=0;always #5 clk=~clk;reg reset_n=0,start=0;reg [7:0] tx_data=0;wire tx,busy,valid;wire [7:0] rx_data;integer i;
uart8n1 #(.BIT_TICKS(12)) dut(clk,reset_n,tx,start,tx_data,tx,busy,valid,rx_data);
task check(input [7:0] b);begin @(negedge clk);tx_data=b;start=1;@(negedge clk);start=0;wait(valid);if(rx_data!==b)$fatal(1,"UART mismatch");wait(!busy);repeat(5)@(negedge clk);end endtask
initial begin repeat(4)@(negedge clk);reset_n=1;check(8'h00);check(8'hff);check(8'h55);check(8'ha6);$display("PASS UART loopback");$finish;end
initial begin #100000;$fatal(1,"timeout");end
endmodule
