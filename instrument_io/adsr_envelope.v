`timescale 1ns/1ps
// Levels 0..256. Retrigger ramps from current level to avoid an amplitude jump.
module adsr_envelope #(
 parameter integer ATTACK_STEP=6,DECAY_INTERVAL=16,SUSTAIN_LEVEL=160,RELEASE_INTERVAL=4
)(input wire clk,reset_n,frame_tick,gate,output reg [8:0] level,output wire active);
 localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
 reg [2:0] state;reg [31:0] count;reg previous_gate;
 localparam [8:0] ATTACK_LIMIT=256-ATTACK_STEP;
 localparam [8:0] ATTACK_VALUE=ATTACK_STEP,SUSTAIN_VALUE=SUSTAIN_LEVEL;
 assign active=level!=0;
 always @(posedge clk) begin
  if(!reset_n)begin state<=IDLE;level<=0;count<=0;previous_gate<=0;end
  else if(frame_tick)begin
   previous_gate<=gate;
   if(gate && !previous_gate)begin
    count<=0;
    if(level>=ATTACK_LIMIT)begin level<=256;state<=DECAY;end
    else begin level<=level+ATTACK_VALUE;state<=ATTACK;end
   end else if(!gate)begin
    state<=RELEASE;
    if(level==0)begin state<=IDLE;count<=0;end
    else if(state!=RELEASE)count<=0;
    else if(count==RELEASE_INTERVAL-1)begin count<=0;level<=level-1'b1;end
    else count<=count+1'b1;
   end else case(state)
    ATTACK:if(level>=ATTACK_LIMIT)begin level<=256;count<=0;state<=DECAY;end
           else level<=level+ATTACK_VALUE;
    DECAY:if(level<=SUSTAIN_VALUE)begin level<=SUSTAIN_VALUE;count<=0;state<=SUSTAIN;end
          else if(count==DECAY_INTERVAL-1)begin count<=0;level<=level-1'b1;end
          else count<=count+1'b1;
    SUSTAIN:begin level<=SUSTAIN_VALUE;count<=0;end
    default:begin state<=ATTACK;count<=0;end
   endcase
  end
 end
endmodule
