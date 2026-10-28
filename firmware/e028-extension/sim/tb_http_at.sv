`timescale 1ns/1ps
module tb_http_at;
reg clk=0;always #5 clk=~clk;reg reset_n=0,rv=0,busy=0;reg[7:0] rd=0;
wire start,ready,active;wire[7:0] td,volume,diag;wire[6:0] ti;
esp_at_control #(.BOOT_TICKS(10),.WAIT_TICKS(5000)) dut(clk,reset_n,rv,rd,busy,start,td,ready,volume,active,diag,8'h41,ti,,,,,,);
integer mode=0,count=0,length=0,closes=0,responses=0,offset=0;string line="";
task rx(input[7:0] b);begin @(negedge clk);rv=1;rd=b;@(negedge clk);rv=0;end endtask
task bytes(input string s);integer i;begin for(i=0;i<s.len();i=i+1)rx(s[i]);end endtask
initial forever begin
 wait(start);@(negedge clk);busy=1;repeat(3)@(negedge clk);busy=0;
 if(mode==1)begin
  if(td!==(responses==2 && count>=dut.HTTP_STATUS_LENGTH ? 8'h41 : dut.http_rom.rom[offset+count]))$fatal(1,"HTTP ROM byte mismatch %d got %h expected %h",count,td,dut.http_rom.rom[offset+count]);
  count=count+1;
  if(count==length)begin mode=0;responses=responses+1;bytes("\015\nSEND OK\015\n");end
 end else begin
  line={line,td};
  if(td==10)begin
   if(line.substr(0,10)=="AT+CIPSEND=")begin
    length=0;for(integer i=13;i<17;i=i+1)length=length*10+line[i]-48;
    if(length>2048||length<100)$fatal(1,"send length %d",length);
    mode=1;count=0;line="";bytes(">");
   end else begin
    if(line.substr(0,10)=="AT+CIPCLOSE")closes=closes+1;
    line="";bytes("\015\nOK\015\n");
   end
  end
 end
 wait(!start);
end
initial begin repeat(4)@(negedge clk);reset_n=1;wait(ready);repeat(20)@(negedge clk);
 bytes("+IPD,2,16:GET / HTTP/1.1\015\n");
 wait(closes==1);repeat(100)@(negedge clk);
 if(responses!=1)$fatal(1,"response count");
 offset=dut.HTTP_ACK_OFFSET;
 bytes("+IPD,2,21:GET /c/V40 HTTP/1.1\015\n");
 wait(closes==2);repeat(100)@(negedge clk);
 offset=dut.HTTP_STATUS_OFFSET;
 bytes("+IPD,2,22:GET /status HTTP/1.1\015\n");
 wait(closes==3);repeat(100)@(negedge clk);
 if(responses!=3)$fatal(1,"three responses");
 $display("PASS HTTP AT boot, gzip payload exact bytes, bounded CIPSEND, close");$finish;
end
initial begin #3000000;$fatal(1,"HTTP AT timeout state=%d",dut.state);end
endmodule
