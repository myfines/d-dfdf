`timescale 1ns/1ps
// U10iinncc: index0..31, note0..31, cc XOR of upper three bytes.
// U00000000 restores identity. Table is volatile and shared by optical/phone pages.
module keymap_control(input wire clk,reset_n,valid,input wire [7:0] kind,
 input wire [31:0] value,output reg [159:0] mapping,output reg rejected);
 integer i;
 wire checksum_ok=value[7:0]==(value[31:24]^value[23:16]^value[15:8]);
 always @(posedge clk)begin
 if(!reset_n)begin for(i=0;i<32;i=i+1)mapping[i*5+:5]<=i;rejected<=0;end
 else begin
 rejected<=0;
 if(valid && kind=="U")begin
 if(value==0)begin for(i=0;i<32;i=i+1)mapping[i*5+:5]<=i;end
 else if(value[31:24]==8'h10 && value[23:21]==0 && value[15:13]==0 && checksum_ok)
 mapping[value[20:16]*5+:5]<=value[12:8];
 else rejected<=1;
 end
 end
 end
endmodule
