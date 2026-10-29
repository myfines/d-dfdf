`timescale 1ns/1ps
// Digital timing only: physical board input pin -> complete I2S word.
// Does not model switch mechanics, sensor front-end, DAC or acoustic latency.
module tb_delivery_latency;
reg clk=0; always #18.5185185 clk=~clk;
reg [3:0] keys=15; reg [1:0] preset=0;
wire bck,ws,data;
instrument_core #(.SAFE_STARTUP(0),.ENABLE_UI(0),.ENABLE_OPTICAL(0),.ENABLE_GESTURE(0),.LINK_MODE(1)) dut(
 .clk(clk),.btn_n(keys),.JOY_SW_N(1'b1),.ADC_SCL(),.ADC_SDA(),.OPTICAL_SCL(),.OPTICAL_SDA(),.OLED_SCL(),.OLED_SDA(),
 .ESP_RX(1'b1),.K230_RX(1'b1),.PCM_BCK(bck),.PCM_LRCK(ws),.PCM_DATA(data));
integer cycle=0,start_cycle=-1,first_cycle=-1,threshold_cycle=-1;
integer bits=0,value=0,pcm=0;reg last_ws=1;reg collecting=0;
always @(posedge clk) cycle=cycle+1;
always @(posedge bck) begin
 if(!dut.io_reset_n)begin bits=0;value=0;last_ws=1;collecting=0;end
 else if(ws===0 && last_ws===1)begin bits=0;value=0;collecting=1;end
 else if(collecting && bits<16)begin
  value=((value<<1)|data)&65535;bits=bits+1;
  if(bits==16 && start_cycle>=0)begin
   if(value[15:0] !== dut.audio.frame_l)$fatal(1,"I2S decoder differs from latched left word");
   pcm=value>=32768?value-65536:value;
   if(pcm!=0 && first_cycle<0)first_cycle=cycle;
   if((pcm>=32 || pcm<=-32) && threshold_cycle<0)threshold_cycle=cycle;
  end
 end
 last_ws=ws;
end
integer tone,phase,delay_cycles;
initial begin
 force dut.arm_inhibit=0;force dut.timbre=preset;
 $display("tone,phase_cycles,first_i2s_cycles,threshold32_cycles");
 for(tone=0;tone<4;tone=tone+1)begin
  for(phase=0;phase<4;phase=phase+1)begin
   start_cycle=-1;first_cycle=-1;threshold_cycle=-1;keys=15;preset=tone;
   force dut.reset_n=0;repeat(10)@(negedge clk);
   force dut.reset_n=1;repeat(1200)@(negedge clk);
   // Different event phases within the 576-clock audio frame.
   delay_cycles=phase*143;repeat(delay_cycles)@(negedge clk);
   start_cycle=cycle;keys=14;
   repeat(60000)@(negedge clk);
   if(threshold_cycle<0)$fatal(1,"no threshold32 output tone=%0d phase=%0d",tone,phase);
   if(first_cycle<0)$fatal(1,"no I2S output tone=%0d phase=%0d",tone,phase);
   if(first_cycle-start_cycle>135000)$fatal(1,"digital first sample exceeds5ms tone=%0d",tone);
   $display("%0d,%0d,%0d,%0d",tone,delay_cycles,first_cycle-start_cycle,threshold_cycle<0?-1:threshold_cycle-start_cycle);
  end
 end
 $display("PASS 16 production core board-pin to complete I2S-word cases; digital simulation only; threshold32=abs(sample)>=32");$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
