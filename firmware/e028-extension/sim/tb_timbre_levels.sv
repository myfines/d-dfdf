`timescale 1ns/1ps
// Actual note-on/envelope path, not forced envelope state. Digital evidence only.
module tb_timbre_levels;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,tick=0;reg[31:0] gates=0;
integer cycle=0,frames=0,i,v,note_index,fd;
wire signed[15:0] pcm[0:3];
integer peak[0:3],settled_peak[0:3],clipped[0:3],count[0:3];
real squares[0:3],rms;
genvar t;
generate for(t=0;t<4;t=t+1)begin: tones
 synth32 dut(.clk(clk),.reset_n(reset_n),.frame_tick(tick),.gate_mask(gates),
 .timbre(t[1:0]),.velocity(8'd159),.bend(14'sd0),.vibrato(8'd0),
 .brightness(8'd128),.expression(8'd160),.tremolo(8'd0),.sample(pcm[t]),
 .custom_adsr(1'b0),.adsr_config(20'd0));
end endgenerate
always @(posedge clk)begin
 if(cycle==575)begin cycle<=0;tick<=1;frames<=frames+1;end
 else begin cycle<=cycle+1;tick<=0;end
 if(reset_n&&tick)for(i=0;i<4;i=i+1)begin
  v=$signed(pcm[i]);if(v<0)v=-v;
  if(v>peak[i])peak[i]=v;if(v>=32767)clipped[i]=clipped[i]+1;
  if(frames>11000)begin if(v>settled_peak[i])settled_peak[i]=v;squares[i]=squares[i]+v*v;count[i]=count[i]+1;end
 end
end
initial begin
 fd=$fopen("timbre-levels.csv","w");$fdisplay(fd,"note,timbre,velocity,expression,brightness,settled_rms,settled_peak,attack_peak,clip_samples");
 for(note_index=0;note_index<=24;note_index=note_index+12)begin
  @(negedge clk);reset_n=0;gates=0;repeat(4)@(negedge clk);
  frames=0;cycle=0;
  for(i=0;i<4;i=i+1)begin peak[i]=0;settled_peak[i]=0;clipped[i]=0;count[i]=0;squares[i]=0;end
  reset_n=1;gates=32'd1<<note_index;
  wait(frames==12000);@(negedge clk);
  for(i=0;i<4;i=i+1)begin
   rms=$sqrt(squares[i]/count[i]);
   $fdisplay(fd,"%0d,%0d,159,160,128,%f,%0d,%0d,%0d",note_index,i,rms,settled_peak[i],peak[i],clipped[i]);
   if(rms<1||clipped[i]!=0)$fatal(1,"inaudible/clipped digital tone note=%0d tone=%0d",note_index,i);
  end
 end
 $fclose(fd);$display("PASS actual note-on four timbres C3/C4/C5, phone defaults, digital RMS/peaks exported; no acoustic equivalence claim");$finish;
end
initial begin #300000000;$fatal(1,"timbre calibration timeout");end
endmodule
