`timescale 1ns/1ps
module tb_controls;
reg clk=0;always #18.5185 clk=~clk;
reg [3:0] keys=15;reg joy=1;reg [11:0] y=825;
tri1 scl,sda;tri1 optical_scl,optical_sda;wire bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart;integer configs,n;
instrument_io #(.SAFE_STARTUP(0),.I2C_HALF_TICKS(4),.CONVERSION_TICKS(100),.RETRY_TICKS(200),
 .BUS_TIMEOUT_TICKS(500),.SWITCH_DEBOUNCE_TICKS(10),.LONG_PRESS_FRAMES(10)) dut(
 clk,keys,joy,scl,sda,bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart,optical_scl,optical_sda,,,1'b1,,1'b1);
ads1015_model slave(scl,sda,1'b1,12'd825,y,configs);
task frames(input integer count);begin repeat(count)@(negedge ws);#1;end endtask
task click;begin joy=0;frames(3);joy=1;frames(3);end endtask
task hold;begin joy=0;frames(14);joy=1;frames(3);end endtask
initial begin
wait(adc_led);frames(3);click();if(dut.timbre!=1)$fatal(1,"Integrated preset click failed");
keys=14;click();if(dut.note_page!=1)$fatal(1,"Integrated note bank failed");
keys=13;click();if(!dut.octave_down)$fatal(1,"Integrated octave failed");
keys=11;click();if(!dut.echo_enable)$fatal(1,"Integrated effect toggle failed");
keys=15;hold();if(!dut.edit_mode)$fatal(1,"Integrated edit entry failed");
keys=14;y=1650;frames(2600);if(dut.attack_step!=16 || dut.keyboard_active)$fatal(1,"Edit mapping or muted gates failed");
keys=15;hold();if(dut.edit_mode)$fatal(1,"Integrated edit exit failed");
keys=6;hold();frames(70);if(!dut.test_mode || !dut.bank_active || dut.play_keys!==15 || dut.router.current!==2'd2)$fatal(1,"32-voice mode routing failed");
repeat(110)@(negedge clk);if(dut.bank_busy)$fatal(1,"Bank cannot finish frame");
for(n=0;n<50;n=n+1)begin frames(1);if($isunknown(dut.audio_sample) || dut.audio_sample>8192 || dut.audio_sample< -8192)$fatal(1,"Mode output invalid");end
hold();keys=15;frames(5000);if(dut.test_mode || dut.note_active || dut.audio_sample!==0)$fatal(1,"Leaving test mode did not become silent");
$display("PASS controls integration: debounced combinations, runtime ADSR, edit mute, 32-voice routing, return to silence");$finish;
end
initial begin #220000000;$fatal(1,"Controls integration timeout");end
endmodule
