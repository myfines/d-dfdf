`timescale 1ns/1ps
module tb_esp_at;
reg clk=0;always #5 clk=~clk;reg reset_n=0,rv=0,busy=0;reg [7:0] rd=0;
wire start,ready,active;wire [7:0] td,volume,diagnostic;integer lines=0;
esp_at_control #(.BOOT_TICKS(10),.WAIT_TICKS(300),.LEASE_TICKS(80)) dut(clk,reset_n,rv,rd,busy,start,td,ready,volume,active,diagnostic,8'd0,,,,,,,);
task rx(input [7:0] b);begin @(negedge clk);rd=b;rv=1;@(negedge clk);rv=0;end endtask
always begin wait(start);@(negedge clk);busy=1;repeat(2)@(negedge clk);busy=0;
 if(td==10)begin lines=lines+1;if(lines>1)begin repeat(5)@(negedge clk);rx(79);rx(75);rx(13);rx(10);end end
 wait(!start);
end
initial begin repeat(4)@(negedge clk);reset_n=1;wait(ready);repeat(10)@(negedge clk);
if(!diagnostic[6] || !diagnostic[5])$fatal(1,"RX/timeout diagnostics missing");
if(lines!=7)$fatal(1,"Config timeout retry failed");
rx(43);rx(73);rx(80);rx(68);rx(44);rx(48);rx(44);rx(52);rx(58);rx(86);rx(50);rx(48);rx(10);
repeat(4)@(negedge clk);if(volume!=32||!active)$fatal(1,"Remote command missing");
repeat(90)@(negedge clk);if(volume!=255||active)$fatal(1,"Lease did not fail neutral");
rx(114);rx(101);rx(97);rx(100);rx(121);rx(13);rx(10);
repeat(2)@(negedge clk);if(ready)$fatal(1,"ESP reboot did not restart config");
reset_n=0;@(negedge clk);if(ready)$fatal(1,"Ready persisted reset");
$display("PASS ESP config retry, OK handshake, command, lease, reset");$finish;end
initial begin #1000000;$fatal(1,"AT timeout");end
endmodule
