`timescale 1ns/1ps
// SRAM-only deterministic configuration/recording acceptance stimulus.
module integration_sequence(input wire clk,reset_n,frame_tick,output reg valid,output reg[7:0]kind,output reg[31:0]value);
 reg[19:0]frames;reg exporting;reg[10:0]period;reg[6:0]chunk;
 always @(posedge clk)begin
 if(!reset_n)begin frames<=0;valid<=0;kind<=0;value<=0;exporting<=0;period<=0;chunk<=0;end
 else begin valid<=0;
 if(frame_tick)begin
 if(frames<500000)frames<=frames+1'b1;
 case(frames)
 4:begin valid<=1;kind<="V";value<=64;end
 5:begin valid<=1;kind<="T";value<=1;end
 6:begin valid<=1;kind<="F";value<=0;end
 7:begin valid<=1;kind<="M";value<=0;end
 8:begin valid<=1;kind<="G";value<=32'h19CDA074;end
 9:begin valid<=1;kind<="U";value<=32'h10001F0F;end
 10:begin valid<=1;kind<="W";value<=32'hFF0000FF;end
 11:begin valid<=1;kind<="W";value<=32'h000C1418;end
 12:begin valid<=1;kind<="W";value<=32'h01101405;end
 13:begin valid<=1;kind<="W";value<=32'h02FF0AF7;end
 14:begin valid<=1;kind<="W";value<=32'hFF0103FD;end
 16:begin valid<=1;kind<="R";value<=1;end
 65000:begin valid<=1;kind<="C";value<=32'h10010011;end
 105000:begin exporting<=1;period<=0;chunk<=0;end
 400000:begin valid<=1;kind<="R";value<=0;end
 endcase
 if(exporting)begin
 if(period==0)begin valid<=1;kind<="C";value<={8'h10,8'h02,1'b0,chunk,(8'h12^{1'b0,chunk})};end
 if(period==1874)begin period<=0;if(chunk==127)exporting<=0;else chunk<=chunk+1'b1;end
 else period<=period+1'b1;
 end
 end end end
endmodule

module diagnostic_packet_uart(input wire clk,reset_n,input wire[7:0]data,
 output reg[6:0]index,output reg capture,output wire tx);
 reg[19:0]timer;reg[2:0]state;reg start;reg[7:0]tx_data;wire busy;
 uart8n1 uart(clk,reset_n,1'b1,start,tx_data,tx,busy,,);
 always @(posedge clk)begin
 if(!reset_n)begin timer<=0;state<=0;start<=0;index<=0;capture<=0;tx_data<=0;end
 else begin start<=0;capture<=0;
 case(state)
 0:if(timer==540000)begin timer<=0;index<=0;capture<=1;state<=1;end else timer<=timer+1'b1;
 1:state<=2;
 2:if(!busy && !start)begin tx_data<=data;start<=1;state<=3;end
 3:if(busy)state<=4;
 4:if(!busy)begin if(index==95)state<=0;else begin index<=index+1'b1;state<=1;end end
 default:state<=0;
 endcase
 end end
endmodule

