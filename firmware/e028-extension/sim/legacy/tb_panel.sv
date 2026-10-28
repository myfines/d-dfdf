`timescale 1ns/1ps
module tb_panel;
reg clk=0,rst=0,tick=0,sw=1;always #5 clk=~clk;
reg [3:0] keys=15;reg [11:0] y=825;
wire [1:0] tone,field,page;wire edit_mode,test_mode,octave,echo;
wire [8:0] a,s;wire [15:0] d,r;
instrument_panel #(.LONG_FRAMES(4)) dut(clk,rst,tick,sw,keys,1'b1,y,tone,page,edit_mode,test_mode,octave,echo,field,a,d,s,r);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
task click;begin sw=0;repeat(2)frame();sw=1;frame();end endtask
task hold;begin sw=0;repeat(6)frame();sw=1;frame();end endtask
initial begin
repeat(3)@(negedge clk);rst=1;frame();if(tone!=0 || edit_mode || test_mode || octave || echo)$fatal(1,"Wrong defaults");
click();if(tone!=1)$fatal(1,"Short press did not change tone");click();click();if(tone!=0)$fatal(1,"Preset wrap failed");
keys=14;click();if(page!=1 || tone!=0)$fatal(1,"Note page change failed");
keys=13;click();if(!octave || tone!=0)$fatal(1,"Octave chord failed");
keys=11;click();if(!echo || tone!=0)$fatal(1,"Echo chord failed");
keys=15;hold();if(!edit_mode || tone!=0)$fatal(1,"Long press must enter edit without cycling preset");
keys=14;y=0;repeat(4)frame();if(a!=1 || field!=0)$fatal(1,"Attack edit failed");
keys=13;y=1650;repeat(4)frame();if(d<60 || field!=1)$fatal(1,"Decay edit failed");
keys=11;y=0;repeat(4)frame();if(s!=32 || field!=2)$fatal(1,"Sustain edit failed");
keys=7;y=1650;repeat(4)frame();if(r<30 || field!=3)$fatal(1,"Release edit failed");
keys=15;hold();if(edit_mode)$fatal(1,"Edit exit failed");
keys=6;hold();if(!test_mode || edit_mode)$fatal(1,"Spectrum test entry failed");hold();if(test_mode)$fatal(1,"Spectrum test exit failed");
$display("PASS panel: presets, octave, echo, ADSR editing, long-press disambiguation, test toggle");$finish;
end
endmodule
