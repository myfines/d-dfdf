`timescale 1ns/1ps
module tb_audio_render;
reg clk=0,reset_n=0,ft=0;always #5 clk=~clk;
reg [1:0] timbre=0;reg[31:0] mask=0;
wire signed[15:0] sample;
synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(ft),.gate_mask(mask),.timbre(timbre),.velocity(8'd180),.bend(14'sd0),.vibrato(8'd0),.brightness(8'd255),.expression(8'd255),.tremolo(8'd0),.sample(sample));
integer cycle=0,t,n,fd;reg[255:0] name;
always @(negedge clk) begin
 if(cycle==575) begin cycle=0;ft=1;end else begin cycle=cycle+1;ft=0;end
end
initial begin
 for(t=0;t<4;t=t+1) begin
  @(negedge clk); reset_n=0;repeat(4)@(negedge clk);
  timbre=t;mask=32'h00001000;reset_n=1;
  repeat(2000)@(negedge ft);
  $sformat(name,"timbre%0d.txt",t);fd=$fopen(name,"w");
  for(n=0;n<4096;n=n+1) begin @(negedge ft);$fdisplay(fd,"%0d",sample);end
  $fclose(fd);$display("render timbre %0d",t);
 end
 $display("PASS audio render");$finish;
end
initial begin #200000000;$fatal(1,"render timeout");end
endmodule
