`timescale 1ns/1ps
module instrument_io #(
    parameter integer I2C_HALF_TICKS=135,
    parameter integer CONVERSION_TICKS=27000,
    parameter integer RETRY_TICKS=270000,
    parameter integer BUS_TIMEOUT_TICKS=270000,
    parameter integer SWITCH_DEBOUNCE_TICKS=135000,
    parameter integer LONG_PRESS_FRAMES=46875,
    parameter SAFE_STARTUP=1,ENABLE_OPTICAL=0,OPTICAL_ACTIVE_LOW=1,ENABLE_UI=0,
    parameter integer OPTICAL_BOOT_TICKS=540000000,OPTICAL_POLL_TICKS=27000
)(input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
  inout wire ADC_SCL,ADC_SDA,
  output wire PCM_BCK,PCM_LRCK,PCM_DATA,
  output wire PA_EN,HP_BCK,HP_WS,HP_DIN,
  output reg LED_ALIVE,output wire LED_ADC,output wire UART_TX,
  inout wire OPTICAL_SCL,OPTICAL_SDA,
  inout wire OLED_SCL,OLED_SDA,input wire ESP_RX,output wire ESP_TX);
    reg [15:0] power_on=0;
    wire reset_n=power_on[15];
    always @(posedge clk) if(!reset_n) power_on<=power_on+1'b1;
    wire armed,arm_command;
    wire io_reset_n=reset_n && armed;
    wire pcm_bck_raw,pcm_lrck_raw,pcm_data_raw;
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
    wire [7:0] optical_keys_n,optical_raw;
    wire optical_valid,optical_error;
    wire optical_perform=optical_valid && !test_mode && !edit_mode;
    wire [3:0] optical_slots_n,optical_triggers;
    wire [11:0] optical_notes;
    wire panel_sw=(!armed || arm_command || keys_sync==4'b1001)?1'b1:sw_stable;
    generate if(SAFE_STARTUP)begin: safe_start
        io_arm_control arm(clk,reset_n,sw_stable,keys_sync,armed,arm_command);
    end else begin: legacy_start
        assign armed=1;assign arm_command=0;
    end endgenerate
    generate if(ENABLE_OPTICAL)begin: optical_interface
        optical_keys_reader #(.HALF_TICKS(I2C_HALF_TICKS),.TIMEOUT_TICKS(BUS_TIMEOUT_TICKS),
            .BOOT_TICKS(OPTICAL_BOOT_TICKS),.POLL_TICKS(OPTICAL_POLL_TICKS),.RETRY_TICKS(RETRY_TICKS),
            .ACTIVE_LOW(OPTICAL_ACTIVE_LOW)) reader(
            clk,io_reset_n,OPTICAL_SCL,OPTICAL_SDA,optical_keys_n,optical_raw,optical_valid,optical_error);
    end else begin: no_optical
        assign OPTICAL_SCL=1'bz;assign OPTICAL_SDA=1'bz;
        assign optical_keys_n=8'hff;assign optical_raw=8'hff;assign optical_valid=0;assign optical_error=0;
    end endgenerate
    optical_key_allocator allocator(clk,io_reset_n,frame_tick,
        optical_perform?optical_keys_n:8'hff,optical_slots_n,optical_notes,optical_triggers);
    // The external PCM5102A uses I2S, not the Dock PT8211's LSB-justified stream.
    // Keep the old headphone amplifier and its data interface inactive.
    assign PA_EN=0;
    assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
    assign LED_ADC=armed && controls_valid && !adc_error;
    ads1015_reader #(.I2C_HALF_TICKS(I2C_HALF_TICKS),.CONVERSION_TICKS(CONVERSION_TICKS),
        .RETRY_TICKS(RETRY_TICKS),.BUS_TIMEOUT_TICKS(BUS_TIMEOUT_TICKS)) adc(
        clk,io_reset_n,ADC_SCL,ADC_SDA,axis_x,axis_y,controls_valid,adc_error);
    instrument_panel #(.LONG_FRAMES(LONG_PRESS_FRAMES)) panel(
        clk,io_reset_n,frame_tick,panel_sw,keys_sync,controls_valid,axis_y,
        timbre,note_page,edit_mode,test_mode,octave_down,echo_enable,edit_field,
        attack_step,decay_interval,sustain_level,release_interval);
    // Test mode selects a 32-voice sine bank; ordinary keys are muted.
    voice_engine voice(clk,io_reset_n,frame_tick,play_keys,test_mode?1'b0:controls_valid,
        axis_x,test_mode?12'd0:axis_y,test_mode?1'b0:octave_down,keyboard_sample,keyboard_active,
        1'b1,test_mode?2'd1:timbre,test_mode?9'd6:attack_step,
        test_mode?16'd1:decay_interval,test_mode?9'd256:sustain_level,
        test_mode?16'd4:release_interval,note_page,
        optical_perform,optical_slots_n,optical_notes,optical_triggers);
    spectrum_bank bank(clk,io_reset_n,frame_tick,{32{test_mode}},bank_sample,bank_active,bank_busy);
    mode_router router(clk,io_reset_n,frame_tick,test_mode?2'd2:edit_mode?2'd1:2'd0,
        keyboard_sample,bank_sample,dry_sample);
    assign note_active=test_mode?bank_active:keyboard_active;
    short_delay effect(clk,io_reset_n,frame_tick,echo_enable && !test_mode && !edit_mode,dry_sample,audio_sample);
    // UART Y packs mode bits; low bit remains actual envelope activity.
    uart_status monitor(clk,reset_n,controls_valid && armed,adc_error,!armed?12'hfff:optical_valid?{4'd0,optical_keys_n}:axis_x,
        {optical_valid,note_page,timbre,edit_mode,test_mode,octave_down,echo_enable,edit_field,note_active},keys_sync,ADC_SCL,ADC_SDA,UART_TX);
    wire signed [15:0] final_sample;
    generate if(ENABLE_UI)begin: extension_ui
        wire rx_valid,tx_busy,tx_start,esp_ready,remote_active,oled_online,esp_tx_raw;
        assign ESP_TX=armed?esp_tx_raw:1'bz;
        wire [7:0] rx_data,tx_data,remote_volume,esp_diagnostic;
        uart8n1 serial_port(clk,io_reset_n,ESP_RX,tx_start,tx_data,esp_tx_raw,tx_busy,rx_valid,rx_data);
        esp_at_control wifi(clk,io_reset_n,rx_valid,rx_data,tx_busy,tx_start,tx_data,esp_ready,remote_volume,remote_active,esp_diagnostic);
        remote_audio_gain gain(clk,io_reset_n,frame_tick,remote_volume,audio_sample,final_sample);
        oled_scope screen(clk,io_reset_n,frame_tick,final_sample,optical_valid?optical_keys_n:{4'hf,keys_sync},
            {remote_active,esp_ready,echo_enable,test_mode,edit_mode,controls_valid,optical_valid,armed},OLED_SCL,OLED_SDA,oled_online,timbre,remote_volume,esp_diagnostic);
    end else begin: no_extension_ui
        assign ESP_TX=1'bz;assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;
        assign final_sample=audio_sample;
    end endgenerate
    i2s_tx16 tx(clk,io_reset_n,final_sample,final_sample,pcm_bck_raw,pcm_lrck_raw,pcm_data_raw,frame_tick);
    assign PCM_BCK=armed?pcm_bck_raw:1'bz;
    assign PCM_LRCK=armed?pcm_lrck_raw:1'bz;
    assign PCM_DATA=armed?pcm_data_raw:1'bz;
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
            heartbeat<=heartbeat+1'b1;LED_ALIVE<=!armed?heartbeat[22]:test_mode?heartbeat[20]:edit_mode?heartbeat[21]:heartbeat[23];
        end
    end
endmodule
