`timescale 1ns/1ps
// Input keys and SW must already be synchronized; SW is debounced by top.
module instrument_panel #(parameter integer LONG_FRAMES=46875)(
 input wire clk,reset_n,frame_tick,sw_n,input wire [3:0] keys_n,
 input wire controls_valid,input wire [11:0] axis_y,
 output reg [1:0] timbre,note_page,output reg edit_mode,test_mode,octave_down,echo_enable,
 output reg [1:0] field,output reg [8:0] attack_step,output reg [15:0] decay_interval,
 output reg [8:0] sustain_level,output reg [15:0] release_interval);
 reg previous_sw,long_fired;reg [31:0] hold_count;reg [3:0] press_keys;
 wire [11:0] bounded=axis_y>1650 ?12'd1650:axis_y;
 wire [19:0] scaled=bounded*8'd159;
 wire [3:0] q=scaled>=20'd262144 ?4'd15:scaled[17:14];
 always @(posedge clk)begin
  if(!reset_n)begin
   timbre<=0;note_page<=0;edit_mode<=0;test_mode<=0;octave_down<=0;echo_enable<=0;field<=0;
   attack_step<=6;decay_interval<=16;sustain_level<=160;release_interval<=4;
   previous_sw<=1;long_fired<=0;hold_count<=0;press_keys<=15;
  end else if(frame_tick)begin
   previous_sw<=sw_n;
   if(previous_sw && !sw_n)begin press_keys<=keys_n;hold_count<=0;long_fired<=0;end
   else if(!sw_n && !long_fired)begin
    if(hold_count==LONG_FRAMES-1)begin
     long_fired<=1;
     if(!press_keys[0] && !press_keys[3])begin test_mode<=!test_mode;edit_mode<=0;end
     else if(!test_mode)edit_mode<=!edit_mode;
    end else hold_count<=hold_count+1'b1;
   end
   if(!previous_sw && sw_n && !long_fired && !edit_mode && !test_mode)begin
    if(!press_keys[0])begin
     case(note_page)2'd0:note_page<=2'd1;2'd1:note_page<=2'd2;default:note_page<=2'd0;endcase
    end
    else if(!press_keys[1])octave_down<=!octave_down;
    else if(!press_keys[2])echo_enable<=!echo_enable;
    else if(press_keys==15)begin
     case(timbre)
      2'd0:timbre<=2'd1;2'd1:timbre<=2'd2;default:timbre<=2'd0;
     endcase
     case(timbre)
      0:begin attack_step<=4;decay_interval<=32;sustain_level<=200;release_interval<=8;end
      1:begin attack_step<=16;decay_interval<=64;sustain_level<=0;release_interval<=16;end
      default:begin attack_step<=6;decay_interval<=16;sustain_level<=160;release_interval<=4;end
     endcase
    end
   end
   if(edit_mode && controls_valid)begin
    if(!keys_n[0])begin field<=0;attack_step<={5'd0,q}+9'd1;end
    else if(!keys_n[1])begin field<=1;decay_interval<=16'd4+{10'd0,q,2'b00};end
    else if(!keys_n[2])begin field<=2;sustain_level<=9'd32+({5'd0,q}*9'd14);end
    else if(!keys_n[3])begin field<=3;release_interval<=16'd2+{11'd0,q,1'b0};end
   end
  end
 end
endmodule

