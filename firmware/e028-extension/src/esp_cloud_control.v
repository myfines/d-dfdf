`timescale 1ns/1ps
// ESP AT station + outbound persistent HTTPS polling. No AP or host Wi-Fi changes.
module esp_cloud_control #(
 parameter BOOT_TICKS=54000000,WAIT_TICKS=216000000,JOIN_TICKS=810000000,POLL_TICKS=5400000,
 parameter TELEMETRY_BYTES=96
)(input wire clk,reset_n,rx_valid,input wire[7:0] rx_data,input wire tx_busy,
 output reg tx_start,output reg[7:0] tx_data,output reg ready,
 input wire[7:0] telemetry_data,output wire[6:0] telemetry_index,output reg telemetry_capture,
 output wire[7:0] diagnostic);
 reg[2:0] state;reg[3:0] section;reg[9:0] index;reg[31:0] timer;
 reg[1:0] reply;reg[2:0] marker;reg completed;reg[2:0] failures;
 wire[7:0] config_data;wire[9:0] config_length;
 esp_cloud_config config_rom(clk,section,index,config_data,config_length);
 assign telemetry_index=index-config_length;
 assign diagnostic={ready,state,section};
 always @(posedge clk)begin
 if(!reset_n)begin state<=0;section<=0;index<=0;timer<=0;reply<=0;marker<=0;completed<=0;failures<=0;tx_start<=0;tx_data<=0;ready<=0;telemetry_capture<=0;end
 else begin
 tx_start<=0;telemetry_capture<=0;
 if(rx_valid)begin
  if(rx_data==79)reply<=1;else if(reply==1&&rx_data==75)reply<=2;else if(reply==2&&rx_data==13)reply<=3;else if(!(reply==3&&rx_data==10))reply<=0;
  case(marker)
   0:marker<=rx_data=="Z"?1:0;
   1:marker<=rx_data=="0"?2:0;
   2:marker<=rx_data=="0"?3:0;
   3:if(rx_data==10)begin completed<=1;marker<=0;end else if(rx_data!=13)marker<=0;
   default:marker<=0;
  endcase
 end
 case(state)
 0:if(timer==BOOT_TICKS-1)begin timer<=0;section<=0;index<=0;state<=1;end else timer<=timer+1'b1;
 1:state<=2; // registered ROM latency
 2:if(!tx_busy&&!tx_start)begin tx_data<=section==7 && index>=config_length?telemetry_data:config_data;tx_start<=1;state<=3;end
 3:if(tx_busy)state<=4;
 4:if(!tx_busy)begin
  if(index==(section==7?config_length+TELEMETRY_BYTES-1:config_length-1))begin timer<=0;reply<=0;state<=5;end
  else begin index<=index+1'b1;state<=1;end
 end
 5:begin
  if(section==6 && rx_valid && rx_data==62)begin section<=7;index<=0;telemetry_capture<=1;completed<=0;state<=1;timer<=0;end
  else if(section==7 && completed)begin ready<=1;failures<=0;completed<=0;state<=6;timer<=0;end
  else if(section!=6 && section!=7 && rx_valid && reply==3 && rx_data==10)begin
   if(section==8)section<=5;else section<=section+1'b1;
   index<=0;state<=1;timer<=0;
  end else if(timer==(section==3?JOIN_TICKS-1:WAIT_TICKS-1))begin
   ready<=0;timer<=0;index<=0;completed<=0;reply<=0;
   if(section<5 || failures==3)begin state<=0;failures<=0;end
   else begin section<=section==8?5:8;state<=1;failures<=failures+1'b1;end
  end else timer<=timer+1'b1;
 end
 6:if(timer==POLL_TICKS-1)begin section<=6;index<=0;timer<=0;state<=1;end else timer<=timer+1'b1;
 default:state<=0;
 endcase
 end end
endmodule
