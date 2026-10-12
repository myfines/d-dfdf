`timescale 1ns/1ps
module instrument_io #(
    parameter integer I2C_HALF_TICKS=135,
    parameter integer CONVERSION_TICKS=27000,
    parameter integer RETRY_TICKS=270000,
    parameter integer BUS_TIMEOUT_TICKS=270000,
    parameter integer SWITCH_DEBOUNCE_TICKS=135000,
    parameter integer LONG_PRESS_FRAMES=46875
)(input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
  inout wire ADC_SCL,ADC_SDA,
  output wire PCM_BCK,PCM_LRCK,PCM_DATA,
  output wire PA_EN,HP_BCK,HP_WS,HP_DIN,
  output reg LED_ALIVE,output wire LED_ADC,output wire UART_TX);
    reg [15:0] power_on=0;
    wire reset_n=power_on[15];
    always @(posedge clk) if(!reset_n) power_on<=power_on+1'b1;
    wire [11:0] axis_x,axis_y;
    wire controls_valid,adc_error,frame_tick,note_active;
    wire signed [15:0] audio_sample,dry_sample,keyboard_sample,bank_sample;
    wire keyboard_active,bank_active,bank_busy;
    reg [3:0] keys_meta,keys_sync;
    wire [1:0] timbre,note_page,edit_field;
    wire edit_mode,test_mode,octave_down,echo_enable;
    wire [8:0] attack_step,sustain_level;
    wire [15:0] decay_interval,release_interval;
    wire [3:0] play_keys=(test_mode || edit_mode)?4'd15:keys_sync;
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
    instrument_panel #(.LONG_FRAMES(LONG_PRESS_FRAMES)) panel(
        clk,reset_n,frame_tick,sw_stable,keys_sync,controls_valid,axis_y,
        timbre,note_page,edit_mode,test_mode,octave_down,echo_enable,edit_field,
        attack_step,decay_interval,sustain_level,release_interval);
    // Test mode selects a 32-voice sine bank; ordinary keys are muted.
    voice_engine voice(clk,reset_n,frame_tick,play_keys,test_mode?1'b0:controls_valid,
        axis_x,test_mode?12'd0:axis_y,test_mode?1'b0:octave_down,keyboard_sample,keyboard_active,
        1'b1,test_mode?2'd1:timbre,test_mode?9'd6:attack_step,
        test_mode?16'd1:decay_interval,test_mode?9'd256:sustain_level,
        test_mode?16'd4:release_interval,note_page);
    spectrum_bank bank(clk,reset_n,frame_tick,{32{test_mode}},bank_sample,bank_active,bank_busy);
    mode_router router(clk,reset_n,frame_tick,test_mode?2'd2:edit_mode?2'd1:2'd0,
        keyboard_sample,bank_sample,dry_sample);
    assign note_active=test_mode?bank_active:keyboard_active;
    short_delay effect(clk,reset_n,frame_tick,echo_enable && !test_mode && !edit_mode,dry_sample,audio_sample);
    // UART Y packs mode bits; low bit remains actual envelope activity.
    uart_status monitor(clk,reset_n,controls_valid,adc_error,axis_x,
        {1'd0,note_page,timbre,edit_mode,test_mode,octave_down,echo_enable,edit_field,note_active},keys_sync,ADC_SCL,ADC_SDA,UART_TX);
    i2s_tx16 tx(clk,reset_n,audio_sample,audio_sample,PCM_BCK,PCM_LRCK,PCM_DATA,frame_tick);
    always @(posedge clk) begin
        if(!reset_n) begin
            keys_meta<=15;keys_sync<=15;
            sw_meta<=1;sw_sync<=1;sw_stable<=1;sw_count<=0;heartbeat<=0;LED_ALIVE<=0;
        end else begin
            keys_meta<=btn_n;keys_sync<=keys_meta;
            sw_meta<=JOY_SW_N;sw_sync<=sw_meta;
            if(sw_sync==sw_stable) sw_count<=0;
            else if(sw_count==SWITCH_DEBOUNCE_TICKS-1) begin sw_stable<=sw_sync;sw_count<=0;end
            else sw_count<=sw_count+1'b1;
            heartbeat<=heartbeat+1'b1;LED_ALIVE<=test_mode?heartbeat[20]:edit_mode?heartbeat[21]:heartbeat[23];
        end
    end
endmodule
