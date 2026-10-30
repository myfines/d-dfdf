`timescale 1ns/1ps
module tb_voice_schedule;
 reg clk=0,rst=0,tick=0;reg[1:0] tone=0;
 integer divider=0,frames=0,cycles=0,max_cycles=0,i;reg measuring=0;
 wire signed[15:0] sample;wire active;wire[5:0] count;
 synth32 dut(.clk(clk),.reset_n(rst),.frame_tick(tick),.gate_mask(32'hffffffff),
  .timbre(tone),.velocity(8'd159),.bend(14'sd4095),.vibrato(8'd255),.brightness(8'd255),
  .expression(8'd255),.tremolo(8'd0),.sample(sample),.active(active),.voice_count(count),
  .note_on(),.note_on_index(),.latency_frames(),.custom_adsr(1'b0),.adsr_config(20'd0));
 always #5 clk=~clk;
 always @(negedge clk)begin
  if(rst)begin tick=(divider==575);divider=tick?0:divider+1;end
 end
 always @(posedge clk)if(rst)begin
  if(tick)begin
   if(dut.state!=0)$fatal(1,"32-voice frame deadline missed");
   measuring=1;cycles=0;frames=frames+1;
  end else if(measuring)begin
   cycles=cycles+1;
   if(dut.state==0)begin
    if(cycles>max_cycles)max_cycles=cycles;
    measuring=0;
   end
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<4;i=i+1)begin
   tone=i;repeat(20)begin @(posedge tick);@(negedge tick);end
  end
  if(count!=32||max_cycles==0||max_cycles>=576)$fatal(1,"invalid schedule/voice count");
  $display("PASS 32-voice schedule: %0d frames, max %0d / 576 clocks, four timbres",frames,max_cycles);$finish;
 end
 initial begin #1000000;$fatal(1,"schedule test timeout");end
endmodule
