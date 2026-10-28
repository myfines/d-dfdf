`timescale 1ns/1ps
// SSD1306 128x64, address 0x3C. Actual post-effect audio feeds the waveform.
// Every transaction is bounded. Unplugged/NACK/stuck bus retries independently.
module oled_scope #(parameter integer HALF_TICKS=36,BOOT_TICKS=8100000,
 RETRY_TICKS=27000000,REFRESH_TICKS=27000)(
 input wire clk,reset_n,frame_tick,input wire signed [15:0] sample,
 input wire [7:0] keys_n,status,inout wire scl,sda,output reg online,
 input wire [1:0] timbre,input wire [7:0] volume,diagnostic);
 reg start;reg [7:0] byte_data;wire busy,done,ok;
 reg [2:0] state;reg [31:0] timer;reg initializing;reg [4:0] init_index;
 reg [2:0] setup;wire [9:0] pixel;reg [6:0] write_index,snapshot_start;
 reg [5:0] wave[0:127],snapshot[0:127];reg [7:0] keys_hold,status_hold;
 wire signed [8:0] scaled=9'sd48-{{3{sample[15]}},sample[15:10]};
 wire [5:0] point=scaled<32?6'd32:scaled>63?6'd63:scaled[5:0];
 wire [2:0] page=pixel[9:7];wire [6:0] column=pixel[6:0];
 wire [6:0] read_index=column+snapshot_start;
 reg [7:0] pixels;integer b,k;
 reg stream_start;wire stream_busy,stream_done,stream_ok;
 wire bulk=!initializing && setup==6;
 wire selected_busy=bulk?stream_busy:busy;
 wire selected_done=bulk?stream_done:done;
 wire selected_ok=bulk?stream_ok:ok;
 oled_i2c_stream #(.HALF_TICKS(HALF_TICKS)) stream_bus(
  clk,reset_n,stream_start,pixels,pixel,scl,sda,stream_busy,stream_done,stream_ok);
 reg capture_ready,capturing;reg signed [15:0] previous;
 reg [9:0] trigger_wait;reg [1:0] decimate;
 reg [15:0] peak,peak_hold;
 wire [15:0] magnitude=sample[15]?(~sample+16'd1):sample;
 wire [5:0] previous_point=snapshot[read_index-1'b1];
 wire [5:0] line_low=column==0?snapshot[read_index]:previous_point<snapshot[read_index]?previous_point:snapshot[read_index];
 wire [5:0] line_high=column==0?snapshot[read_index]:previous_point>snapshot[read_index]?previous_point:snapshot[read_index];
 reg [1:0] timbre_hold;reg [7:0] volume_hold,diag_hold;
 reg [7:0] character;wire [7:0] text_pixels;
 function [7:0] hex_char;input [3:0] n;begin hex_char=n<10?48+n:55+n;end endfunction
 function [34:0] glyph;input [7:0] c;begin case(c)
  "T":glyph={7'h01,7'h01,7'h7f,7'h01,7'h01};
  "O":glyph={7'h3e,7'h41,7'h41,7'h41,7'h3e};
  "N":glyph={7'h7f,7'h02,7'h04,7'h08,7'h7f};
  "E":glyph={7'h7f,7'h49,7'h49,7'h49,7'h41};
  "V":glyph={7'h1f,7'h20,7'h40,7'h20,7'h1f};
  "L":glyph={7'h7f,7'h40,7'h40,7'h40,7'h40};
  "W":glyph={7'h3f,7'h40,7'h38,7'h40,7'h3f};
  "I":glyph={7'h00,7'h41,7'h7f,7'h41,7'h00};
  "F":glyph={7'h7f,7'h09,7'h09,7'h09,7'h01};
  "A":glyph={7'h7e,7'h09,7'h09,7'h09,7'h7e};
  "R":glyph={7'h7f,7'h09,7'h19,7'h29,7'h46};
  "X":glyph={7'h63,7'h14,7'h08,7'h14,7'h63};
  "Y":glyph={7'h07,7'h08,7'h70,7'h08,7'h07};
  "D":glyph={7'h7f,7'h41,7'h41,7'h22,7'h1c};
  "B":glyph={7'h7f,7'h49,7'h49,7'h49,7'h36};
  "C":glyph={7'h3e,7'h41,7'h41,7'h41,7'h22};
  "0":glyph={7'h3e,7'h51,7'h49,7'h45,7'h3e};
  "1":glyph={7'h00,7'h42,7'h7f,7'h40,7'h00};
  "2":glyph={7'h42,7'h61,7'h51,7'h49,7'h46};
  "3":glyph={7'h21,7'h41,7'h45,7'h4b,7'h31};
  "4":glyph={7'h18,7'h14,7'h12,7'h7f,7'h10};
  "5":glyph={7'h27,7'h45,7'h45,7'h45,7'h39};
  "6":glyph={7'h3c,7'h4a,7'h49,7'h49,7'h30};
  "7":glyph={7'h01,7'h71,7'h09,7'h05,7'h03};
  "8":glyph={7'h36,7'h49,7'h49,7'h49,7'h36};
  "9":glyph={7'h06,7'h49,7'h49,7'h29,7'h1e};
  ":":glyph={7'h00,7'h36,7'h36,7'h00,7'h00};
  "!":glyph={7'h00,7'h00,7'h5f,7'h00,7'h00};
  default:glyph=0;endcase end endfunction
 wire [34:0] glyph_bits=glyph(character);
 wire [4:0] char_index=column/6;
 wire [2:0] glyph_column=column%6;
 assign text_pixels=glyph_column<5?{1'b0,(glyph_bits >> ((4-glyph_column)*7)) & 7'h7f}:8'd0;
 always @*begin
  character=" ";
  if(page==2)case(char_index)
   0:character="T";1:character="O";2:character="N";3:character="E";4:character=":";
   5:character=49+{6'd0,timbre_hold};
   8:character="V";9:character="O";10:character="L";11:character=":";
   12:character=hex_char(volume_hold[7:4]);13:character=hex_char(volume_hold[3:0]);
   default:character=" ";endcase
  else if(page==3)case(char_index)
   0:character="W";1:character="I";2:character="F";3:character="I";4:character=":";
   5:character=diag_hold[7]?"O":"A";6:character=diag_hold[7]?"N":"T";
   7:character=diag_hold[7]?" ":hex_char({1'b0,diag_hold[2:0]});
   9:character="R";10:character="X";11:character=":";12:character=diag_hold[6]?"Y":"N";
   14:character=diag_hold[5]?"!":" ";default:character=" ";endcase
 end
 wire [9:0] command_index_unused;
 oled_i2c_stream #(.HALF_TICKS(HALF_TICKS),.DATA_BYTES(1),.CONTROL(8'h00)) command_bus(
 clk,reset_n,start,byte_data,command_index_unused,scl,sda,busy,done,ok);
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
  else if(page==1 && column>=96)begin pixels=(column-96)<peak_hold[15:10]?8'h7e:8'h42;end
  else if(page==1)begin if(column[3:0]>=2&&column[3:0]<=12)pixels=status_hold[column[6:4]]?8'h3c:8'h00;end
  else if(page==2 || page==3)pixels=text_pixels;
  else begin
   for(b=0;b<8;b=b+1)if({page,3'b000}+b>=line_low && {page,3'b000}+b<=line_high)pixels[b]=1;
   if(page==6 && column[3:0]==0)pixels[0]=1;
  end
 end
 always @(posedge clk)begin
  if(!reset_n)begin state<=0;timer<=0;initializing<=1;init_index<=0;setup<=0;
   start<=0;byte_data<=0;online<=0;write_index<=0;snapshot_start<=0;keys_hold<=255;status_hold<=0;timbre_hold<=0;volume_hold<=255;diag_hold<=0;stream_start<=0;capture_ready<=0;capturing<=0;previous<=0;trigger_wait<=0;decimate<=0;peak<=0;peak_hold<=0;
   for(k=0;k<128;k=k+1)begin wave[k]<=48;snapshot[k]<=48;end
  end else begin
   start<=0;stream_start<=0;
   if(frame_tick)begin
    previous<=sample;
    if(magnitude>peak)peak<=magnitude;
    if(!capture_ready)begin
     if(!capturing)begin
      if((previous<=0 && sample>0) || trigger_wait==1023)begin
       capturing<=1;write_index<=0;decimate<=0;trigger_wait<=0;
      end else trigger_wait<=trigger_wait+1'b1;
     end else begin
      decimate<=decimate+1'b1;
      if(decimate==0)begin wave[write_index]<=point;write_index<=write_index+1'b1;
       if(write_index==127)begin capturing<=0;capture_ready<=1;end
      end
     end
    end
   end
   case(state)
    0:if(timer==BOOT_TICKS-1)begin timer<=0;state<=1;end else timer<=timer+1'b1;
    1:if(!selected_busy)begin
      byte_data<=initializing?init_byte(init_index):setup<6?setup_byte(setup):pixels;
      if(bulk)stream_start<=1;else start<=1;state<=2;end
    2:if(selected_busy)state<=3;
    3:if(selected_done)begin
      if(!selected_ok)begin online<=0;timer<=0;state<=5;initializing<=1;init_index<=0;end
      else if(initializing)begin
       if(init_index==24)begin initializing<=0;online<=1;setup<=0;state<=4;timer<=0;end
       else begin init_index<=init_index+1'b1;state<=1;end
      end else if(setup<6)begin setup<=setup+1'b1;state<=1;end
      else begin state<=4;timer<=0;end
    end
    4:if(timer==REFRESH_TICKS-1)begin
      if(capture_ready)begin
       for(k=0;k<128;k=k+1)snapshot[k]<=wave[k];
       snapshot_start<=0;capture_ready<=0;
      end
      peak_hold<=peak;peak<=0;
      keys_hold<=keys_n;status_hold<=status;timbre_hold<=timbre;volume_hold<=volume;diag_hold<=diagnostic;setup<=0;timer<=0;state<=1;
     end else timer<=timer+1'b1;
    5:if(timer==RETRY_TICKS-1)begin timer<=0;state<=1;end else timer<=timer+1'b1;
    default:state<=0;
   endcase
  end
 end
endmodule
