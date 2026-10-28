`timescale 1ns/1ps
module tb_wifi_link;
reg clk=0;always #5 clk=~clk;reg reset_n=0,rv=0,busy=0;reg [7:0] rd=0;
wire start,ready,active,echo,capture;wire [7:0] td,volume,diag,telemetry;
wire [6:0] index;wire [1:0] tone,page;wire [3:0] keys;wire [2:0] overrides;
integer packets=0,remaining=0;reg [8*64-1:0] command=0;reg [8*85-1:0] payload=0;
esp_at_control #(.BOOT_TICKS(10),.WAIT_TICKS(300),.LEASE_TICKS(5000),.SEND_TICKS(1000)) dut(
 clk,reset_n,rv,rd,busy,start,td,ready,volume,active,diag,
 telemetry,index,capture,tone,page,echo,keys,overrides);
wifi_telemetry source(clk,reset_n,1'b1,16'sd8192,capture,8'h0f,8'h81,12'h012,12'h345,volume,tone,echo,page,index,telemetry,1'b0,8'd0,10'd0,10'd0,8'd0);
task rx(input [7:0] b);begin @(negedge clk);rd=b;rv=1;@(negedge clk);rv=0;end endtask
task send(input [8*128-1:0] s);integer i;begin for(i=127;i>=0;i=i-1)if(s[i*8+:8]!=0)rx(s[i*8+:8]);end endtask
always begin
 wait(start);@(negedge clk);busy=1;repeat(2)@(negedge clk);busy=0;
 if(remaining!=0)begin
  payload={payload[8*84-1:0],td};remaining=remaining-1;
  if(remaining==0)begin packets=packets+1;send("SEND OK\015\012");end
 end else begin
  command={command[8*63-1:0],td};
  if(td==10)begin
   if(command=="AT+CIPSEND=2,85\015\012")begin remaining=85;rx(62);end
   else if(command=="AT\015\012" || command=="ATE0\015\012" || command=="AT+CWMODE_CUR=2\015\012" || command=="AT+CWSAP_CUR=\"FPGA-Instrument\",\"fpga-demo-2026\",6,3\015\012" || command=="AT+CIPMUX=1\015\012" || command=="AT+CIPSERVER=1,9000\015\012")send("OK\015\012");
   else $fatal(1,"Unexpected AT command: %0s",command);
   command=0;
  end
 end
 wait(!start);
end
initial begin
 repeat(4)@(negedge clk);reset_n=1;wait(ready);repeat(10)@(negedge clk);
 send("+IPD,2,20:V80\nT02\nE01\nK03\nP01\n");repeat(5)@(negedge clk);
 if(volume!=128||tone!=2||!echo||keys!=3||page!=1||overrides!=7)$fatal(1,"Remote controls not applied");
 wait(packets==1);if(payload[8*85-1-:8]!="S" || payload[7:0]!=10)$fatal(1,"Telemetry framing");
 if(payload[8*70-1-:16]!="80")$fatal(1,"Actual volume missing");
 repeat(6000)@(negedge clk);
 if(active || keys!=0 || overrides!=0 || volume!=255)$fatal(1,"Disconnect lease did not fail local");
 $display("PASS bidirectional ESP: exact AT config, CIPSEND prompt, 85-byte actual state, SEND OK, lease release");$finish;
end
initial begin #1000000;$fatal(1,"WiFi link timeout");end
endmodule

