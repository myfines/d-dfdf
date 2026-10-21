`timescale 1ns/1ps
module tb_extension_safe;
reg clk=0;always #5 clk=~clk;reg [3:0] keys=15;reg sw=1;
tri1 ascl,asda,oscl,osda,dscl,dsda;wire esp_tx;wire b,w,d,pa,hb,hw,hd,alive,led,uart;integer ac,oc;
instrument_io #(.SAFE_STARTUP(1),.ENABLE_UI(1),.ENABLE_OPTICAL(1),.I2C_HALF_TICKS(3),.CONVERSION_TICKS(100),
 .RETRY_TICKS(50),.BUS_TIMEOUT_TICKS(100),.SWITCH_DEBOUNCE_TICKS(3),.OPTICAL_BOOT_TICKS(50),.OPTICAL_POLL_TICKS(20)) dut(
 clk,keys,sw,ascl,asda,b,w,d,pa,hb,hw,hd,alive,led,uart,oscl,osda,dscl,dsda,1'b1,esp_tx);
ads1015_model adc(ascl,asda,1'b1,12'd825,12'd0,ac);
optical_sensor_model optical(oscl,osda,1'b1,8'hff,oc);
task click(input [3:0] held);begin keys=held;repeat(10)@(negedge clk);sw=0;repeat(20)@(negedge clk);sw=1;repeat(20)@(negedge clk);keys=15;end endtask
initial begin
wait(dut.reset_n);repeat(200)@(negedge clk);
if(esp_tx!==1'bz || dscl!==1 || dsda!==1)$fatal(1,"Extension drives before arm");
if(dut.armed || b!==1'bz || w!==1'bz || d!==1'bz || ac!=0 || oc!=0 || led)$fatal(1,"Cold startup drives peripherals");
click(13);if(dut.armed)$fatal(1,"Ordinary key armed interface");
click(9);if(!dut.armed)$fatal(1,"Explicit arming gesture failed");
wait(led && dut.optical_valid);if(b===1'bz || w===1'bz || d===1'bz || dut.octave_down || dut.echo_enable)$fatal(1,"Enable or gesture suppression failed");
click(9);if(esp_tx!==1'bz || dscl!==1 || dsda!==1)$fatal(1,"Extension drives before arm");
if(dut.armed || b!==1'bz || w!==1'bz || d!==1'bz || led || dut.adc.bus.busy || dut.optical_interface.reader.bus.busy)$fatal(1,"Disarm did not release interfaces");
$display("PASS extension safe startup: no automatic output, explicit arm, no accidental panel action, disarm high impedance");$finish;
end
initial begin #3000000;$fatal(1,"Safe startup timeout");end
endmodule
