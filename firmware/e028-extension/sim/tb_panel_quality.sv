`timescale 1ns/1ps
module tb_panel_quality;
reg clk=0,rst=0;always #5 clk=~clk;
reg[3:0] keys=15;reg inhibit=0;wire[2:0]fx;wire testmode;
panel_ctrl dut(.clk(clk),.reset_n(rst),.frame_tick(1'b1),.sw_n(1'b1),.keys_n(keys),.inhibit(inhibit),.fx_enable(fx),.test_mode(testmode));
task tap;begin @(negedge clk);keys=14;repeat(100)@(negedge clk);keys=15;repeat(100)@(negedge clk);end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;repeat(100)@(negedge clk);
 tap;if(fx!==1)$fatal(1,"FX off cannot enable");
 tap;if(fx!==3)$fatal(1,"FX second preset");
 tap;if(fx!==7)$fatal(1,"FX third preset");
 tap;if(fx!==0)$fatal(1,"FX cannot disable");
 inhibit=1;tap;inhibit=0;if(fx!==0)$fatal(1,"inhibit leaked FX");
 @(negedge clk);keys=14;repeat(47000)@(negedge clk);keys=15;repeat(100)@(negedge clk);
 if(testmode!==1 || fx!==0)$fatal(1,"long press also short action");
 $display("PASS panel FX cycle, inhibit, long/short isolation");$finish;
end
endmodule
