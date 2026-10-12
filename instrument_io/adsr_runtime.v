`timescale 1ns/1ps
// Callers hold values stable for each note; zero intervals are clamped to 1.
module adsr_runtime(input wire clk,reset_n,frame_tick,gate,
 input wire [8:0] attack_step,input wire [15:0] decay_interval,
 input wire [8:0] sustain_level,input wire [15:0] release_interval,
 output reg [8:0] level,output wire active);
 localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
 reg [2:0] state;reg [31:0] count;reg previous_gate;
 wire [8:0] ATTACK_VALUE=attack_step==0 ?9'd1:attack_step>256 ?9'd256:attack_step;
 wire [8:0] ATTACK_LIMIT=9'd256-ATTACK_VALUE;
 wire [8:0] SUSTAIN_VALUE=sustain_level>256 ?9'd256:sustain_level;
 wire [15:0] d_ticks=decay_interval==0 ?16'd1:decay_interval;
 wire [15:0] r_ticks=release_interval==0 ?16'd1:release_interval;
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
    else if(count==r_ticks-1)begin count<=0;level<=level-1'b1;end
    else count<=count+1'b1;
   end else case(state)
    ATTACK:if(level>=ATTACK_LIMIT)begin level<=256;count<=0;state<=DECAY;end
           else level<=level+ATTACK_VALUE;
    DECAY:if(level<=SUSTAIN_VALUE)begin level<=SUSTAIN_VALUE;count<=0;state<=SUSTAIN;end
          else if(count==d_ticks-1)begin count<=0;level<=level-1'b1;end
          else count<=count+1'b1;
    SUSTAIN:begin level<=SUSTAIN_VALUE;count<=0;end
    default:begin state<=ATTACK;count<=0;end
   endcase
  end
 end
endmodule
