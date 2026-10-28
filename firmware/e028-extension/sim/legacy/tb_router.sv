`timescale 1ns/1ps
module tb_router;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;reg [1:0] mode=0;
wire signed [15:0] sample;
mode_router #(.STEP(64)) dut(clk,rst,tick,mode,16'sd4000,-16'sd4000,sample);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
integer i;reg saw_zero=0;
initial begin
repeat(3)@(negedge clk);rst=1;repeat(7)frame();if(sample!==4000)$fatal(1,"Router normal gain wrong");
mode=2;for(i=0;i<12;i=i+1)begin frame();if(sample==0)saw_zero=1;if(sample<0 && !saw_zero)$fatal(1,"Mode switched without zero crossing fade");if(sample>4000 || sample< -4000)$fatal(1,"Router gain overflow");end
if(sample!==-4000)$fatal(1,"Router test mode did not reach unity");
mode=1;repeat(12)frame();if(sample!==0)$fatal(1,"Edit mode not muted");
mode=0;repeat(12)frame();if(sample!==4000)$fatal(1,"Returning to keyboard failed");
$display("PASS router: fade to zero before mode switch, edit silence, bounded gain, return");$finish;
end
endmodule
