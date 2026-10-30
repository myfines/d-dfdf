`timescale 1ns/1ps
// Temporary SRAM-only E043. Same production synth/FX/I2S, bounded60s sequence.
// DAC is attenuated16x solely for the PC mic; pre-attenuation peak is reported.
module audio_delivery_probe #(parameter integer SLOT_FRAMES=93750,CAPTURE_SHIFT=4)(
 input wire clk,input wire[3:0] btn_n,input wire JOY_SW_N,
 inout wire ADC_SCL,ADC_SDA,OPTICAL_SCL,OPTICAL_SDA,OLED_SCL,OLED_SDA,
 input wire ESP_RX,K230_RX,
 output wire PCM_BCK,PCM_LRCK,PCM_DATA,PA_EN,HP_BCK,HP_WS,HP_DIN,
 output wire[3:0] led,output wire UART_TX,ESP_TX);
 reg[15:0] boot=0;always @(posedge clk)if(!(&boot))boot<=boot+1'b1;
 wire reset_n=&boot;wire ft;reg[16:0] frame=0;reg[4:0] slot=0;
 always @(posedge clk)if(!reset_n)begin frame<=0;slot<=0;end
 else if(ft)begin if(frame==SLOT_FRAMES-1)begin frame<=0;if(slot<30)slot<=slot+1'b1;end else frame<=frame+1'b1;end
 reg[1:0] tone;reg[31:0] mask;reg[2:0] fx;reg[7:0] ceiling,pinch,vibrato;
 always @*begin
  tone=1;mask=0;fx=0;ceiling=160;pinch=255;vibrato=0;
  case(slot)
   1:begin tone=0;mask=32'h1000;end
   3:mask=32'h1000;
   5:begin tone=2;mask=32'h1000;end
   7:begin tone=3;mask=32'h1000;end
   9,10,11,12,13:begin mask=32'h1000;pinch=slot==10?128:slot==11?64:slot==12?0:255;end
   15:mask=32'h1000;
   16:begin mask=32'h1000;fx=1;end
   17:fx=1;
   18:begin mask=32'h1000;fx=2;end
   19:fx=2;
   20:begin mask=32'h1000;fx=4;end
   21:fx=4;
   22:begin mask=32'h00891000;ceiling=32;end
   23:ceiling=32; // Keep release-tail gain equal to the preceding held chord.
   24:begin mask=32'hffffffff;ceiling=16;end
   25:begin mask=32'hffff0000;ceiling=16;end
   26:begin mask=32'h0000ffff;ceiling=16;end
   27:ceiling=16; // Do not amplify releasing voices10x at the test boundary.
   28:begin mask=32'h1000;vibrato=80;end
   default:begin end
  endcase
 end
 // Same rounded ceiling/pinch composition as production; not a sensor test.
 wire[15:0] product=ceiling*pinch;wire[16:0] rounded={1'b0,product}+17'd128;
 wire[17:0] scaled={1'b0,rounded}+(rounded>>8);wire[7:0] expression=scaled[15:8];
 wire signed[15:0] dry,left,right;wire[5:0] voices;
 synth32 synth(.clk(clk),.reset_n(reset_n),.frame_tick(ft),.gate_mask(mask),.timbre(tone),
 .velocity(8'd159),.bend(14'sd0),.vibrato(vibrato),.brightness(8'd128),.expression(expression),
 .tremolo(8'd0),.sample(dry),.voice_count(voices),.custom_adsr(1'b0),.adsr_config(20'd0));
 fx_engine effects(clk,reset_n,ft,dry,fx,left,right);
 wire signed[15:0] capture_l=left>>>CAPTURE_SHIFT,capture_r=right>>>CAPTURE_SHIFT;
 i2s_tx16 audio(clk,reset_n,capture_l,capture_r,PCM_BCK,PCM_LRCK,PCM_DATA,ft);
 reg[15:0] peak=0;wire[15:0] magnitude=left[15]?-left:left;
 always @(posedge clk)if(!reset_n)peak<=0;else if(ft)begin
  if(frame==0)peak<=magnitude;else if(magnitude>peak)peak<=magnitude;
 end
 // Read-only9-byte marker: A5,slot,frame17bits(3bytes),peak16bits,voices,XOR.
 reg[12:0] interval=0;reg[3:0] ordinal=0;reg sending=0,start=0;reg[71:0] packet;reg[7:0] data;
 wire busy;
 uart8n1 uart(clk,reset_n,1'b1,start,data,UART_TX,busy,,);
 wire[7:0] check=8'ha5^{3'd0,slot}^{7'd0,frame[16]}^frame[15:8]^frame[7:0]^peak[15:8]^peak[7:0]^{2'd0,voices};
 always @(posedge clk)begin
  if(!reset_n)begin interval<=0;ordinal<=0;sending<=0;start<=0;packet<=0;data<=0;end
  else begin
   start<=0;
   if(ft)begin
    if(interval==4686)begin interval<=0;if(!sending)begin
     packet<={8'ha5,3'd0,slot,7'd0,frame[16],frame[15:0],peak,2'd0,voices,check};sending<=1;ordinal<=0;
    end end else interval<=interval+1'b1;
   end
   if(sending&&!busy&&!start)begin data<=packet[71:64];packet<=packet<<8;start<=1;
    if(ordinal==8)sending<=0;else ordinal<=ordinal+1'b1;
   end
  end
 end
 assign ADC_SCL=1'bz;assign ADC_SDA=1'bz;assign OPTICAL_SCL=1'bz;assign OPTICAL_SDA=1'bz;
 assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;assign ESP_TX=1'bz;
 assign PA_EN=0;assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;assign led=~slot[3:0];
endmodule
