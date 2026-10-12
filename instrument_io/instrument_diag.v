`timescale 1ns/1ps
// Diagnostic only: known onboard key audio + unconditional external 440 Hz.
// ADC is observed, not used to gate either sound. Telemetry uses onboard UART B.
module instrument_diag #(parameter integer UART_PERIOD_TICKS=6750000)(
    input wire clk,input wire [3:0] btn_n,
    inout wire ADC_SCL,ADC_SDA,
    output wire PCM_BCK,PCM_LRCK,PCM_DATA,
    output wire PA_EN,HP_BCK,HP_WS,HP_DIN,
    output wire LED_ALIVE,LED_ADC,UART_TX);
    reg [15:0] power_on=0;
    wire reset_n=power_on[15];
    always @(posedge clk) if(!reset_n)power_on<=power_on+1'b1;
    wire [11:0] axis_x,axis_y;
    wire valid,error,tick,unused_key_led;
    reg [31:0] phase;
    reg [3:0] keys_meta,keys_sync;
    reg scl_meta,scl_sync,sda_meta,sda_sync;
    wire [14:0] magnitude=phase[30]?~phase[29:15]:phase[29:15];
    wire [15:0] triangle={phase[31],magnitude^{15{phase[31]}}};
    wire signed [15:0] tone=$signed({{2{triangle[15]}},triangle[15:2]});
    assign LED_ADC=valid && !error;
    audio_keys reference_voice(.clk(clk),.btn_n(btn_n),.HP_BCK(HP_BCK),.HP_WS(HP_WS),
        .HP_DIN(HP_DIN),.PA_EN(PA_EN),.LED_ALIVE(LED_ALIVE),.LED_KEY(unused_key_led));
    ads1015_reader adc(clk,reset_n,ADC_SCL,ADC_SDA,axis_x,axis_y,valid,error);
    i2s_tx16 external_tone(clk,reset_n,tone,tone,PCM_BCK,PCM_LRCK,PCM_DATA,tick);
    uart_status #(.PERIOD_TICKS(UART_PERIOD_TICKS)) monitor(
        clk,reset_n,valid,error,axis_x,axis_y,keys_sync,scl_sync,sda_sync,UART_TX);
    always @(posedge clk) begin
        if(!reset_n)begin
            phase<=0;keys_meta<=15;keys_sync<=15;scl_meta<=1;scl_sync<=1;sda_meta<=1;sda_sync<=1;
        end else begin
            if(tick)phase<=phase+32'd40315427; // 440 Hz, calibrated to 46,875 frames/s.
            keys_meta<=btn_n;keys_sync<=keys_meta;
            scl_meta<=ADC_SCL;scl_sync<=scl_meta;sda_meta<=ADC_SDA;sda_sync<=sda_meta;
        end
    end
endmodule
