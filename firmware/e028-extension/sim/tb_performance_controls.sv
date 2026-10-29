`timescale 1ns/1ps
module tb_performance_controls;
reg[11:0]y=0,c=0;reg valid=1,gesture=1;wire[7:0]v,b;
performance_controls dut(y,c,valid,gesture,v,b);
integer i,last_v,last_b;
initial begin
last_v=0;last_b=0;
for(i=0;i<=1800;i=i+1)begin y=i;c=i;#1;
if(v<last_v||b<last_b)$fatal(1,"control wrap at %0d",i);
last_v=v;last_b=b;
end
if(v!=255||b!=255)$fatal(1,"upper endpoint not reached");
y=0;c=0;#1;if(v!=64||b!=0)$fatal(1,"lower endpoint");
y=825;c=825;#1;if(v<155||v>165||b<125||b>130)$fatal(1,"center mapping");
valid=0;gesture=0;#1;if(v!=192||b!=128)$fatal(1,"disconnected defaults");
$display("PASS monotonic full-range velocity/brightness, clipping, center and defaults");$finish;
end
endmodule
