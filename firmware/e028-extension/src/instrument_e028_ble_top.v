`timescale 1ns/1ps
// BLE-UART variant: the same pinout, but the serial link is a transparent
// BLE-UART module instead of the ESP-01S AT/TCP firmware.
module instrument_e028_ble_top(
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
    instrument_e027_top #(.LINK_MODE(1)) core(
        .clk(clk), .btn_n(btn_n), .JOY_SW_N(JOY_SW_N),
        .ADC_SCL(ADC_SCL), .ADC_SDA(ADC_SDA),
        .OPTICAL_SCL(OPTICAL_SCL), .OPTICAL_SDA(OPTICAL_SDA),
        .OLED_SCL(OLED_SCL), .OLED_SDA(OLED_SDA),
        .ESP_RX(ESP_RX), .K230_RX(K230_RX),
        .PCM_BCK(PCM_BCK), .PCM_LRCK(PCM_LRCK), .PCM_DATA(PCM_DATA),
        .PA_EN(PA_EN), .HP_BCK(HP_BCK), .HP_WS(HP_WS), .HP_DIN(HP_DIN),
        .led(led), .UART_TX(UART_TX), .ESP_TX(ESP_TX));
endmodule
