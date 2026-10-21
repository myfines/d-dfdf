`timescale 1ns/1ps
module instrument_optical_top #(parameter ACTIVE_LOW=0)(input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
 inout wire ADC_SCL,ADC_SDA,OPTICAL_SCL,OPTICAL_SDA,
 output wire PCM_BCK,PCM_LRCK,PCM_DATA,PA_EN,HP_BCK,HP_WS,HP_DIN,LED_ALIVE,LED_ADC,UART_TX);
 instrument_io #(.SAFE_STARTUP(1),.ENABLE_OPTICAL(1),.OPTICAL_ACTIVE_LOW(ACTIVE_LOW)) core(clk,btn_n,JOY_SW_N,ADC_SCL,ADC_SDA,
 PCM_BCK,PCM_LRCK,PCM_DATA,PA_EN,HP_BCK,HP_WS,HP_DIN,LED_ALIVE,LED_ADC,UART_TX,OPTICAL_SCL,OPTICAL_SDA,,,1'b1,);
endmodule
