`timescale 1ns/1ps
module instrument_io #(
    parameter integer I2C_HALF_TICKS=135,
    parameter integer CONVERSION_TICKS=27000,
    parameter integer RETRY_TICKS=270000,
    parameter integer BUS_TIMEOUT_TICKS=270000,
    parameter integer SWITCH_DEBOUNCE_TICKS=135000
)(input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
  inout wire ADC_SCL,ADC_SDA,
  output wire PCM_BCK,PCM_LRCK,PCM_DATA,
  output wire PA_EN,HP_BCK,HP_WS,HP_DIN,
  output reg LED_ALIVE,output wire LED_ADC);
    reg [15:0] power_on=0;
    wire reset_n=power_on[15];
    always @(posedge clk) if(!reset_n) power_on<=power_on+1'b1;
    wire [11:0] axis_x,axis_y;
    wire controls_valid,adc_error,frame_tick,note_active;
    wire signed [15:0] audio_sample;
    reg sw_meta,sw_sync,sw_stable;
    reg [31:0] sw_count;
    reg [23:0] heartbeat;
    // The external PCM5102A uses I2S, not the Dock PT8211's LSB-justified stream.
    // Keep the old headphone amplifier and its data interface inactive.
    assign PA_EN=0;
    assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
    assign LED_ADC=controls_valid && !adc_error;
    ads1015_reader #(.I2C_HALF_TICKS(I2C_HALF_TICKS),.CONVERSION_TICKS(CONVERSION_TICKS),
        .RETRY_TICKS(RETRY_TICKS),.BUS_TIMEOUT_TICKS(BUS_TIMEOUT_TICKS)) adc(
        clk,reset_n,ADC_SCL,ADC_SDA,axis_x,axis_y,controls_valid,adc_error);
    voice_engine voice(clk,reset_n,frame_tick,btn_n,controls_valid,axis_x,axis_y,
        !sw_stable,audio_sample,note_active);
    i2s_tx16 tx(clk,reset_n,audio_sample,audio_sample,PCM_BCK,PCM_LRCK,PCM_DATA,frame_tick);
    always @(posedge clk) begin
        if(!reset_n) begin
            sw_meta<=1;sw_sync<=1;sw_stable<=1;sw_count<=0;heartbeat<=0;LED_ALIVE<=0;
        end else begin
            sw_meta<=JOY_SW_N;sw_sync<=sw_meta;
            if(sw_sync==sw_stable) sw_count<=0;
            else if(sw_count==SWITCH_DEBOUNCE_TICKS-1) begin sw_stable<=sw_sync;sw_count<=0;end
            else sw_count<=sw_count+1'b1;
            heartbeat<=heartbeat+1'b1;LED_ALIVE<=heartbeat[23];
        end
    end
endmodule
