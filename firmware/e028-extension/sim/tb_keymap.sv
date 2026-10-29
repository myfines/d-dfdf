`timescale 1ns/1ps
module tb_keymap;
reg clk=0,reset_n=0,valid=0,tick=0;always #5 clk=~clk;
reg [31:0] value=0;wire [159:0] mapping;wire rejected;wire[31:0] gates;
reg [7:0] optical=8'hff,remote=0;reg[1:0]page=0;
keymap_control bank(clk,reset_n,valid,8'h55,value,mapping,rejected);
note_router router(clk,reset_n,tick,4'hf,optical,1'b1,remote,1'b1,page,1'b0,32'd0,1'b0,32'd0,gates,,,mapping);
task command;input[31:0]v;begin @(negedge clk);valid=1;value=v;@(negedge clk);valid=0;end endtask
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
initial begin
repeat(3)@(negedge clk);reset_n=1;optical=8'hfe;frame();if(gates!=1)$fatal(1,"default mapping");
command(32'h10001F0F);frame();if(gates!=32'h80000000)$fatal(1,"optical remap");
optical=8'hff;remote=1;frame();if(gates!=32'h80000000)$fatal(1,"phone remap");
command(32'h10001F00);if(!rejected)$fatal(1,"bad checksum accepted");
command(32'h10201F2F);if(!rejected)$fatal(1,"invalid index accepted");
command(32'h10002030);if(!rejected)$fatal(1,"invalid note accepted");
command(0);frame();if(gates!=1)$fatal(1,"restore identity");
page=3;frame();if(gates!=32'h01000000)$fatal(1,"page mapping");
$display("PASS keymap identity, optical/phone remap, validation, reset, pages");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
