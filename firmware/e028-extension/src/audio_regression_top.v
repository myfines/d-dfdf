`timescale 1ns/1ps
// Temporary SRAM-only autonomous acoustic probe. Inputs/peripherals unused.
// E03A identifies this probe, not the full E033 instrument.
module audio_regression_top #(parameter integer SLOT_FRAMES=93750)(
 input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
 inout wire ADC_SCL,ADC_SDA,OPTICAL_SCL,OPTICAL_SDA,OLED_SCL,OLED_SDA,
 input wire ESP_RX,K230_RX,
 output wire PCM_BCK,PCM_LRCK,PCM_DATA,PA_EN,HP_BCK,HP_WS,HP_DIN,
 output wire [3:0] led,output wire UART_TX,ESP_TX
);
 reg [15:0] boot=0;
 always @(posedge clk) if(!(&boot)) boot<=boot+1'b1;
 wire reset_n=&boot;
 wire ft;
 reg [16:0] frame=0;
 reg [4:0] slot=0;
 always @(posedge clk) begin
  if(!reset_n) begin frame<=0;slot<=0;end
  else if(ft && slot<18) begin
   if(frame==SLOT_FRAMES-1)begin frame<=0;slot<=slot+1'b1;end
   else frame<=frame+1'b1;
  end
 end
 wire single_note=(slot>=1 && slot<=4)||(slot>=6 && slot<=8)||slot==10||slot==12;
 wire [31:0] mask=single_note ? 32'h00001000 :
                  slot==14 ? 32'h00891000 : slot==16 ? 32'hFFFFFFFF : 0;
 wire signed [13:0] bend=slot==2 ? 14'sd8191 : slot==3 ? -14'sd8192 : 14'sd0;
 wire [2:0] fx=(slot==8||slot==9) ? 3'd2 :
               (slot==10||slot==11) ? 3'd4 :
               (slot==12||slot==13) ? 3'd1 : 3'd0;
 wire signed [15:0] dry,left,right;
 synth32 synth(.clk(clk),.reset_n(reset_n),.frame_tick(ft),.gate_mask(mask),.timbre(2'd1),
  .velocity(8'd120),.bend(bend),.vibrato(8'd0),.brightness(8'd128),
  // Extra capture headroom for32-note stress. PC mic input is not line level.
  .expression(slot==16 ? 8'd1 : 8'd8),.tremolo(8'd0),.sample(dry));
 fx_engine effects(clk,reset_n,ft,dry,fx,left,right);
 i2s_tx16 audio(clk,reset_n,left,right,PCM_BCK,PCM_LRCK,PCM_DATA,ft);
 assign ADC_SCL=1'bz;assign ADC_SDA=1'bz;
 assign OPTICAL_SCL=1'bz;assign OPTICAL_SDA=1'bz;
 assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;
 assign ESP_TX=1'bz;assign UART_TX=1'b1;
 assign PA_EN=0;assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
 assign led=~slot[3:0];
endmodule
