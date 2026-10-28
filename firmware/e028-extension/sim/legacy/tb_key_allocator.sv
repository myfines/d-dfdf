`timescale 1ns/1ps
module tb_key_allocator;
reg clk=0,rst=0,tick=0;always #5 clk=~clk;reg [7:0] keys=255;
wire [3:0] gates,triggers;wire [11:0] notes;
optical_key_allocator dut(clk,rst,tick,keys,gates,notes,triggers);
task frame;begin @(negedge clk);tick=1;@(negedge clk);tick=0;end endtask
integer i;reg [7:0] seen;
task check_unique;begin seen=0;for(i=0;i<4;i=i+1)if(!gates[i])begin if(seen[notes[i*3+:3]])$fatal(1,"Duplicate assignment");seen[notes[i*3+:3]]=1;end end endtask
initial begin
repeat(3)@(negedge clk);rst=1;frame();if(gates!==15)$fatal(1,"Idle not released");
keys=0;frame();check_unique();if(seen!==8'h0f || triggers!==15)$fatal(1,"First four notes wrong");
frame();if(triggers!==0)$fatal(1,"Held note retriggered");
keys=8'h03;frame();check_unique();if(seen!==8'h3c)$fatal(1,"Held notes lost or queued keys not admitted");
keys=255;frame();if(gates!==15)$fatal(1,"Release-all failed");
keys=8'h7f;frame();check_unique();if(seen!==8'h80)$fatal(1,"Eighth input missing");
$display("PASS allocator: eight inputs, four retained voices, no duplicates, queued keys, edge triggers");$finish;
end
endmodule
