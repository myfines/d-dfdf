`timescale 1ns/1ps
module optical_keys_reader #(
 parameter integer HALF_TICKS=135,TIMEOUT_TICKS=270000,BOOT_TICKS=540000000,
 parameter integer POLL_TICKS=27000,RETRY_TICKS=270000,FILTER_SAMPLES=2,
 parameter ACTIVE_LOW=1
)(input wire clk,reset_n,inout wire scl,sda,output reg [7:0] keys_n,raw_status,
 output reg valid,error);
 localparam BOOT=0,WRITE=1,WRITE_WAIT=2,READ=3,READ_WAIT=4,PAUSE=5,RETRY=6;
 localparam CW=$clog2(FILTER_SAMPLES+1);
 reg [2:0] state;reg [31:0] timer;reg start,read_command;
 reg [7:0] candidate;reg [CW-1:0] counts[0:7],good_count;
 wire busy,done,ok;wire [15:0] data;wire [7:0] mapped;
 genvar n;
 generate for(n=0;n<8;n=n+1)begin: reverse_channels
  assign mapped[n]=ACTIVE_LOW?data[15-n]:~data[15-n];
 end endgenerate
 i2c_register_bus #(.HALF_TICKS(HALF_TICKS),.TIMEOUT_TICKS(TIMEOUT_TICKS),.ADDRESS(7'h12)) bus(
 clk,reset_n,start,32'h30000000,read_command?3'd0:3'd1,read_command?2'd1:2'd0,
 scl,sda,busy,done,ok,data);
 integer k;
 always @(posedge clk)begin
  if(!reset_n)begin
   state<=BOOT;timer<=0;start<=0;read_command<=0;keys_n<=255;raw_status<=255;
   valid<=0;error<=0;candidate<=255;good_count<=0;
   for(k=0;k<8;k=k+1)counts[k]<=0;
  end else begin
   start<=0;
   case(state)
    BOOT:if(timer==BOOT_TICKS-1)begin timer<=0;state<=WRITE;end else timer<=timer+1'b1;
    WRITE:if(!busy)begin read_command<=0;start<=1;state<=WRITE_WAIT;end
    READ:if(!busy)begin read_command<=1;start<=1;state<=READ_WAIT;end
    WRITE_WAIT,READ_WAIT:if(done)begin
     if(!ok)begin
      valid<=0;error<=1;keys_n<=255;raw_status<=255;candidate<=255;good_count<=0;
      for(k=0;k<8;k=k+1)counts[k]<=0;
      timer<=0;state<=RETRY;
     end else if(state==WRITE_WAIT)state<=READ;
     else begin
      raw_status<=data[15:8];error<=0;
      if(good_count>=FILTER_SAMPLES-1)valid<=1;
      else good_count<=good_count+1'b1;
      for(k=0;k<8;k=k+1)begin
       if(FILTER_SAMPLES==1)keys_n[k]<=mapped[k];
       else if(mapped[k]!=candidate[k])begin candidate[k]<=mapped[k];counts[k]<=1;end
       else if(counts[k]>=FILTER_SAMPLES-1)keys_n[k]<=mapped[k];
       else counts[k]<=counts[k]+1'b1;
      end
      timer<=0;state<=PAUSE;
     end
    end
    PAUSE:if(timer==POLL_TICKS-1)begin timer<=0;state<=WRITE;end else timer<=timer+1'b1;
    RETRY:if(timer==RETRY_TICKS-1)begin timer<=0;state<=WRITE;end else timer<=timer+1'b1;
    default:begin state<=BOOT;timer<=0;valid<=0;error<=1;keys_n<=255;end
   endcase
  end
 end
endmodule
