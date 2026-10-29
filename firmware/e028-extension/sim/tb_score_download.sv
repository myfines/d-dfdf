`timescale 1ns/1ps
module tb_score_download;
reg clk=0,rst=0,valid=0,tick=0,en=0;always #5 clk=~clk;
reg[31:0] value;wire[31:0] gates;wire[4:0]note;wire[5:0]step;wire beat,playing;
song_player #(.STEP_FRAMES(4),.DOWNLOAD_UNIT_FRAMES(2)) dut(clk,rst,tick,en,gates,note,step,beat,playing,valid,8'h57,value,,);
task cmd;input[31:0]v;begin @(negedge clk);valid=1;value=v;@(negedge clk);valid=0;end endtask
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
initial begin
repeat(3)@(negedge clk);rst=1;
cmd(32'h000C020E);cmd(32'h01FF02FC); // C4, rest, each2units
cmd(32'hFF0102FC); // commit length2
if(!dut.download_ready)$fatal(1,"score not committed");
en=1;repeat(3)frame();if(gates!=32'h1000)$fatal(1,"download C4 missing");
repeat(3)frame();if(gates!=0)$fatal(1,"rest did not silence");
repeat(5)frame();if(gates!=32'h1000)$fatal(1,"offline loop failed");
en=0;cmd(32'hFF0000FF);if(dut.download_selected)$fatal(1,"builtin restore failed");
cmd(32'h000C020F);if(dut.download_selected)$fatal(1,"bad checksum accepted");
cmd(32'h000C020E);cmd(32'hFF0103FD);if(dut.download_ready)$fatal(1,"incomplete score committed");
$display("PASS score download checksum/commit/rest/offline loop/builtin restore/incomplete rejection");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
