`timescale 1ns/1ps
module tb_oled_scope #(parameter integer OLED_HALF=3);
reg clk=0;always #5 clk=~clk;reg reset_n=0,frame=1;reg signed [15:0] sample=8192;
tri1 scl,sda;wire online;reg ack_enable=0,ack_low=0;integer bit_count=0,bytes=0;reg transfer=0;reg [7:0] shift=0,control=0,expected;integer word_index=0,data_count=0,col,pg;reg check_pixel;integer frame_start=0,frame_end=0,second_start=0;
integer dump=0,phase=0;reg preview=0;reg [1023:0] frame_path;
initial begin
 preview=$test$plusargs("PREVIEW");
 if($value$plusargs("FRAME=%s",frame_path))dump=$fopen(frame_path,"w");
end
always @(negedge clk)if(preview)begin phase=phase+1;sample=$rtoi(12000*$sin(6.283185307179586*phase/256.0));end
assign sda=ack_low?1'b0:1'bz;
oled_scope #(.HALF_TICKS(OLED_HALF),.BOOT_TICKS(20),.RETRY_TICKS(40),.REFRESH_TICKS(100)) dut(
 clk,reset_n,frame,sample,8'hfe,8'h35,scl,sda,online,2'd1,8'h80,8'h42);
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
  if(word_index>=2 && control==8'h40 && ack_enable)begin
   if(data_count==0)frame_start=$time;
   if(data_count==1024)second_start=$time;
   col=data_count%128;pg=(data_count%1024)/128;expected=0;check_pixel=1;
   if(pg==0 && col%16>=2&&col%16<=12)expected=col<16?8'h7e:8'h42;
   else if(pg==1 && col>=96)expected=col<104?8'h7e:8'h42;
   else if(pg==1 && col%16>=2&&col%16<=12)expected=(8'h35>>(col/16))&1?8'h3c:0;
   else if(pg==2)begin
    case(col)
     0,1,3,4:expected=1;2:expected=8'h7f;
     6,10:expected=8'h3e;7,8,9:expected=8'h41;
     12,16:expected=8'h7f;13:expected=2;14:expected=4;15:expected=8;
     18:expected=8'h7f;19,20,21:expected=8'h49;22:expected=8'h41;
     30:expected=8'h42;31:expected=8'h61;32:expected=8'h51;33:expected=8'h49;34:expected=8'h46;
     72,76:expected=8'h36;73,74,75:expected=8'h49;
     78,82:expected=8'h3e;79:expected=8'h51;80:expected=8'h49;81:expected=8'h45;
     default:check_pixel=0;
    endcase
   end else if(pg==3)begin
    case(col)
     0,4:expected=8'h3f;1,3:expected=8'h40;2:expected=8'h38;
     72,76:expected=8'h07;73,75:expected=8'h08;74:expected=8'h70;
     default:check_pixel=0;
    endcase
   end else if(pg==5)expected=1;
   else if(pg==6 && col%16==0)expected=1;
   if(preview && (pg>=4 || (pg==1 && col>=96)))check_pixel=0;
   if(dump!=0 && data_count<1024)$fdisplay(dump,"%02x",shift);
   if(check_pixel && shift!==expected)$fatal(1,"Pixel mismatch index=%0d actual=%h expected=%h",data_count,shift,expected);
   data_count=data_count+1;
  end
  word_index=word_index+1;
 end
 bit_count=bit_count+1;
end
end
initial begin repeat(4)@(negedge clk);reset_n=1;repeat(2000)@(negedge clk);
if(online)$fatal(1,"Missing OLED reported online");ack_enable=1;
wait(online);wait(data_count==1024);frame_end=$time;wait(data_count==2048);wait(dut.state==4);repeat(5)@(negedge clk);
if(data_count<1024 || bytes<1026)$fatal(1,"Incomplete display frame");
reset_n=0;@(negedge clk);if(scl!==1||sda!==1)$fatal(1,"Reset failed to release bus");
$display("OLED HALF_TICKS=%0d transfer_cycles=%0d period_cycles=%0d equivalent_27MHz_fps=%f",OLED_HALF,(frame_end-frame_start)/10,(second_start-frame_start)/10,27000000.0/((second_start-frame_start)/10));
if(dump!=0)$fclose(dump);
$display("PASS OLED absence recovery, full refresh, open-drain reset");$finish;end
initial begin #100000000;$fatal(1,"OLED timeout");end
endmodule
