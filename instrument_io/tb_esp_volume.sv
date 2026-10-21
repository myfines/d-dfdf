`timescale 1ns/1ps
module tb_esp_volume;
reg clk=0;always #5 clk=~clk;reg reset_n=0,valid=0;reg [7:0] data;wire update;wire [7:0] volume;integer count=0;
esp_volume_parser #(.IDLE_TICKS(200)) dut(clk,reset_n,valid,data,update,volume);
always @(posedge clk)if(update)count=count+1;
task send(input [8*128-1:0] s);integer i;begin for(i=127;i>=0;i=i-1)if(s[i*8+:8]!=0)begin @(negedge clk);valid=1;data=s[i*8+:8];@(negedge clk);valid=0;end end endtask
initial begin repeat(3)@(negedge clk);reset_n=1;
send("V00\n");if(count!=0)$fatal(1,"Raw AT text accepted");
send("+IPD,0,4:V80\n");repeat(2)@(negedge clk);if(count!=1||volume!=128)$fatal(1,"Valid volume rejected");
send("+IPD,0,2:V4");send("+IPD,0,2:0\n");repeat(2)@(negedge clk);if(count!=2||volume!=64)$fatal(1,"Fragmented TCP command rejected");
send("+IPD,0,8:V20\nVFF\n");repeat(2)@(negedge clk);if(count!=4||volume!=255)$fatal(1,"Coalesced command rejected");
send("+IPD,0,4:VQ0\n");send("+IPD,0,2:V0");send("+IPD,1,2:0\n");repeat(2)@(negedge clk);if(count!=4)$fatal(1,"Bad/inter-client command accepted");
repeat(220)@(negedge clk);send("+IPD,0,2:0\n");repeat(2)@(negedge clk);if(count!=4)$fatal(1,"Stale fragment accepted");
$display("PASS esp_volume framing, fragments, clients, invalid data, timeout");$finish;end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
