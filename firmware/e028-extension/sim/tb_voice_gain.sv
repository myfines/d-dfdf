`timescale 1ns/1ps
module tb_voice_gain;
reg clk=0;always #5 clk=~clk;
wire signed [15:0] sample;
synth32 dut(.clk(clk),.reset_n(1'b0),.frame_tick(1'b0),.gate_mask(32'd0),
 .timbre(2'd1),.velocity(8'd255),.bend(14'sd0),.vibrato(8'd0),
 .brightness(8'd255),.expression(8'd8),.tremolo(8'd0),.sample(sample));
integer wave_input,velocity_input,level_input,v,e,p,expected,gain;
initial begin
 force dut.wave_value=wave_input;force dut.velocity_now=velocity_input;
 force dut.level_now=level_input;
 for(v=0;v<4;v=v+1)begin
  velocity_input=v==0 ? 255 : v==1 ? 64 : v==2 ? 120 : 0;
  for(e=0;e<3;e=e+1)begin
   level_input=e==0 ? 65535 : e==1 ? 32768 : 0;
   for(p=0;p<2;p=p+1)begin
    wave_input=p ? -32768 : 32767;#2;
    gain=(level_input*velocity_input)>>>8;
    expected=(wave_input*gain)>>>16;
    if($signed(dut.voice_sample)!=expected)
     $fatal(1,"voice gain Q16 overflow/scaling wave=%0d env=%0d velocity=%0d expected=%0d actual=%0d",wave_input,level_input,velocity_input,expected,$signed(dut.voice_sample));
   end
  end
 end
 $display("PASS Q16 envelope gain endpoints, velocity, polarity and mute");$finish;
end
endmodule
