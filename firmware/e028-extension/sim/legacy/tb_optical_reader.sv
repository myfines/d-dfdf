`timescale 1ns/1ps
module tb_optical_reader;
reg clk=0,rst=0,enabled=1;always #5 clk=~clk;
reg [7:0] status=255;tri1 scl,sda;wire [7:0] keys,raw;wire valid,error;integer reads;
optical_keys_reader #(.HALF_TICKS(3),.TIMEOUT_TICKS(100),.BOOT_TICKS(20),.POLL_TICKS(20),.RETRY_TICKS(30)) dut(clk,rst,scl,sda,keys,raw,valid,error);
optical_sensor_model sensor(scl,sda,enabled,status,reads);
reg [7:0] high_status=0;tri1 hscl,hsda;wire [7:0] high_keys,high_raw;wire high_valid,high_error;integer hr;
optical_keys_reader #(.HALF_TICKS(3),.TIMEOUT_TICKS(100),.BOOT_TICKS(4),.POLL_TICKS(20),.ACTIVE_LOW(0)) high_reader(clk,rst,hscl,hsda,high_keys,high_raw,high_valid,high_error);
optical_sensor_model high_sensor(hscl,hsda,1'b1,high_status,hr);
reg stuck=0;assign scl=stuck?1'b0:1'bz;
task wait_keys(input [7:0] expected);integer timeout;begin timeout=0;while(keys!==expected && timeout<10000)begin @(negedge clk);timeout=timeout+1;end if(keys!==expected)$fatal(1,"Optical mapping/filter expected %h got %h",expected,keys);end endtask
initial begin
repeat(3)@(negedge clk);rst=1;repeat(19)@(negedge clk);if(reads!=0 || valid)$fatal(1,"Module stabilization skipped");
wait(valid);if(keys!==255)$fatal(1,"Idle not released");
status=8'h7f;wait_keys(8'hfe);if(raw!==8'h7f)$fatal(1,"Raw byte wrong");
status=8'hfe;wait_keys(8'h7f);
status=8'h5a;wait_keys(8'h5a); // bit reverse of 0x5a is itself.
enabled=0;wait(error);if(valid || keys!==255)$fatal(1,"NACK did not release all inputs");
enabled=1;status=8'hff;wait(valid);if(error)$fatal(1,"Retry did not recover");
stuck=1;wait(error);if(valid || keys!==255)$fatal(1,"Stuck clock not bounded");stuck=0;wait(valid);
wait(high_valid);if(high_keys!==255)$fatal(1,"High-active idle polarity wrong");high_status=8'h80;
repeat(5000)@(negedge clk);if(high_keys!==8'hfe)$fatal(1,"High-active first key polarity wrong");
$display("PASS optical reader: boot delay, 0x12/0x30, single byte NACK, channel order, multikey, disconnect, timeout recovery");$finish;
end
initial begin #2000000;$fatal(1,"Optical test timeout");end
endmodule
