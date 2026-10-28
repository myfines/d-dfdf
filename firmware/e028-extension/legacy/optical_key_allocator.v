`timescale 1ns/1ps
// Retain held notes first, then fill free slots from unclaimed optical inputs.
module optical_key_allocator(input wire clk,reset_n,frame_tick,input wire [7:0] keys_n,
 output wire [3:0] slot_keys_n,output reg [11:0] notes,output reg [3:0] triggers);
 reg [3:0] assigned;reg [3:0] next_assigned;reg [11:0] next_notes;
 reg [7:0] claimed;reg found;integer i,j,k;
 assign slot_keys_n=~assigned;
 always @*begin
  next_assigned=0;next_notes=notes;claimed=0;found=0;
  for(i=0;i<4;i=i+1)if(assigned[i] && !keys_n[notes[i*3+:3]])begin
   next_assigned[i]=1;claimed[notes[i*3+:3]]=1;
  end
  for(i=0;i<4;i=i+1)if(!next_assigned[i])begin
   found=0;
   for(j=0;j<8;j=j+1)if(!keys_n[j] && !claimed[j] && !found)begin
    next_assigned[i]=1;next_notes[i*3+:3]=j[2:0];claimed[j]=1;found=1;
   end
  end
 end
 always @(posedge clk)begin
  if(!reset_n)begin assigned<=0;notes<=0;triggers<=0;end
  else if(frame_tick)begin
   assigned<=next_assigned;notes<=next_notes;
   for(k=0;k<4;k=k+1)triggers[k]<=next_assigned[k] && (!assigned[k] || notes[k*3+:3]!=next_notes[k*3+:3]);
  end
 end
endmodule
