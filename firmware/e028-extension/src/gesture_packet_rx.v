`timescale 1ns/1ps
// Byte-stream boundary: identical framing can be used after UART or a future USB host.
module gesture_packet_rx #(
 parameter integer LEASE_TICKS=6750000, GAP_TICKS=540000,
 parameter integer MIN_CONFIDENCE=60
)(input wire clk,reset_n,byte_valid,input wire [7:0] byte_data,
 output reg active,update,output reg [7:0] seq,
 output reg [9:0] pinch,y,output reg [7:0] confidence);
 reg [2:0] state;reg [2:0] index;
 reg [7:0] body[0:7];reg [15:0] crc;reg [7:0] crc_hi;
 reg [31:0] lease,gap;reg have_seq;
 wire [7:0] advance=body[1]-seq;
 wire [15:0] new_pinch={body[3],body[4]},new_y={body[5],body[6]};
 function [15:0] crc_byte;input [15:0] previous;input [7:0] value;reg [15:0] c;integer bitn;begin
  c=previous^{value,8'd0};for(bitn=0;bitn<8;bitn=bitn+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc_byte=c;
 end endfunction
 always @(posedge clk)begin
  if(!reset_n)begin state<=0;index<=0;crc<=16'hffff;crc_hi<=0;lease<=0;gap<=0;have_seq<=0;active<=0;update<=0;seq<=0;pinch<=0;y<=0;confidence<=0;end
  else begin
   update<=0;
   if(lease!=0)begin lease<=lease-1'b1;if(lease==1)begin active<=0;pinch<=0;y<=0;confidence<=0;have_seq<=0;end end
   if(state!=0)begin
    if(gap==GAP_TICKS-1)begin state<=0;gap<=0;end else gap<=gap+1'b1;
   end
   if(byte_valid)begin
    gap<=0;
    // A byte arriving at/after the gap boundary starts a fresh sync search.
    if(state!=0 && gap>=GAP_TICKS-1)state<=byte_data==8'ha5 ? 1 : 0;
    else case(state)
     0:if(byte_data==8'ha5)state<=1;
     1:if(byte_data==8'h5a)begin state<=2;index<=0;crc<=16'hffff;end else state<=byte_data==8'ha5 ? 1 : 0;
     2:begin body[index]<=byte_data;crc<=crc_byte(crc,byte_data);if(index==7)state<=3;else index<=index+1'b1;end
     3:begin crc_hi<=byte_data;state<=4;end
     4:begin
      state<=0;
      if({crc_hi,byte_data}==crc && body[0]==1 && body[2]<=1 && new_pinch<=1000 && new_y<=1000 && body[7]<=100 &&
        (!have_seq || (advance!=0 && !advance[7])))begin
       update<=1;seq<=body[1];have_seq<=1;lease<=LEASE_TICKS;
       active<=body[2][0] && body[7]>=MIN_CONFIDENCE;
       if(body[2][0] && body[7]>=MIN_CONFIDENCE)begin pinch<=new_pinch[9:0];y<=new_y[9:0];confidence<=body[7];end
       else begin pinch<=0;y<=0;confidence<=0;end
      end
     end
     default:state<=0;
    endcase
   end
  end
 end
endmodule

