`timescale 1ns/1ps
module tb_wifi_commands;
reg clk=0;always #5 clk=~clk;reg reset_n=0,valid=0;reg [7:0] data;
wire update,command_valid;wire [7:0] volume,kind,value;wire [2:0] client;
integer commands=0;
esp_volume_parser dut(clk,reset_n,valid,data,update,volume,command_valid,kind,value,client);
always @(posedge clk)if(command_valid)commands=commands+1;
task send(input [8*128-1:0] s);integer i;begin for(i=127;i>=0;i=i-1)if(s[i*8+:8]!=0)begin @(negedge clk);valid=1;data=s[i*8+:8];@(negedge clk);valid=0;end repeat(2)@(negedge clk);end endtask
initial begin repeat(3)@(negedge clk);reset_n=1;
 send("+IPD,2,4:T02\n");if(commands!=1||kind!="T"||value!=2||client!=2)$fatal(1,"Timbre command");
 send("+IPD,2,4:K0F\n");if(commands!=2||kind!="K"||value!=15)$fatal(1,"Key command");
 send("+IPD,2,4:T04\n");send("+IPD,2,4:E02\n");send("+IPD,2,4:K10\n");send("+IPD,2,4:P03\n");
 if(commands!=2)$fatal(1,"Out-of-range command applied");
 send("+IPD,4,2:Q0");send("+IPD,4,2:0\n");if(commands!=3||kind!="Q"||client!=4)$fatal(1,"Subscription fragmentation");
 $display("PASS WiFi commands: parameters, client, range, fragments");$finish;
end
endmodule
