`timescale 1ns/1ps
module tb_pcm_record;
reg clk=0,rst=0,tick=0,valid=0,capture=0;always #5 clk=~clk;
reg signed [15:0] sample=16384;reg[31:0] value=0;reg[6:0]index=0;
wire mode;wire[7:0]data;
pcm_record #(.LENGTH(64),.DECIMATE(2)) dut(clk,rst,tick,sample,valid,8'h43,value,capture,index,mode,data,7'd2,1'b1,1'b0,20'd0,160'd0);
task cmd;input[31:0]v;begin @(negedge clk);valid=1;value=v;@(negedge clk);valid=0;end endtask
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
initial begin repeat(3)@(negedge clk);rst=1;cmd(32'h10010011);
if(!mode || !dut.busy)$fatal(1,"capture did not start");
repeat(128)frame();if(!dut.ready || dut.busy)$fatal(1,"capture length wrong");
cmd(32'h10020012);@(negedge clk);capture=1;@(negedge clk);capture=0;
index=20;repeat(3)@(negedge clk);if(data!="4")$fatal(1,"signed PCM high nibble");
index=21;repeat(3)@(negedge clk);if(data!="0")$fatal(1,"signed PCM low nibble");
repeat(80)@(negedge clk);
index=84;repeat(2)@(negedge clk);if(data!="0")$fatal(1,"checksum high");
index=85;repeat(2)@(negedge clk);if(data!="8")$fatal(1,"checksum sum");
index=82;repeat(2)@(negedge clk);if(data!="4")$fatal(1,"last payload missing");
cmd(32'h10020210);if(dut.selected_chunk!=0)$fatal(1,"out of range chunk accepted");
cmd(0);if(mode)$fatal(1,"exit recording telemetry failed");
$display("PASS PCM real-sample capture, averaging, bounded length, chunk formatting, range and exit");$finish;end
initial begin #100000;$fatal(1,"timeout");end
endmodule
