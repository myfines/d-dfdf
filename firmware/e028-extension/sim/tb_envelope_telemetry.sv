`timescale 1ns/1ps
module tb_envelope_telemetry;
reg clk=0,reset_n=0;always #5 clk=~clk;
wire tx,valid;wire [7:0] data;integer n=0;reg [7:0] expected[0:5];
envelope_telemetry #(.PERIOD(20000)) dut(clk,reset_n,5'd16,16'h8080,3'd4,tx);
uart8n1 rx(.clk(clk),.reset_n(reset_n),.rx(tx),.tx_start(1'b0),.tx_data(8'd0),.tx(),.tx_busy(),.rx_valid(valid),.rx_data(data));
always @(posedge clk)if(valid)begin
if(data!==expected[n])$fatal(1,"packet byte %0d got %h expected %h",n,data,expected[n]);
if(n==5)begin $display("PASS telemetry UART bytes, snapshot, XOR");$finish;end
n=n+1;end
initial begin expected[0]=8'hA5;expected[1]=16;expected[2]=8'h80;expected[3]=8'h80;expected[4]=4;expected[5]=8'hB1;
repeat(4)@(negedge clk);reset_n=1;end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
