`timescale 1ns/1ps
// S=85-byte legacy / G=96-byte gesture snapshot, including LF; display samples, not recording.
module wifi_telemetry #(parameter EXTENDED=0)(input wire clk,reset_n,frame_tick,input wire signed [15:0] sample,
 input wire capture,input wire [7:0] keys,flags,input wire [11:0] axis_x,axis_y,
 input wire [7:0] volume,input wire [1:0] timbre,input wire echo_enable,
 input wire [1:0] page,input wire [6:0] index,output reg [7:0] data,
 input wire gesture_active,input wire [7:0] gesture_seq,input wire [9:0] gesture_pinch,gesture_y,input wire [7:0] gesture_confidence);
 reg [7:0] wave[0:31],snapshot[0:31];reg [4:0] write_index,start_index;
 reg [1:0] decimate;reg [15:0] frame_sequence;
 reg active_hold;reg [7:0] seq_hold,confidence_hold;reg [9:0] pinch_hold,gesture_y_hold;
 reg [7:0] keys_hold,flags_hold,volume_hold;reg [11:0] x_hold,y_hold;
 reg [1:0] tone_hold,page_hold;reg echo_hold;integer k;
 wire [4:0] wave_index=((index-20)>>1)+start_index;
 wire [7:0] point=snapshot[wave_index];
 function [7:0] hex_char;input [3:0] nibble;begin hex_char=nibble<10?48+nibble:55+nibble;end endfunction
 always @*begin
  data=10;
  if(index==0)data=EXTENDED?"G":"S";
  else if(index<5)data=hex_char(frame_sequence>>((4-index)*4));
  else if(index<7)data=hex_char(keys_hold>>((6-index)*4));
  else if(index<9)data=hex_char(flags_hold>>((8-index)*4));
  else if(index<12)data=hex_char(x_hold>>((11-index)*4));
  else if(index<15)data=hex_char(y_hold>>((14-index)*4));
  else if(index<17)data=hex_char(volume_hold>>((16-index)*4));
  else if(index==17)data=48+{6'd0,tone_hold};
  else if(index==18)data=48+{7'd0,echo_hold};
  else if(index==19)data=48+{6'd0,page_hold};
  else if(index<84)data=hex_char(index[0]?point[3:0]:point[7:4]);
  else if(EXTENDED)begin
   if(index==84)data=active_hold?"1":"0";
   else if(index<87)data=hex_char(seq_hold>>((86-index)*4));
   else if(index<90)data=hex_char({2'd0,pinch_hold}>>((89-index)*4));
   else if(index<93)data=hex_char({2'd0,gesture_y_hold}>>((92-index)*4));
   else if(index<95)data=hex_char(confidence_hold>>((94-index)*4));
  end
 end
 always @(posedge clk)begin
  if(!reset_n)begin active_hold<=0;seq_hold<=0;confidence_hold<=0;pinch_hold<=0;gesture_y_hold<=0;write_index<=0;start_index<=0;decimate<=0;frame_sequence<=0;
   keys_hold<=0;flags_hold<=0;volume_hold<=255;x_hold<=0;y_hold<=0;tone_hold<=0;echo_hold<=0;page_hold<=0;
   for(k=0;k<32;k=k+1)begin wave[k]<=128;snapshot[k]<=128;end
  end else begin
   if(frame_tick)begin decimate<=decimate+1'b1;
    if(decimate==0)begin wave[write_index]<=sample[15:8]^8'h80;write_index<=write_index+1'b1;end
   end
   if(capture)begin
    active_hold<=gesture_active;seq_hold<=gesture_seq;pinch_hold<=gesture_pinch;gesture_y_hold<=gesture_y;confidence_hold<=gesture_confidence;
    for(k=0;k<32;k=k+1)snapshot[k]<=wave[k];
    start_index<=write_index;frame_sequence<=frame_sequence+1'b1;keys_hold<=keys;flags_hold<=flags;
    x_hold<=axis_x;y_hold<=axis_y;volume_hold<=volume;tone_hold<=timbre;echo_hold<=echo_enable;page_hold<=page;
   end
  end
 end
endmodule
