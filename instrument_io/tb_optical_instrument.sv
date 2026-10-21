`timescale 1ns/1ps
module tb_optical_instrument;
reg clk=0;always #18.5185 clk=~clk;reg [3:0] keys=15;reg enabled=1;reg [7:0] status=255;
tri1 ascl,asda,oscl,osda;wire bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart;integer ac,oc,n,nonzero;
reg [15:0] l,r;
instrument_io #(.SAFE_STARTUP(0),.I2C_HALF_TICKS(3),.CONVERSION_TICKS(100),.RETRY_TICKS(50),.BUS_TIMEOUT_TICKS(100),
 .SWITCH_DEBOUNCE_TICKS(10),.ENABLE_OPTICAL(1),.OPTICAL_BOOT_TICKS(50),.OPTICAL_POLL_TICKS(20)) dut(
 clk,keys,1'b1,ascl,asda,bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart,oscl,osda,,,1'b1,);
ads1015_model adc(ascl,asda,1'b1,12'd825,12'd0,ac);
optical_sensor_model optical(oscl,osda,enabled,status,oc);
task decode;integer i;begin @(negedge ws);@(posedge bck);l=0;r=0;
for(i=0;i<16;i=i+1)begin @(posedge bck);l={l[14:0],data};end
for(i=0;i<16;i=i+1)begin @(posedge bck);r={r[14:0],data};end
if(l!==r || $signed(l)>8192 || $signed(l)< -8192)$fatal(1,"Optical PCM frame invalid");end endtask
initial begin
wait(adc_led && dut.optical_valid);keys=14;repeat(80)decode();if(l!==0 || dut.note_active)$fatal(1,"Board control key played while optical online");
keys=15;status=8'h7f;wait(dut.optical_keys_n==8'hfe);nonzero=0;
for(n=0;n<100;n=n+1)begin decode();if(l!=0)nonzero=nonzero+1;end
if(nonzero<50)$fatal(1,"Optical key did not reach PCM");
enabled=0;wait(dut.optical_error);repeat(1400)@(negedge ws);decode();if(l!==0 || dut.note_active)$fatal(1,"Disconnected optical keys stuck sounding");
keys=14;nonzero=0;for(n=0;n<100;n=n+1)begin decode();if(l!=0)nonzero=nonzero+1;end
if(nonzero<50)$fatal(1,"Board fallback failed");
keys=15;enabled=1;status=255;wait(dut.optical_valid);repeat(1400)@(negedge ws);decode();if(l!==0)$fatal(1,"Recovered idle optical bus not silent");
$display("PASS optical integration: separate ADC/I2C, control-only board keys, decoded stereo, disconnect release, board fallback, recovery");$finish;
end
initial begin #100000000;$fatal(1,"Optical integration timeout");end
endmodule
