`timescale 1ns/1ps
module tb_keymap_transport;
reg clk=0,reset_n=0,valid=0;reg[7:0]data=0;always #5 clk=~clk;
wire cv,hc,req;wire[7:0]ck,hk;wire[31:0]value,hv;
wire[2:0]client,hclient;wire[1:0]route;
esp_command_parser parser(clk,reset_n,valid,data,cv,ck,value,client);
esp_http_request http(clk,reset_n,valid,data,req,hclient,route,hc,hk,hv);
integer raw_seen=0,http_seen=0;
always @(posedge clk)begin
 if(cv && ck=="U" && value==32'h10001F0F)raw_seen<=raw_seen+1;
 if(hc && hk=="U" && hv==32'h10001F0F)http_seen<=http_seen+1;
end
task bytes;input string s;integer i;begin
 for(i=0;i<s.len();i=i+1)begin @(negedge clk);valid=1;data=s[i];@(negedge clk);valid=0;end
end endtask
task packet;input string p;begin bytes($sformatf("+IPD,0,%0d:",p.len()));bytes(p);repeat(3)@(negedge clk);end endtask
initial begin
 repeat(2)@(negedge clk);reset_n=1;
 packet("U10001F0F\n");if(raw_seen!=1)$fatal(1,"IPD ADSR command missing");
 packet("GET /c/U10001F0F HTTP/1.1\r\n\r\n");if(http_seen!=1)$fatal(1,"HTTP ADSR command missing");
 $display("PASS ADSR eighthex command over IPD and HTTP, legacy parser framing retained");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
