`timescale 1ns/1ps
// G packet: version1 nibble, A/D/R index nibbles, sustain byte,
// XOR checksum of the first3 bytes. G00000000 restores timbre presets.
module envelope_control(input wire clk,reset_n,cmd_valid,
 input wire [7:0] kind,input wire [31:0] value,
 output reg enabled,output reg [19:0] config_value,output reg rejected);
always @(posedge clk)begin
 if(!reset_n)begin enabled<=0;config_value<=0;rejected<=0;end
 else begin
  rejected<=0;
  if(cmd_valid && kind=="G")begin
   if(value==0)enabled<=0;
   else if(value[31:28]==4'd1 && value[7:0]==(value[31:24]^value[23:16]^value[15:8]))begin
    enabled<=1;config_value<=value[27:8];
   end else rejected<=1;
  end
 end
end
endmodule
