`timescale 1ns/1ps
// Local WPA2 demo AP/TCP server; config retries never stall the audio core.
// Demo password is public configuration, not a user credential.
module esp_at_control #(parameter integer BOOT_TICKS=54000000,WAIT_TICKS=27000000,LEASE_TICKS=135000000,SEND_TICKS=2700000,TELEMETRY_BYTES=85)(
 input wire clk,reset_n,rx_valid,input wire [7:0] rx_data,input wire tx_busy,
 output reg tx_start,output reg [7:0] tx_data,output reg ready,
 output reg [7:0] volume,output wire remote_active,output wire [7:0] diagnostic,
 input wire [7:0] telemetry_data,output wire [6:0] telemetry_index,output reg telemetry_capture,
 output reg [1:0] remote_timbre,remote_page,output reg remote_echo,
 output reg [3:0] remote_keys,output reg [2:0] overrides);
 reg [3:0] state;reg [2:0] command_index;reg [6:0] index;reg [31:0] timer,lease;
 reg [2:0] boot_match;
 reg rx_seen,timed_out;
 assign diagnostic={ready,rx_seen,timed_out,2'b00,command_index};
 reg [1:0] reply;wire update,command_valid;wire [7:0] requested,kind,value;wire [2:0] source_client;
 reg [2:0] target_client,send_client;reg [31:0] send_timer;
 assign telemetry_index=index;
 function [7:0] send_command_byte;input [6:0] pos;begin case(pos)
  0:send_command_byte="A";1:send_command_byte="T";2:send_command_byte="+";
  3:send_command_byte="C";4:send_command_byte="I";5:send_command_byte="P";
  6:send_command_byte="S";7:send_command_byte="E";8:send_command_byte="N";
  9:send_command_byte="D";10:send_command_byte="=";11:send_command_byte=48+{5'd0,send_client};
  12:send_command_byte=",";13:send_command_byte=48+(TELEMETRY_BYTES/10);14:send_command_byte=48+(TELEMETRY_BYTES%10);
  15:send_command_byte=13;default:send_command_byte=10;
 endcase end endfunction
 assign remote_active=lease!=0;
 esp_volume_parser parser(clk,reset_n && ready,rx_valid,rx_data,update,requested,command_valid,kind,value,source_client);
 function [6:0] command_length;input [2:0] n;begin case(n)
   3'd0:command_length=7'd4;
   3'd1:command_length=7'd6;
   3'd2:command_length=7'd17;
   3'd3:command_length=7'd53;
   3'd4:command_length=7'd13;
   3'd5:command_length=7'd21;
   default:command_length=0;endcase end endfunction
 function [7:0] command_byte;input [2:0] n;input [5:0] pos;begin case({n,pos})
   9'd0:command_byte=8'd65;
   9'd1:command_byte=8'd84;
   9'd2:command_byte=8'd13;
   9'd3:command_byte=8'd10;
   9'd64:command_byte=8'd65;
   9'd65:command_byte=8'd84;
   9'd66:command_byte=8'd69;
   9'd67:command_byte=8'd48;
   9'd68:command_byte=8'd13;
   9'd69:command_byte=8'd10;
   9'd128:command_byte=8'd65;
   9'd129:command_byte=8'd84;
   9'd130:command_byte=8'd43;
   9'd131:command_byte=8'd67;
   9'd132:command_byte=8'd87;
   9'd133:command_byte=8'd77;
   9'd134:command_byte=8'd79;
   9'd135:command_byte=8'd68;
   9'd136:command_byte=8'd69;
   9'd137:command_byte=8'd95;
   9'd138:command_byte=8'd67;
   9'd139:command_byte=8'd85;
   9'd140:command_byte=8'd82;
   9'd141:command_byte=8'd61;
   9'd142:command_byte=8'd50;
   9'd143:command_byte=8'd13;
   9'd144:command_byte=8'd10;
   9'd192:command_byte=8'd65;
   9'd193:command_byte=8'd84;
   9'd194:command_byte=8'd43;
   9'd195:command_byte=8'd67;
   9'd196:command_byte=8'd87;
   9'd197:command_byte=8'd83;
   9'd198:command_byte=8'd65;
   9'd199:command_byte=8'd80;
   9'd200:command_byte=8'd95;
   9'd201:command_byte=8'd67;
   9'd202:command_byte=8'd85;
   9'd203:command_byte=8'd82;
   9'd204:command_byte=8'd61;
   9'd205:command_byte=8'd34;
   9'd206:command_byte=8'd70;
   9'd207:command_byte=8'd80;
   9'd208:command_byte=8'd71;
   9'd209:command_byte=8'd65;
   9'd210:command_byte=8'd45;
   9'd211:command_byte=8'd73;
   9'd212:command_byte=8'd110;
   9'd213:command_byte=8'd115;
   9'd214:command_byte=8'd116;
   9'd215:command_byte=8'd114;
   9'd216:command_byte=8'd117;
   9'd217:command_byte=8'd109;
   9'd218:command_byte=8'd101;
   9'd219:command_byte=8'd110;
   9'd220:command_byte=8'd116;
   9'd221:command_byte=8'd34;
   9'd222:command_byte=8'd44;
   9'd223:command_byte=8'd34;
   9'd224:command_byte=8'd102;
   9'd225:command_byte=8'd112;
   9'd226:command_byte=8'd103;
   9'd227:command_byte=8'd97;
   9'd228:command_byte=8'd45;
   9'd229:command_byte=8'd100;
   9'd230:command_byte=8'd101;
   9'd231:command_byte=8'd109;
   9'd232:command_byte=8'd111;
   9'd233:command_byte=8'd45;
   9'd234:command_byte=8'd50;
   9'd235:command_byte=8'd48;
   9'd236:command_byte=8'd50;
   9'd237:command_byte=8'd54;
   9'd238:command_byte=8'd34;
   9'd239:command_byte=8'd44;
   9'd240:command_byte=8'd54;
   9'd241:command_byte=8'd44;
   9'd242:command_byte=8'd51;
   9'd243:command_byte=8'd13;
   9'd244:command_byte=8'd10;
   9'd256:command_byte=8'd65;
   9'd257:command_byte=8'd84;
   9'd258:command_byte=8'd43;
   9'd259:command_byte=8'd67;
   9'd260:command_byte=8'd73;
   9'd261:command_byte=8'd80;
   9'd262:command_byte=8'd77;
   9'd263:command_byte=8'd85;
   9'd264:command_byte=8'd88;
   9'd265:command_byte=8'd61;
   9'd266:command_byte=8'd49;
   9'd267:command_byte=8'd13;
   9'd268:command_byte=8'd10;
   9'd320:command_byte=8'd65;
   9'd321:command_byte=8'd84;
   9'd322:command_byte=8'd43;
   9'd323:command_byte=8'd67;
   9'd324:command_byte=8'd73;
   9'd325:command_byte=8'd80;
   9'd326:command_byte=8'd83;
   9'd327:command_byte=8'd69;
   9'd328:command_byte=8'd82;
   9'd329:command_byte=8'd86;
   9'd330:command_byte=8'd69;
   9'd331:command_byte=8'd82;
   9'd332:command_byte=8'd61;
   9'd333:command_byte=8'd49;
   9'd334:command_byte=8'd44;
   9'd335:command_byte=8'd57;
   9'd336:command_byte=8'd48;
   9'd337:command_byte=8'd48;
   9'd338:command_byte=8'd48;
   9'd339:command_byte=8'd13;
   9'd340:command_byte=8'd10;
   default:command_byte=0;endcase end endfunction
 always @(posedge clk)begin
  if(!reset_n)begin rx_seen<=0;timed_out<=0;state<=0;command_index<=0;index<=0;timer<=0;reply<=0;boot_match<=0;ready<=0;tx_start<=0;tx_data<=0;volume<=255;lease<=0;remote_timbre<=0;remote_page<=0;remote_echo<=0;remote_keys<=0;overrides<=0;send_timer<=0;target_client<=0;send_client<=0;telemetry_capture<=0;end
  else begin
   tx_start<=0;telemetry_capture<=0;
   if(ready && send_timer!=SEND_TICKS-1)send_timer<=send_timer+1'b1;
   if(lease!=0)begin lease<=lease-1'b1;if(lease==1)begin volume<=255;remote_keys<=0;overrides<=0;end end
   if(command_valid)begin
    lease<=LEASE_TICKS;target_client<=source_client;
    case(kind)
     "V":volume<=value;
     "T":begin remote_timbre<=value[1:0];overrides[0]<=1;end
     "E":begin remote_echo<=value[0];overrides[1]<=1;end
     "P":begin remote_page<=value[1:0];overrides[2]<=1;end
     "K":remote_keys<=value[3:0];
     "L":begin lease<=0;remote_keys<=0;overrides<=0;volume<=255;end
     default:begin end
    endcase
   end
   if(rx_valid)begin
    rx_seen<=1;
    case(boot_match)
     0:boot_match<=rx_data==114?1:0;
     1:boot_match<=rx_data==101?2:0;
     2:boot_match<=rx_data==97?3:0;
     3:boot_match<=rx_data==100?4:0;
     4:boot_match<=rx_data==121?5:0;
     5:boot_match<=rx_data==13?6:0;
     default:boot_match<=0;
    endcase
    if(rx_data==79)reply<=1;
    else if(reply==1&&rx_data==75)reply<=2;
    else if(reply==2&&rx_data==13)reply<=3;
    else if(!(reply==3&&rx_data==10))reply<=0;
   end
   case(state)
    0:if(timer==BOOT_TICKS-1)begin timer<=0;index<=0;state<=1;reply<=0;end else timer<=timer+1'b1;
    1:if(!tx_busy && !tx_start)begin
      tx_data<=command_byte(command_index,index[5:0]);tx_start<=1;state<=2;end
    2:if(tx_busy)state<=3;
    3:if(!tx_busy)begin if(index==command_length(command_index)-1)begin timer<=0;state<=4;end else begin index<=index+1'b1;state<=1;end end
    4:begin
      if(rx_valid && reply==3 && rx_data==10)begin
       if(command_index==5)begin ready<=1;state<=5;end
       else begin command_index<=command_index+1'b1;index<=0;state<=1;reply<=0;end
      end else if(timer==WAIT_TICKS-1)begin timed_out<=1;state<=0;timer<=0;command_index<=0;ready<=0;end
      else timer<=timer+1'b1;
    end
    5:if(lease!=0 && send_timer==SEND_TICKS-1)begin
     send_timer<=0;send_client<=target_client;telemetry_capture<=1;index<=0;state<=6;reply<=0;
    end
    6:if(!tx_busy && !tx_start)begin tx_data<=send_command_byte(index);tx_start<=1;state<=7;end
    7:if(tx_busy)state<=8;
    8:if(!tx_busy)begin if(index==16)begin timer<=0;state<=9;end else begin index<=index+1'b1;state<=6;end end
    9:if(rx_valid && rx_data==62)begin index<=0;state<=10;timer<=0;end
      else if(timer==WAIT_TICKS-1)begin state<=5;timer<=0;end else timer<=timer+1'b1;
    10:if(!tx_busy && !tx_start)begin tx_data<=telemetry_data;tx_start<=1;state<=11;end
    11:if(tx_busy)state<=12;
    12:if(!tx_busy)begin if(index==TELEMETRY_BYTES-1)begin timer<=0;reply<=0;state<=13;end else begin index<=index+1'b1;state<=10;end end
    13:if(rx_valid && reply==3 && rx_data==10)begin state<=5;timer<=0;end
       else if(timer==WAIT_TICKS-1)begin state<=5;timer<=0;end else timer<=timer+1'b1;
    default:state<=0;
   endcase
   if(rx_valid && ready && boot_match==6 && rx_data==10)begin
    ready<=0;state<=0;timer<=0;command_index<=0;index<=0;reply<=0;volume<=255;lease<=0;remote_keys<=0;overrides<=0;
   end
  end
 end
endmodule
