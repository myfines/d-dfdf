`timescale 1ns/1ps
// SSD1306 128x64, address 0x3C. Actual post-effect audio feeds the waveform.
// Every transaction is bounded. Unplugged/NACK/stuck bus retries independently.
module oled_scope #(parameter integer HALF_TICKS=135,BOOT_TICKS=8100000,
 RETRY_TICKS=27000000,REFRESH_TICKS=2700000)(
 input wire clk,reset_n,frame_tick,input wire signed [15:0] sample,
 input wire [7:0] keys_n,status,inout wire scl,sda,output reg online);
 reg start;reg [7:0] control,byte_data;wire busy,done,ok;wire [15:0] ignored;
 reg [2:0] state;reg [31:0] timer;reg initializing;reg [4:0] init_index;
 reg [2:0] setup;reg [9:0] pixel;reg [6:0] write_index,snapshot_start;
 reg [5:0] wave[0:127],snapshot[0:127];reg [7:0] keys_hold,status_hold;
 wire signed [8:0] scaled=9'sd40-{{2{sample[15]}},sample[15:9]};
 wire [5:0] point=scaled<16?6'd16:scaled>63?6'd63:scaled[5:0];
 wire [2:0] page=pixel[9:7];wire [6:0] column=pixel[6:0];
 wire [6:0] read_index=column+snapshot_start;
 reg [7:0] pixels;integer b,k;
 i2c_register_bus #(.HALF_TICKS(HALF_TICKS),.TIMEOUT_TICKS(HALF_TICKS*256),.ADDRESS(7'h3c)) bus(
 clk,reset_n,start,{control,byte_data,16'd0},3'd2,2'd0,scl,sda,busy,done,ok,ignored);
 function [7:0] init_byte;input [4:0] n;begin case(n)
  5'd0:init_byte=8'hae;
  5'd1:init_byte=8'hd5;
  5'd2:init_byte=8'h80;
  5'd3:init_byte=8'ha8;
  5'd4:init_byte=8'h3f;
  5'd5:init_byte=8'hd3;
  5'd6:init_byte=8'h00;
  5'd7:init_byte=8'h40;
  5'd8:init_byte=8'h8d;
  5'd9:init_byte=8'h14;
  5'd10:init_byte=8'h20;
  5'd11:init_byte=8'h00;
  5'd12:init_byte=8'ha1;
  5'd13:init_byte=8'hc8;
  5'd14:init_byte=8'hda;
  5'd15:init_byte=8'h12;
  5'd16:init_byte=8'h81;
  5'd17:init_byte=8'h40;
  5'd18:init_byte=8'hd9;
  5'd19:init_byte=8'hf1;
  5'd20:init_byte=8'hdb;
  5'd21:init_byte=8'h40;
  5'd22:init_byte=8'ha4;
  5'd23:init_byte=8'ha6;
  5'd24:init_byte=8'haf;
  default:init_byte=0;endcase end endfunction
 function [7:0] setup_byte;input [2:0] n;begin case(n)
  0:setup_byte=8'h21;1:setup_byte=0;2:setup_byte=127;
  3:setup_byte=8'h22;4:setup_byte=0;default:setup_byte=7;endcase end endfunction
 always @*begin
  pixels=0;
  if(page==0)begin if(column[3:0]>=2&&column[3:0]<=12)pixels=keys_hold[column[6:4]]?8'h42:8'h7e;end
  else if(page==1)begin if(column[3:0]>=2&&column[3:0]<=12)pixels=status_hold[column[6:4]]?8'h3c:8'h00;end
  else begin
   for(b=0;b<8;b=b+1)if({page,3'b000}+b==snapshot[read_index])pixels[b]=1;
   if(page==5 && column[2:0]==0)pixels[0]=1;
  end
 end
 always @(posedge clk)begin
  if(!reset_n)begin state<=0;timer<=0;initializing<=1;init_index<=0;setup<=0;pixel<=0;
   start<=0;control<=0;byte_data<=0;online<=0;write_index<=0;snapshot_start<=0;keys_hold<=255;status_hold<=0;
   for(k=0;k<128;k=k+1)begin wave[k]<=40;snapshot[k]<=40;end
  end else begin
   start<=0;
   if(frame_tick)begin wave[write_index]<=point;write_index<=write_index+1'b1;end
   case(state)
    0:if(timer==BOOT_TICKS-1)begin timer<=0;state<=1;end else timer<=timer+1'b1;
    1:if(!busy)begin
      control<=initializing?8'h00:setup<6?8'h00:8'h40;
      byte_data<=initializing?init_byte(init_index):setup<6?setup_byte(setup):pixels;
      start<=1;state<=2;end
    2:if(busy)state<=3;
    3:if(done)begin
      if(!ok)begin online<=0;timer<=0;state<=5;initializing<=1;init_index<=0;end
      else if(initializing)begin
       if(init_index==24)begin initializing<=0;online<=1;setup<=0;state<=4;timer<=0;end
       else begin init_index<=init_index+1'b1;state<=1;end
      end else if(setup<6)begin setup<=setup+1'b1;state<=1;end
      else if(pixel==1023)begin state<=4;timer<=0;end
      else begin pixel<=pixel+1'b1;state<=1;end
    end
    4:if(timer==REFRESH_TICKS-1)begin
      for(k=0;k<128;k=k+1)snapshot[k]<=wave[k];
      snapshot_start<=write_index;
      keys_hold<=keys_n;status_hold<=status;setup<=0;pixel<=0;timer<=0;state<=1;
     end else timer<=timer+1'b1;
    5:if(timer==RETRY_TICKS-1)begin timer<=0;state<=1;end else timer<=timer+1'b1;
    default:state<=0;
   endcase
  end
 end
endmodule
