`timescale 1ns/1ps
module adsr_envelope #(
 parameter integer ATTACK_STEP=6,DECAY_INTERVAL=16,SUSTAIN_LEVEL=160,RELEASE_INTERVAL=4
)(input wire clk,reset_n,frame_tick,gate,output wire [8:0] level,output wire active);
 localparam [8:0] A=ATTACK_STEP,S=SUSTAIN_LEVEL;
 localparam [15:0] D=DECAY_INTERVAL,R=RELEASE_INTERVAL;
 adsr_runtime core(clk,reset_n,frame_tick,gate,A,D,S,R,level,active);
endmodule
