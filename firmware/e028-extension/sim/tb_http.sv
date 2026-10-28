`timescale 1ns/1ps
module tb_http;
reg clk=0;always #5 clk=~clk;reg reset_n=0,valid=0;reg[7:0] data=0;
wire request,command;wire[2:0] client;wire[1:0] route;wire[7:0] kind;wire[31:0] value;
esp_http_request dut(clk,reset_n,valid,data,request,client,route,command,kind,value);
integer requests=0,commands=0;
always @(posedge clk) begin
 if(request) begin requests=requests+1;if(client!=2)$fatal(1,"client");end
 if(command) begin commands=commands+1;if(kind!="M" || value!=32'h80000001)$fatal(1,"mask");end
end
task send(input string s);integer i;begin for(i=0;i<s.len();i=i+1)begin @(negedge clk);valid=1;data=s[i];end @(negedge clk);valid=0;repeat(4)@(negedge clk);end endtask
initial begin repeat(3)@(negedge clk);reset_n=1;
 send("+IPD,2,16:GET / HTTP/1.1\015\n");
 send("+IPD,2,8:GET /c/M");send("+IPD,2,19:80000001 HTTP/1.1\015\n");
 send("+IPD,2,27:GET /c/MZZZZZZZZ HTTP/1.1\015\n");
 repeat(10)@(negedge clk);
 if(requests!=3 || commands!=1)$fatal(1,"counts %d %d",requests,commands);
 $display("PASS HTTP GET, split payload, mask, invalid hex");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
