`timescale 1ns/1ps
module esp_cloud_config(input wire clk,input wire[3:0] section,input wire[9:0] index,output reg[7:0] data,output wire[9:0] length);
assign length=section==7?5:3;
always @(posedge clk)case(index)0:data<=section==7?"P":"A";1:data<=section==7?"O":"T";2:data<=section==7?"S":10;3:data<="T";default:data<=10;endcase
endmodule
module tb_cloud;
reg clk=0;always #5 clk=~clk;reg reset_n=0,rv=0,busy=0;reg[7:0] rd=0;wire start,ready,capture;wire[7:0] td,diag;wire[6:0] ti;
esp_cloud_control #(.BOOT_TICKS(10),.WAIT_TICKS(1000),.JOIN_TICKS(2000),.POLL_TICKS(30)) dut(clk,reset_n,rv,rd,busy,start,td,ready,8'h41,ti,capture,diag);
integer payload=0,polls=0,captures=0;reg collecting=0;
always @(posedge clk)if(capture)captures=captures+1;
task rx(input[7:0] b);begin @(negedge clk);rd=b;rv=1;@(negedge clk);rv=0;end endtask
task bytes(input string s);integer i;begin for(i=0;i<s.len();i=i+1)rx(s[i]);end endtask
initial forever begin
 wait(start);@(negedge clk);busy=1;repeat(3)@(negedge clk);busy=0;
 if(dut.section==7)begin
  payload=payload+1;
  if(payload>5 && td!=8'h41)$fatal(1,"Telemetry payload corruption");
  if(payload==101)begin payload=0;polls=polls+1;bytes("\015\nSEND OK\015\n+IPD,0,26:HTTP/1.1 200 OK\015\n\015\nV40\nZ00\n");end
 end else if(td==10)begin
  if(dut.section==6)bytes(">");else bytes("\015\nOK\015\n");
 end
 wait(!start);
end
initial begin repeat(4)@(negedge clk);reset_n=1;wait(polls==2);repeat(20)@(negedge clk);
 if(!ready||captures!=2)$fatal(1,"Cloud readiness/capture");
 $display("PASS station config, TLS start, persistent HTTP polls, telemetry, ready");$finish;
end
initial begin #500000;$fatal(1,"Cloud timeout state %d section %d",dut.state,dut.section);end
endmodule
