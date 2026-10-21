`timescale 1ns/1ps
module tb_wifi_telemetry;
reg clk=0;always #5 clk=~clk;reg reset_n=0,capture=0;reg [6:0] index=0;wire [7:0] data;
integer i;reg [8*20-1:0] prefix="S00010F8101234580210";
// Explicit expected prefix: S,0001,0F,81,012,345,80,2,1,0.
wifi_telemetry dut(clk,reset_n,1'b1,16'sd8192,capture,8'h0f,8'h81,12'h012,12'h345,8'h80,2'd2,1'b1,2'd0,index,data);
initial begin repeat(4)@(negedge clk);reset_n=1;repeat(160)@(negedge clk);
 capture=1;@(negedge clk);capture=0;
 prefix={"S","0001","0F","81","012","345","80","2","1","0"};
 for(i=0;i<85;i=i+1)begin index=i;#1;
  if(i<20 && data!==prefix[(19-i)*8+:8])$fatal(1,"Header field wrong index %0d",i);
  if(i>=20 && i<84 && data!==((i%2)==0?8'h41:8'h30))$fatal(1,"Wave encoding wrong");
  if(i==84 && data!=10)$fatal(1,"Line terminator wrong");
 end
 $display("PASS telemetry: coherent fields, 32 actual audio samples, 85-byte framing");$finish;
end
endmodule
