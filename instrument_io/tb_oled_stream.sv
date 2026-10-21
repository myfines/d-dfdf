`timescale 1ns/1ps
module tb_oled_stream #(parameter integer HALF=3);
reg clk=0;always #5 clk=~clk;
reg reset_n=0,start=0,ack_enable=1,ack_low=0,stuck=0;
tri1 scl,sda;wire busy,done,ok;wire [9:0] index;
wire [7:0] data=index[7:0]^8'ha5;
integer bits=0,words=0,starts=0,cycles=0;time last_fall=0;reg transfer=0;reg [7:0] shift=0;
assign sda=ack_low?1'b0:1'bz;assign scl=stuck?1'b0:1'bz;
oled_i2c_stream #(.HALF_TICKS(HALF),.TIMEOUT_TICKS(HALF*30000+10000)) dut(
 clk,reset_n,start,data,index,scl,sda,busy,done,ok);
always @(negedge scl)last_fall=$time;
always @(dut.dl)if(reset_n && busy && scl===0 && HALF>=12)
 if($time-last_fall<(HALF/4)*10)$fatal(1,"SDA hold too short");
always @(posedge clk)if(busy)cycles=cycles+1;
always @(negedge sda)if(scl===1)begin transfer=1;bits=0;words=0;starts=starts+1;end
always @(posedge sda)if(scl===1)transfer=0;
always @(negedge scl)if(transfer)ack_low=(bits==8 && ack_enable);
always @(posedge scl)if(transfer)begin
 if(bits==8)begin bits=0;words=words+1;end
 else begin
  shift={shift[6:0],sda};
  if(bits==7 && ack_enable)begin
   if(words==0 && shift!=8'h78)$fatal(1,"Address wrong");
   if(words==1 && shift!=8'h40)$fatal(1,"Control wrong");
   if(words>=2 && shift!==(((words-2)&255)^8'ha5))$fatal(1,"Stream byte order wrong %0d",words);
  end
  bits=bits+1;
 end
end
task launch;begin @(negedge clk);start=1;@(negedge clk);start=0;wait(busy);wait(done);end endtask
initial begin
 repeat(4)@(negedge clk);reset_n=1;launch;
 if(!ok || words!=1026 || starts!=1)$fatal(1,"Incomplete single transaction %0d %0d",words,starts);
 if(cycles>HALF*26000+10000)$fatal(1,"Stream throughput regression");
 ack_enable=0;launch;if(ok)$fatal(1,"NACK ignored");
 stuck=1;launch;if(ok || busy)$fatal(1,"Stuck bus timeout missing");
 reset_n=0;stuck=0;ack_low=0;@(negedge clk);
 if(scl!==1 || sda!==1)$fatal(1,"Reset bus not released");
 $display("PASS OLED stream: 1024 ordered bytes, one START, NACK, timeout, reset");$finish;
end
initial begin #50000000;$fatal(1,"Stream test timeout");end
endmodule
