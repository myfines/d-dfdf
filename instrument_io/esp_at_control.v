`timescale 1ns/1ps
// Local WPA2 demo AP/TCP server; config retries never stall the audio core.
// Demo password is public configuration, not a user credential.
module esp_at_control #(parameter integer BOOT_TICKS=54000000,WAIT_TICKS=27000000,LEASE_TICKS=135000000)(
 input wire clk,reset_n,rx_valid,input wire [7:0] rx_data,input wire tx_busy,
 output reg tx_start,output reg [7:0] tx_data,output reg ready,
 output reg [7:0] volume,output wire remote_active,output wire [7:0] diagnostic);
 reg [2:0] state,command_index;reg [6:0] index;reg [31:0] timer,lease;
 reg [2:0] boot_match;
 reg rx_seen,timed_out;
 assign diagnostic={ready,rx_seen,timed_out,2'b00,command_index};
 reg [1:0] reply;wire update;wire [7:0] requested;
 assign remote_active=lease!=0;
 esp_volume_parser parser(clk,reset_n && ready,rx_valid,rx_data,update,requested);
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
  if(!reset_n)begin rx_seen<=0;timed_out<=0;state<=0;command_index<=0;index<=0;timer<=0;reply<=0;boot_match<=0;ready<=0;tx_start<=0;tx_data<=0;volume<=255;lease<=0;end
  else begin
   tx_start<=0;
   if(lease!=0)begin lease<=lease-1'b1;if(lease==1)volume<=255;end
   if(update)begin volume<=requested;lease<=LEASE_TICKS;end
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
    5:begin end
    default:state<=0;
   endcase
   if(rx_valid && ready && boot_match==6 && rx_data==10)begin
    ready<=0;state<=0;timer<=0;command_index<=0;index<=0;reply<=0;volume<=255;lease<=0;
   end
  end
 end
endmodule
