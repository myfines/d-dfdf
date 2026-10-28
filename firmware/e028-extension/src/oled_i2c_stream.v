`timescale 1ns/1ps
// SSD1306 horizontal RAM stream: 0x78,0x40,1024 data bytes, one STOP.
// Independent bounded open-drain master; caller keeps data stable for index.
module oled_i2c_stream #(parameter integer HALF_TICKS=36,TIMEOUT_TICKS=2700000,DATA_BYTES=1024,parameter [7:0] CONTROL=8'h40)(
 input wire clk,reset_n,start,input wire [7:0] data,output reg [9:0] index,
 inout wire scl,sda,output reg busy,done,ok);
 localparam IDLE=0,WAIT_BUS=1,START=2,LOAD=3,LOW=4,HIGH=5,
  ACK_LOW=6,ACK_HIGH=7,STOP_LOW=8,STOP_HIGH=9,RELEASE=10;
 reg [3:0] state;reg sl,dl,sm,ss,dm,ds;
 reg [31:0] timer,watchdog;reg [10:0] ordinal;reg [7:0] shift;reg [2:0] bit_left;
 assign scl=sl?1'b0:1'bz;assign sda=dl?1'b0:1'bz;
 always @(posedge clk)begin
  sm<=scl;ss<=sm;dm<=sda;ds<=dm;
  if(!reset_n)begin state<=IDLE;sl<=0;dl<=0;busy<=0;done<=0;ok<=0;
   sm<=1;ss<=1;dm<=1;ds<=1;timer<=0;watchdog<=0;ordinal<=0;index<=0;shift<=0;bit_left<=7;end
  else begin
   done<=0;
   if(busy)watchdog<=watchdog+1'b1;
   if(busy && watchdog==TIMEOUT_TICKS-1)begin
    busy<=0;done<=1;ok<=0;sl<=0;dl<=0;state<=IDLE;
   end else case(state)
    IDLE:begin sl<=0;dl<=0;timer<=0;
     if(start)begin busy<=1;ok<=1;index<=0;ordinal<=0;watchdog<=0;state<=WAIT_BUS;end end
    WAIT_BUS:if(ss&&ds)begin if(timer==HALF_TICKS-1)begin timer<=0;dl<=1;state<=START;end else timer<=timer+1'b1;end else timer<=0;
    START:if(timer==HALF_TICKS-1)begin timer<=0;sl<=1;state<=LOAD;end else timer<=timer+1'b1;
    LOAD:begin shift<=ordinal==0?8'h78:ordinal==1?CONTROL:data;bit_left<=7;state<=LOW;timer<=0;end
    LOW:begin if(timer==HALF_TICKS/4)dl<=!shift[7];
     if(timer==HALF_TICKS-1)begin timer<=0;sl<=0;state<=HIGH;end else timer<=timer+1'b1;end
    HIGH:if(ss)begin
     if(timer==HALF_TICKS-1)begin timer<=0;sl<=1;
      if(bit_left==0)state<=ACK_LOW;
      else begin shift<={shift[6:0],1'b0};bit_left<=bit_left-1'b1;state<=LOW;end
     end else timer<=timer+1'b1;
    end else timer<=0;
    ACK_LOW:begin if(timer==HALF_TICKS/4)dl<=0;
     if(timer==HALF_TICKS-1)begin timer<=0;sl<=0;state<=ACK_HIGH;end else timer<=timer+1'b1;end
    ACK_HIGH:if(ss)begin
     if(timer==HALF_TICKS-1)begin timer<=0;sl<=1;
      if(ds || ordinal==DATA_BYTES+1)begin if(ds)ok<=0;state<=STOP_LOW;end
      else begin ordinal<=ordinal+1'b1;if(ordinal>=2)index<=index+1'b1;state<=LOAD;end
     end else timer<=timer+1'b1;
    end else timer<=0;
    STOP_LOW:begin if(timer==HALF_TICKS/4)dl<=1;
     if(timer==HALF_TICKS-1)begin timer<=0;sl<=0;state<=STOP_HIGH;end else timer<=timer+1'b1;end
    STOP_HIGH:if(ss)begin if(timer==HALF_TICKS-1)begin timer<=0;dl<=0;state<=RELEASE;end else timer<=timer+1'b1;end else timer<=0;
    RELEASE:if(timer==HALF_TICKS-1)begin busy<=0;done<=1;state<=IDLE;end else timer<=timer+1'b1;
    default:begin state<=IDLE;busy<=0;done<=1;ok<=0;sl<=0;dl<=0;end
   endcase
  end
 end
endmodule
