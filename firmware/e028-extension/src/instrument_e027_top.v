`timescale 1ns/1ps
// E027 extension top level.  Pin-compatible with the E027 Dock build except
// that N16/N14 and four more user LEDs form the six-LED performance guide.
module instrument_e027_top #(
    parameter LINK_MODE = 0 // 0 = ESP-01S Wi-Fi AT/TCP, 1 = BLE-UART transparent
)(
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
    instrument_core #(
        .SAFE_STARTUP(1),
        .ENABLE_OPTICAL(1),
        .OPTICAL_ACTIVE_LOW(0),
        .ENABLE_UI(1),
        .ENABLE_GESTURE(1),
        .GESTURE_MIN_CONFIDENCE(18),
        .LINK_MODE(LINK_MODE)
    ) core(
        .clk(clk), .btn_n(btn_n), .JOY_SW_N(JOY_SW_N),
        .ADC_SCL(ADC_SCL), .ADC_SDA(ADC_SDA),
        .OPTICAL_SCL(OPTICAL_SCL), .OPTICAL_SDA(OPTICAL_SDA),
        .OLED_SCL(OLED_SCL), .OLED_SDA(OLED_SDA),
        .ESP_RX(ESP_RX), .K230_RX(K230_RX),
        .PCM_BCK(PCM_BCK), .PCM_LRCK(PCM_LRCK), .PCM_DATA(PCM_DATA),
        .PA_EN(PA_EN), .HP_BCK(HP_BCK), .HP_WS(HP_WS), .HP_DIN(HP_DIN),
        .led(led), .UART_TX(UART_TX), .ESP_TX(ESP_TX));
endmodule
