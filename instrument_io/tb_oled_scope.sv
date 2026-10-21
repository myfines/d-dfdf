`timescale 1ns/1ps
module tb_oled_scope;
reg clk=0;always #5 clk=~clk;reg reset_n=0,frame=1;reg signed [15:0] sample=8192;
tri1 scl,sda;wire online;reg ack_enable=0,ack_low=0;integer bit_count=0,bytes=0;reg transfer=0;reg [7:0] shift=0,control=0,expected;integer word_index=0,data_count=0,col,pg;
assign sda=ack_low?1'b0:1'bz;
oled_scope #(.HALF_TICKS(3),.BOOT_TICKS(20),.RETRY_TICKS(40),.REFRESH_TICKS(100)) dut(
 clk,reset_n,frame,sample,8'hfe,8'h35,scl,sda,online);
always @(negedge sda)if(scl===1)begin transfer=1;bit_count=0;word_index=0;end
always @(posedge sda)if(scl===1)transfer=0;
always @(negedge scl)if(transfer)begin
 if(bit_count==8)begin ack_low=ack_enable;end
 else ack_low=0;
end
always @(posedge scl)if(transfer)begin
 if(bit_count==8)begin bit_count=0;bytes=bytes+1;end else begin
 shift={shift[6:0],sda};
 if(bit_count==7)begin
  if(word_index==0 && shift!=8'h78)$fatal(1,"Wrong OLED address");
  if(word_index==1)control=shift;
  if(word_index==2 && control==8'h40 && ack_enable)begin
   col=data_count%128;pg=(data_count%1024)/128;expected=0;
   if(pg==0 && col%16>=2 && col%16<=12)expected=col<16?8'h7e:8'h42;
   else if(pg==1 && col%16>=2 && col%16<=12)expected=(8'h35>>(col/16))&1?8'h3c:0;
   else if(pg==3)expected=1;
   else if(pg==5 && col%8==0)expected=1;
   if(shift!==expected)$fatal(1,"Pixel mismatch index=%0d actual=%h expected=%h",data_count,shift,expected);
   data_count=data_count+1;
  end
  word_index=word_index+1;
 end
 bit_count=bit_count+1;
end
end
initial begin repeat(4)@(negedge clk);reset_n=1;repeat(2000)@(negedge clk);
if(online)$fatal(1,"Missing OLED reported online");ack_enable=1;
wait(online);wait(dut.pixel==1023);repeat(500)@(negedge clk);
if(data_count<1024 || bytes<3000)$fatal(1,"Incomplete display frame");
reset_n=0;@(negedge clk);if(scl!==1||sda!==1)$fatal(1,"Reset failed to release bus");
$display("PASS OLED absence recovery, full refresh, open-drain reset");$finish;end
initial begin #10000000;$fatal(1,"OLED timeout");end
endmodule
