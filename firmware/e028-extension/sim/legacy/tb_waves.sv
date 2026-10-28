`timescale 1ns/1ps
module tb_waves;
reg [31:0] phase=0;reg [1:0] timbre=0;wire signed [15:0] sample;
wave_source dut(phase,timbre,sample);
real f,h,angle;integer n,t;
initial begin
for(t=0;t<3;t=t+1)begin
 timbre=t;f=0;h=0;
 for(n=0;n<256;n=n+1)begin
  phase=n<<24;#1;angle=6.283185307179586*n/256;
  if($isunknown(sample))$fatal(1,"Unknown waveform sample");
  f=f+$itor($signed(sample))*$sin(angle);h=h+$itor($signed(sample))*$sin(3*angle);
 end
 if(f<0)f=-f;if(h<0)h=-h;
 if(f<1000000)$fatal(1,"Missing fundamental");
 if(t==1 && h/f>0.01)$fatal(1,"Sine harmonic distortion too high");
 if(t==2 && h/f<0.2)$fatal(1,"Saw preset not distinct");
end
$display("PASS waveforms: bounded known samples, fundamental, sine purity, distinct saw harmonics");$finish;
end
endmodule
