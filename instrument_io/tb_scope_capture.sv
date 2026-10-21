`timescale 1ns/1ps
module tb_scope_capture;
reg clk=0;always #5 clk=~clk;reg reset_n=0,frame=0;
reg signed [15:0] sample=-8192;tri1 scl,sda;wire online;
oled_scope #(.BOOT_TICKS(1000000)) dut(clk,reset_n,frame,sample,8'hff,8'd0,scl,sda,online,2'd0,8'hff,8'd0);
task tick(input signed [15:0] s);begin
 @(negedge clk);sample=s;frame=1;@(negedge clk);frame=0;repeat(3)@(negedge clk);
end endtask
integer i;reg [5:0] saved;
initial begin
 repeat(4)@(negedge clk);reset_n=1;
 for(i=0;i<20;i=i+1)tick(-8192);
 if(dut.capturing || dut.capture_ready)$fatal(1,"Capture started before crossing");
 tick(8192);if(!dut.capturing)$fatal(1,"Positive zero-cross trigger missing");
 for(i=0;i<512;i=i+1)tick(8192);
 if(!dut.capture_ready)$fatal(1,"Complete capture not published");
 for(i=0;i<128;i=i+1)if(dut.wave[i]!=40)$fatal(1,"Decimation/clamping incorrect");
 saved=dut.wave[0];for(i=0;i<80;i=i+1)tick(-32768);
 if(dut.wave[0]!=saved)$fatal(1,"Completed capture was overwritten");
 reset_n=0;@(negedge clk);reset_n=1;
 for(i=0;i<1600;i=i+1)tick(0);
 if(!dut.capture_ready || dut.wave[0]!=48)$fatal(1,"Silent auto-trigger missing");
 $display("PASS scope capture: zero-cross, decimation, clamp, freeze, silence timeout");$finish;
end
initial begin #1000000;$fatal(1,"Capture test timeout");end
endmodule
