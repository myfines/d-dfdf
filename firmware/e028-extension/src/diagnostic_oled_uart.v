`timescale 1ns/1ps
// SRAM diagnostic only: an unchanged A frame followed by Z + 8 status bytes.
// Z bytes: version50, OLED-online, screen, {note-valid,playing}, note,
// selected bank, decoded target keys, suggested bank. Frozen per packet.
module e050_packet_uart(input wire clk,reset_n,input wire[7:0]data,
 input wire[63:0]status,output reg[6:0]index,output reg capture,output wire tx);
 reg[19:0]timer;reg[2:0]state;reg start;reg[7:0]tx_data;wire busy;reg[63:0]held;
 wire[3:0]nibble=held>>((112-index)*4);
 uart8n1 uart(clk,reset_n,1'b1,start,tx_data,tx,busy,,);
 always @(posedge clk)begin
  if(!reset_n)begin timer<=0;state<=0;start<=0;index<=0;capture<=0;tx_data<=0;held<=0;end
  else begin start<=0;capture<=0;
   case(state)
    0:if(timer==540000)begin timer<=0;index<=0;capture<=1;held<=status;state<=1;end else timer<=timer+1'b1;
    1:state<=2;
    2:if(!busy && !start)begin
      tx_data<=index<96?data:index==96?"Z":index==113?8'd10:nibble<10?8'd48+nibble:8'd55+nibble;
      start<=1;state<=3;
    end
    3:if(busy)state<=4;
    4:if(!busy)begin if(index==113)state<=0;else begin index<=index+1'b1;state<=1;end end
    default:state<=0;
   endcase
  end
 end
endmodule
