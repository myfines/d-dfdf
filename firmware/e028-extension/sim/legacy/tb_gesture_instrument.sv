`timescale 1ns/1ps
module tb_gesture_instrument;
reg clk=0;always #5 clk=~clk;reg rx=1;reg [3:0] keys=15;
tri1 scl,sda;wire b,w,d;reg [7:0] vectors[0:119];integer k,bitn;
instrument_io #(.SAFE_STARTUP(0),.ENABLE_GESTURE(1),.GESTURE_BIT_TICKS(16),
 .GESTURE_LEASE_TICKS(40000),.GESTURE_GAP_TICKS(2000)) dut(
 .clk(clk),.btn_n(keys),.JOY_SW_N(1'b1),.ADC_SCL(scl),.ADC_SDA(sda),
 .PCM_BCK(b),.PCM_LRCK(w),.PCM_DATA(d),.ESP_RX(1'b1),.K230_RX(rx));
task send_packet(input integer slot);reg [7:0] value;begin
 for(k=0;k<12;k=k+1)begin
  value=vectors[slot*12+k];rx=0;repeat(16)@(negedge clk);
  for(bitn=0;bitn<8;bitn=bitn+1)begin rx=value[bitn];repeat(16)@(negedge clk);end
  rx=1;repeat(20)@(negedge clk);
 end
 repeat(5)@(negedge clk);
end endtask
initial begin
 $readmemh("E:/gaoyun/tools/smoke/gesture-vectors.hex",vectors);
 wait(dut.reset_n);repeat(100)@(negedge clk);
 if(dut.gesture_active||dut.gesture_gain!=255)$fatal(1,"unconnected idle changes gain");
 send_packet(0);
 if(!dut.gesture_active||dut.gesture_seq!=254||dut.gesture_pinch!=750)$fatal(1,"UART not integrated");
 repeat(1000)@(negedge clk);
 if(dut.note_active||dut.final_sample!==0)$fatal(1,"gesture generated notes");
 if(dut.gesture_gain<190||dut.gesture_gain>192||dut.gesture_color>825)$fatal(1,"expression not applied");
 send_packet(1);if(dut.gesture_seq!=254)$fatal(1,"bad CRC applied");
 keys=13;repeat(4000)@(negedge clk);if(!dut.note_active)$fatal(1,"local notes lost");
 keys=15;repeat(42000)@(negedge clk);
 if(dut.gesture_active||dut.gesture_gain!=255)$fatal(1,"lost UART did not restore local control");
 $display("PASS gesture integrated: physical UART, CRC rejection, no autonomous note, local notes, timeout fallback");$finish;
end
initial begin #3000000;$fatal(1,"gesture integration timeout");end
endmodule
