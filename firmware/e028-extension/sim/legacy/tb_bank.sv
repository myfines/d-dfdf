`timescale 1ns/1ps
module tb_bank;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;
reg [31:0] gates=0;wire signed [15:0] sample;wire active,busy;
spectrum_bank dut(clk,rst,tick,gates,sample,active,busy);
integer n,f;
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;repeat(110)@(negedge clk);if(busy)$fatal(1,"Bank missed frame budget");end endtask
initial begin
repeat(3)@(negedge clk);rst=1;repeat(2)frame();if(sample!==0 || active)$fatal(1,"Bank idle not silent");
gates=32'hffffffff;repeat(60)frame();if(!active)$fatal(1,"Bank failed to start");
f=$fopen("E:/gaoyun/tools/smoke/spectrum32.csv","w");
for(n=0;n<8192;n=n+1)begin frame();if(sample>8192 || sample< -8192 || $isunknown(sample))$fatal(1,"Bank mixed sample invalid");$fdisplay(f,"%0d",sample);end
$fclose(f);gates=0;repeat(300)frame();if(sample!==0 || active)$fatal(1,"Bank release not silent");
$display("PASS 32 bank: 32 active oscillators, per-frame budget, bounded samples, released silence");$finish;
end
endmodule
