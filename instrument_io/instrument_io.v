`timescale 1ns/1ps
module instrument_io #(
    parameter integer I2C_HALF_TICKS=135,
    parameter integer CONVERSION_TICKS=27000,
    parameter integer RETRY_TICKS=270000,
    parameter integer BUS_TIMEOUT_TICKS=270000,
    parameter integer SWITCH_DEBOUNCE_TICKS=135000,
    parameter integer LONG_PRESS_FRAMES=46875,
    parameter SAFE_STARTUP=1,ENABLE_OPTICAL=0,OPTICAL_ACTIVE_LOW=1,ENABLE_UI=0,ENABLE_GESTURE=0,
    parameter integer GESTURE_BIT_TICKS=234,GESTURE_LEASE_TICKS=6750000,GESTURE_GAP_TICKS=540000,
    parameter integer OPTICAL_BOOT_TICKS=540000000,OPTICAL_POLL_TICKS=27000
)(input wire clk,input wire [3:0] btn_n,input wire JOY_SW_N,
  inout wire ADC_SCL,ADC_SDA,
  output wire PCM_BCK,PCM_LRCK,PCM_DATA,
  output wire PA_EN,HP_BCK,HP_WS,HP_DIN,
  output reg LED_ALIVE,output wire LED_ADC,output wire UART_TX,
  inout wire OPTICAL_SCL,OPTICAL_SDA,
  inout wire OLED_SCL,OLED_SDA,input wire ESP_RX,output wire ESP_TX,input wire K230_RX);
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
    wire [1:0] remote_tone,remote_page;
    wire remote_echo;wire [3:0] remote_keys;wire [2:0] remote_overrides;
    wire [1:0] selected_timbre=remote_overrides[0]?remote_tone:timbre;
    wire selected_echo=remote_overrides[1]?remote_echo:echo_enable;
    wire [1:0] selected_page=remote_overrides[2]?remote_page:note_page;
    wire remote_play=(|remote_keys) && !test_mode && !edit_mode;
    wire gesture_active,gesture_update;wire [7:0] gesture_seq,gesture_confidence;
    wire [9:0] gesture_pinch,gesture_y;wire [7:0] gesture_gain;
    wire [11:0] gesture_color;wire gesture_apply=gesture_active && !test_mode && !edit_mode;
    generate if(ENABLE_GESTURE)begin: gesture_input
        gesture_uart_rx #(.BIT_TICKS(GESTURE_BIT_TICKS),.LEASE_TICKS(GESTURE_LEASE_TICKS),.GAP_TICKS(GESTURE_GAP_TICKS)) receiver(clk,io_reset_n,K230_RX,gesture_active,gesture_update,
            gesture_seq,gesture_pinch,gesture_y,gesture_confidence);
    end else begin: no_gesture
        assign gesture_active=0;assign gesture_update=0;assign gesture_seq=0;
        assign gesture_pinch=0;assign gesture_y=0;assign gesture_confidence=0;
    end endgenerate
    gesture_expression expression(clk,io_reset_n,frame_tick,gesture_apply,
        gesture_pinch,gesture_y,gesture_gain,gesture_color);
    wire signed [15:0] expression_sample;
    remote_audio_gain expression_gain(clk,io_reset_n,frame_tick,gesture_gain,audio_sample,expression_sample);
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
    voice_engine voice(clk,io_reset_n,frame_tick,play_keys,test_mode?1'b0:(controls_valid || gesture_apply),
        controls_valid?axis_x:12'd825,test_mode?12'd0:gesture_apply?gesture_color:axis_y,test_mode?1'b0:octave_down,keyboard_sample,keyboard_active,
        1'b1,test_mode?2'd1:selected_timbre,test_mode?9'd6:attack_step,
        test_mode?16'd1:decay_interval,test_mode?9'd256:sustain_level,
        test_mode?16'd4:release_interval,selected_page,
        optical_perform || remote_play,remote_play?~remote_keys:optical_slots_n,
        remote_play?{3'd3,3'd2,3'd1,3'd0}:optical_notes,remote_play?4'd0:optical_triggers);
    spectrum_bank bank(clk,io_reset_n,frame_tick,{32{test_mode}},bank_sample,bank_active,bank_busy);
    mode_router router(clk,io_reset_n,frame_tick,test_mode?2'd2:edit_mode?2'd1:2'd0,
        keyboard_sample,bank_sample,dry_sample);
    assign note_active=test_mode?bank_active:keyboard_active;
    short_delay effect(clk,io_reset_n,frame_tick,selected_echo && !test_mode && !edit_mode,dry_sample,audio_sample);
    // UART Y packs mode bits; low bit remains actual envelope activity.
    uart_status monitor(clk,reset_n,controls_valid && armed,adc_error,!armed?12'hfff:optical_valid?{4'd0,optical_keys_n}:axis_x,
        {optical_valid,note_page,timbre,edit_mode,test_mode,octave_down,echo_enable,edit_field,note_active},keys_sync,ADC_SCL,ADC_SDA,UART_TX);
    wire signed [15:0] final_sample;
    generate if(ENABLE_UI)begin: extension_ui
        wire rx_valid,tx_busy,tx_start,esp_ready,remote_active,oled_online,esp_tx_raw;
        assign ESP_TX=armed?esp_tx_raw:1'bz;
        wire [7:0] rx_data,tx_data,remote_volume,esp_diagnostic,telemetry_byte;
        wire [6:0] telemetry_index;wire telemetry_capture;
        wire [7:0] visible_keys=remote_play?{4'd0,remote_keys}:optical_valid?~optical_keys_n:{4'd0,~keys_sync};
        wifi_telemetry #(.EXTENDED(ENABLE_GESTURE)) status_packet(clk,io_reset_n,frame_tick,final_sample,telemetry_capture,
            visible_keys,{armed,optical_valid,controls_valid,test_mode,edit_mode,selected_echo,note_active,remote_active},
            axis_x,axis_y,remote_volume,selected_timbre,selected_echo,selected_page,telemetry_index,telemetry_byte,
            gesture_active,gesture_seq,gesture_pinch,gesture_y,gesture_confidence);
        uart8n1 serial_port(clk,io_reset_n,ESP_RX,tx_start,tx_data,esp_tx_raw,tx_busy,rx_valid,rx_data);
        esp_at_control #(.TELEMETRY_BYTES(ENABLE_GESTURE?96:85)) wifi(clk,io_reset_n,rx_valid,rx_data,tx_busy,tx_start,tx_data,esp_ready,remote_volume,remote_active,esp_diagnostic,
            telemetry_byte,telemetry_index,telemetry_capture,remote_tone,remote_page,remote_echo,remote_keys,remote_overrides);
        remote_audio_gain gain(clk,io_reset_n,frame_tick,remote_volume,expression_sample,final_sample);
        oled_scope screen(clk,io_reset_n,frame_tick,final_sample,optical_valid?optical_keys_n:{4'hf,keys_sync},
            {remote_active,esp_ready,selected_echo,test_mode,edit_mode,controls_valid,optical_valid,armed},OLED_SCL,OLED_SDA,oled_online,selected_timbre,remote_volume,esp_diagnostic);
    end else begin: no_extension_ui
        assign remote_tone=0;assign remote_page=0;assign remote_echo=0;assign remote_keys=0;assign remote_overrides=0;
        assign ESP_TX=1'bz;assign OLED_SCL=1'bz;assign OLED_SDA=1'bz;
        assign final_sample=expression_sample;
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
