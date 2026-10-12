`timescale 1ns/1ps
module short_delay #(parameter integer DEPTH=2048)(input wire clk,reset_n,frame_tick,enabled,
 input wire signed [15:0] dry,output wire signed [15:0] sample);
 localparam integer AW=$clog2(DEPTH);
 reg signed [15:0] memory[0:DEPTH-1];
 localparam [AW-1:0] LAST_INDEX=DEPTH-1;
 reg [AW-1:0] index;reg [AW:0] filled;
 wire [AW:0] index_next={1'b0,index}+{{AW{1'b0}},1'b1};
 reg signed [15:0] delayed;
 wire [AW+1:0] fill_next={1'b0,filled}+{{(AW+1){1'b0}},1'b1};
 wire signed [17:0] dry_wide={{2{dry[15]}},dry};
 wire signed [17:0] wet_wide={{2{delayed[15]}},delayed};
 wire signed [17:0] sum=(dry_wide<<<1)+dry_wide+wet_wide;
 assign sample=enabled?$signed(sum[17:2]):dry;
 always @(posedge clk)begin
  if(!reset_n)begin index<=0;filled<=0;delayed<=0;end
  else if(!enabled)begin index<=0;filled<=0;delayed<=0;end
  else if(frame_tick)begin
   delayed<=filled==DEPTH?memory[index]:16'sd0;
   memory[index]<=dry;
   index<=index==LAST_INDEX?{AW{1'b0}}:index_next[AW-1:0];
   if(filled!=DEPTH)filled<=fill_next[AW:0];
  end
 end
endmodule
