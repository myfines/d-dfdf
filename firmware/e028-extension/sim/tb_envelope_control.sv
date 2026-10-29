`timescale 1ns/1ps
module tb_envelope_control;
reg clk=0,reset_n=0,valid=0;always #5 clk=~clk;
reg [7:0] kind="G";reg [31:0] value=0;
wire enabled,rejected;wire [19:0] config_value;
envelope_control dut(clk,reset_n,valid,kind,value,enabled,config_value,rejected);
task send;input [31:0] v;begin @(negedge clk);value=v;valid=1;@(negedge clk);valid=0;#1;end endtask
initial begin
 repeat(2) @(negedge clk);reset_n=1;
 // v1 A=8 D=9 R=A S=80 checksum18^9A^80=02
 send(32'h189A8002);if(!enabled || config_value!=20'h89A80 || rejected)$fatal(1,"valid packet rejected");
 send(32'h189A8003);if(!rejected || config_value!=20'h89A80)$fatal(1,"checksum changed config");
 send(32'h289A8032);if(!rejected || config_value!=20'h89A80)$fatal(1,"unknown version accepted");
 send(0);if(enabled)$fatal(1,"preset restore failed");
 $display("PASS envelope config checksum, version, atomic reject, preset restore");$finish;
end
endmodule
