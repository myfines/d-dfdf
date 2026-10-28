`timescale 1ns/1ps
// Temporary SRAM-only fixed sequencer; automatic idle after sixteen seconds.
module audio_probe_top #(parameter integer SLOT_FRAMES=46875)(
    input  wire       clk,
    input  wire [3:0] btn_n,
    input  wire       JOY_SW_N,
    inout  wire       ADC_SCL, ADC_SDA,
    inout  wire       OPTICAL_SCL, OPTICAL_SDA,
    inout  wire       OLED_SCL, OLED_SDA,
    input  wire       ESP_RX,
    input  wire       K230_RX,
    output wire       PCM_BCK, PCM_LRCK, PCM_DATA,
    output wire       PA_EN, HP_BCK, HP_WS, HP_DIN,
    output wire [3:0] led,
    output wire       UART_TX,
    output wire       ESP_TX
);
    reg [15:0] boot=0;
    always @(posedge clk) if(!(&boot)) boot<=boot+1'b1;
    wire reset_n=&boot;
    wire ft;wire signed [15:0] sample;
    reg [15:0] frame=0;reg [4:0] slot=0;
    always @(posedge clk) begin
      if(!reset_n) begin frame<=0;slot<=0;end
      else if(ft && slot<16) begin
        if(frame==SLOT_FRAMES-1)begin frame<=0;slot<=slot+1'b1;end
        else frame<=frame+1'b1;
      end
    end
    wire [31:0] mask = slot==1||slot==3||slot==5||slot==7 ? 32'h00001000 :
                             slot==9 ? 32'h00891000 : slot==11 ? 32'h00000001 : slot==13 ? 32'h80000000 : 0;
    wire [1:0] tone = slot<8 ? slot[2:1] : 0;
    synth32 synth(.clk(clk),.reset_n(reset_n),.frame_tick(ft),.gate_mask(mask),.timbre(tone),
       .velocity(8'd160),.bend(14'sd0),.vibrato(8'd0),.brightness(8'd200),.expression(8'd96),.tremolo(8'd0),.sample(sample));
    i2s_tx16 audio(clk,reset_n,sample,sample,PCM_BCK,PCM_LRCK,PCM_DATA,ft);
    assign ADC_SCL=1'bz;assign ADC_SDA=1'bz;assign OPTICAL_SCL=1'bz;assign OPTICAL_SDA=1'bz;
    assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;
    assign ESP_TX=1'bz;assign UART_TX=1'b1;
    assign PA_EN=0;assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
    assign led=~slot[3:0];
endmodule
