`timescale 1ns/1ps
module tb_fx_stability;
reg clk=0,reset_n=0,tick=0;always #5 clk=~clk;
reg signed[15:0] dry=0;reg[2:0] enable=2;
wire signed[15:0] l,r;fx_engine dut(clk,reset_n,tick,dry,enable,l,r);
integer i,peak,lastpeak;integer echoes;
task frame; input integer v;begin
 @(negedge clk);dry=v;tick=1;@(negedge clk);tick=0;repeat(8) @(negedge clk);
 if((^l)===1'bx || (^r)===1'bx)$fatal(1,"unknown output");
end endtask
initial begin
repeat(3) @(negedge clk);reset_n=1;
// No testbench RAM initialization. Verify startup and mode-change scrubs.
repeat(2200) @(negedge clk);
frame(0);if(l!=0 || r!=0)$fatal(1,"startup not silent");
frame(-16000);lastpeak=0;echoes=0;
for(i=0;i<50000;i=i+1)begin frame(0);
 if(l>0 || r>0)$fatal(1,"negative impulse produced positive feedback at %0d: %0d",i,l);
 if(l!=0)echoes=echoes+1;
 if(i>49000 && -l>lastpeak)lastpeak=-l;
end
if(echoes<2 || lastpeak>2)$fatal(1,"tail did not decay: echoes=%0d tail=%0d",echoes,lastpeak);
enable=0;frame(0);repeat(2200) @(negedge clk);enable=2;repeat(2200) @(negedge clk);frame(0);
if(l!=0 || r!=0)$fatal(1,"old tail resurrected");
$display("PASS fx stability uninitialized RAM, negative impulse, decay, re-enable echoes=%0d tail=%0d",echoes,lastpeak);$finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
