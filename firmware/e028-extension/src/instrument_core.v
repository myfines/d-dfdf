`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// E027 extension core: 32-voice engine, expression, internal effects,
// real-time visualisation, offline song/LED guide and the serial app link.
//
// The pinout is the E027 Dock pinout.  The only intentional board-level change
// is that four GPIO user LEDs become the performance guide (L16 L14 N14 N16).
// A13/C13 are dedicated package pins, not additional user LED outputs.
// -----------------------------------------------------------------------------
module instrument_core #(
    parameter integer I2C_HALF_TICKS = 135,
    parameter integer CONVERSION_TICKS = 27000,
    parameter integer RETRY_TICKS = 270000,
    parameter integer BUS_TIMEOUT_TICKS = 270000,
    parameter integer SWITCH_DEBOUNCE_TICKS = 135000,
    parameter integer GESTURE_MIN_CONFIDENCE = 18,
    parameter integer GESTURE_BIT_TICKS = 234,
    parameter integer GESTURE_LEASE_TICKS = 6750000,
    parameter integer GESTURE_GAP_TICKS = 540000,
    parameter integer OPTICAL_BOOT_TICKS = 540000000,
    parameter integer OPTICAL_POLL_TICKS = 27000,
    parameter SAFE_STARTUP = 1,
    parameter ENABLE_OPTICAL = 1,
    parameter OPTICAL_ACTIVE_LOW = 0,
    parameter ENABLE_UI = 1,
    parameter ENABLE_GESTURE = 1,
    parameter ENABLE_WEB_RELAY = 0,
    parameter LINK_MODE = 0,          // 0 = ESP-01S AT/TCP, 1 = transparent BLE-UART
    parameter integer LEASE_TICKS = 135000000
)(
    input  wire        clk,
    input  wire [3:0]  btn_n,
    input  wire        JOY_SW_N,
    inout  wire        ADC_SCL, ADC_SDA,
    inout  wire        OPTICAL_SCL, OPTICAL_SDA,
    inout  wire        OLED_SCL, OLED_SDA,
    input  wire        ESP_RX,
    input  wire        K230_RX,
    output wire        PCM_BCK, PCM_LRCK, PCM_DATA,
    output wire        PA_EN, HP_BCK, HP_WS, HP_DIN,
    output wire [3:0]  led,
    output wire        UART_TX,
    output wire        ESP_TX
);

    reg [15:0] power_on = 0;
    wire reset_n = power_on[15];
    always @(posedge clk)
        if(!reset_n) power_on <= power_on + 1'b1;

    wire armed, arm_command;
    wire io_reset_n = reset_n && armed;

    // Ignore panel key releases for 1 s after arming.  The safe-start
    // combination itself holds S1+S2 and clicks the stick; without this
    // window, releasing S2 would look like a short press and start the song.
    reg [25:0] arm_inhibit;
    reg armed_prev;
    always @(posedge clk) begin
        if(!reset_n) begin
            arm_inhibit <= 0;
            armed_prev <= 0;
        end else begin
            armed_prev <= armed;
            // 27,000,000 clocks = 1 s at 27 MHz.
            if(armed && !armed_prev) arm_inhibit <= 26'd27000000;
            else if(arm_inhibit != 0) arm_inhibit <= arm_inhibit - 1'b1;
        end
    end
    wire panel_inhibit = !armed || arm_command || (arm_inhibit != 0);

    reg [3:0] keys_meta, keys_sync;
    reg sw_meta, sw_sync, sw_stable;
    reg [31:0] sw_count;
    reg [23:0] heartbeat;

    wire [11:0] axis_x, axis_y;
    wire controls_valid, adc_error;
    wire [7:0] optical_keys_n, optical_raw;
    wire optical_valid, optical_error;

    wire frame_tick;
    wire pcm_bck_raw, pcm_lrck_raw, pcm_data_raw;
    wire signed [15:0] synth_sample, fx_l, fx_r;
    wire synth_active;
    wire [5:0] voice_count;
    wire note_on;
    wire [4:0] note_on_index;
    wire [15:0] latency_frames;

    wire [1:0] panel_timbre, panel_page;
    wire [2:0] panel_screen, panel_fx;
    wire panel_song, panel_latch, test_mode;

    wire [31:0] gate_from_router;
    wire [7:0] key_activity;
    wire [5:0] active_count;
    wire [31:0] song_gate;
    wire [4:0] guide_note;
    wire [5:0] guide_step;
    wire song_beat, song_playing;

    wire remote_active;
    wire uart_tx_serial;

    reg [7:0]  remote_volume;
    reg [7:0]  remote_vibrato, remote_brightness;
    reg [13:0] remote_bend;
    reg remote_brightness_owned, remote_bend_owned;
    reg [1:0]  remote_timbre, remote_page;
    reg [2:0]  remote_fx, remote_screen;
    reg        remote_song, remote_latch, remote_demo;
    reg [31:0] app_mask;
    reg        app_override;
    reg [31:0] lease;
    reg [7:0]  remote_keys_byte;

    wire [1:0] timbre = remote_active ? remote_timbre : panel_timbre;
    wire [1:0] page   = remote_active ? remote_page : panel_page;
    wire [2:0] screen = remote_active ? remote_screen : panel_screen;
    wire [2:0] fx_on  = remote_active ? remote_fx : panel_fx;
    wire       song_on = panel_song | remote_song;
    wire       latch_on = panel_latch | remote_latch;
    wire       demo_on = remote_demo;

    wire signed [13:0] bend_joy;
    wire [7:0] velocity_local;
    wire [7:0] velocity;
    wire [7:0] vibrato;
    wire [7:0] brightness;
    wire [7:0] expression;
    wire [7:0] tremolo;

    wire [31:0] performance_gate = panel_inhibit ? 32'd0 : gate_from_router;
    wire [31:0] synth_gate = (test_mode || demo_on) ? 32'hFFFFFFFF : performance_gate;

    wire gesture_active, gesture_update;
    wire [7:0] gesture_seq, gesture_confidence;
    wire [9:0] gesture_pinch, gesture_y;
    wire [7:0] gesture_gain;
    wire [11:0] gesture_color;

    wire [7:0] rx_data;
    wire rx_valid, tx_busy;
    wire [7:0] tx_data;
    wire tx_start;

    wire cmd_valid;
    wire [7:0] cmd_kind;
    wire [31:0] cmd_value;

    wire esp_ready, telemetry_capture;
    wire [7:0] telemetry_byte;
    wire [7:0] telemetry_normal,telemetry_record;wire record_mode;
    // Hold the packet kind for its entire transmission, even if C changes mid-frame.
    reg telemetry_record_selected;
    always @(posedge clk)begin
        if(!io_reset_n)telemetry_record_selected<=0;
        else if(telemetry_capture)telemetry_record_selected<=record_mode;
    end
    assign telemetry_byte=telemetry_record_selected?telemetry_record:telemetry_normal;
    wire [6:0] telemetry_index;

    wire signed [15:0] final_l, final_r;
    wire [127:0] spectrum_bands;
    wire oled_online;

    // ------------------------------------------------------------------
    // Input synchronizers / debounce
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if(!reset_n) begin
            keys_meta <= 4'hf;
            keys_sync <= 4'hf;
            sw_meta <= 1;
            sw_sync <= 1;
            sw_stable <= 1;
            sw_count <= 0;
            heartbeat <= 0;
        end else begin
            keys_meta <= btn_n;
            keys_sync <= keys_meta;
            sw_meta <= JOY_SW_N;
            sw_sync <= sw_meta;
            if(sw_sync == sw_stable) sw_count <= 0;
            else if(sw_count == SWITCH_DEBOUNCE_TICKS-1) begin
                sw_stable <= sw_sync;
                sw_count <= 0;
            end else sw_count <= sw_count + 1'b1;
            heartbeat <= heartbeat + 1'b1;
        end
    end

    wire panel_sw = (!armed || arm_command || keys_sync == 4'b1001) ? 1'b1 : sw_stable;
    generate if(SAFE_STARTUP) begin: safe_start
        io_arm_control arm(clk, reset_n, sw_stable, keys_sync, armed, arm_command);
    end else begin: legacy_start
        assign armed = 1'b1;
        assign arm_command = 1'b0;
    end endgenerate

    // ------------------------------------------------------------------
    // Sensors
    // ------------------------------------------------------------------
    ads1015_reader #(
        .I2C_HALF_TICKS(I2C_HALF_TICKS), .CONVERSION_TICKS(CONVERSION_TICKS),
        .RETRY_TICKS(RETRY_TICKS), .BUS_TIMEOUT_TICKS(BUS_TIMEOUT_TICKS)
    ) adc(
        clk, io_reset_n, ADC_SCL, ADC_SDA, axis_x, axis_y, controls_valid, adc_error);

    generate if(ENABLE_OPTICAL) begin: optical_interface
        optical_keys_reader #(
            .HALF_TICKS(I2C_HALF_TICKS), .TIMEOUT_TICKS(BUS_TIMEOUT_TICKS),
            .BOOT_TICKS(OPTICAL_BOOT_TICKS), .POLL_TICKS(OPTICAL_POLL_TICKS),
            .RETRY_TICKS(RETRY_TICKS), .ACTIVE_LOW(OPTICAL_ACTIVE_LOW)
        ) reader(
            clk, io_reset_n, OPTICAL_SCL, OPTICAL_SDA,
            optical_keys_n, optical_raw, optical_valid, optical_error);
    end else begin: no_optical
        assign OPTICAL_SCL = 1'bz;
        assign OPTICAL_SDA = 1'bz;
        assign optical_keys_n = 8'hff;
        assign optical_raw = 8'hff;
        assign optical_valid = 0;
        assign optical_error = 0;
    end endgenerate

    generate if(ENABLE_GESTURE) begin: gesture_input
        gesture_uart_rx #(
            .MIN_CONFIDENCE(GESTURE_MIN_CONFIDENCE), .BIT_TICKS(GESTURE_BIT_TICKS),
            .LEASE_TICKS(GESTURE_LEASE_TICKS), .GAP_TICKS(GESTURE_GAP_TICKS)
        ) receiver(
            clk, io_reset_n, K230_RX, gesture_active, gesture_update,
            gesture_seq, gesture_pinch, gesture_y, gesture_confidence);
    end else begin: no_gesture
        assign gesture_active = 0;
        assign gesture_update = 0;
        assign gesture_seq = 0;
        assign gesture_pinch = 0;
        assign gesture_y = 0;
        assign gesture_confidence = 0;
    end endgenerate

    gesture_expression expression_map(
        clk, io_reset_n, frame_tick, gesture_active && !test_mode,
        gesture_pinch, gesture_y, gesture_gain, gesture_color);

    // ------------------------------------------------------------------
    // Panel and expression mapping
    // ------------------------------------------------------------------
    panel_ctrl panel(
        clk, io_reset_n, frame_tick, panel_sw, keys_sync, panel_inhibit,
        panel_timbre, panel_page, panel_screen,
        panel_song, panel_latch, panel_fx, test_mode);

    wire [7:0] local_brightness;
    performance_controls performance_map(axis_y,gesture_color,controls_valid,gesture_active,
        velocity_local,local_brightness);
    assign velocity=velocity_local;

    wire signed [12:0] delta = $signed({1'b0, axis_x > 1650 ? 12'd1650 : axis_x}) - 13'sd825;
    wire signed [20:0] bend_product = delta * 13'sd10;
    assign bend_joy = !controls_valid ? 14'sd0 :
        bend_product > 21'sd8191 ? 14'sd8191 :
        bend_product < -21'sd8192 ? -14'sd8192 : bend_product[13:0];

    // Pinch is volume, not an implicit vibrato/tremolo macro.
    assign vibrato = remote_active ? remote_vibrato : 8'd0;
    assign brightness = remote_active && remote_brightness_owned ? remote_brightness : local_brightness;
    wire [7:0] volume_ceiling = remote_active ? remote_volume : 8'd255;
    wire [7:0] pinch_gain = gesture_active ? gesture_gain : 8'd255;
    wire [15:0] expression_product = volume_ceiling * pinch_gain;
    // Rounded division by255, retaining exact unity endpoints.
    wire [16:0] expression_rounded = {1'b0,expression_product} + 17'd128;
    wire [17:0] expression_scaled = {1'b0,expression_rounded} + (expression_rounded >> 8);
    assign expression = expression_scaled[15:8];
    assign tremolo = 8'd0;
    wire signed [13:0] bend = remote_active && remote_bend_owned ? remote_bend : bend_joy;

    // ------------------------------------------------------------------
    // Note routing and song
    // ------------------------------------------------------------------
    wire [159:0] key_mapping; wire keymap_rejected;
    keymap_control keymap(clk,io_reset_n,cmd_valid,cmd_kind,cmd_value,key_mapping,keymap_rejected);
    note_router router(
        clk, io_reset_n, frame_tick, keys_sync,
        optical_keys_n, optical_valid,
        remote_keys_byte, remote_active,
        page, latch_on, app_mask, app_override, song_gate,
        gate_from_router, key_activity, active_count,key_mapping);

    wire [6:0] downloaded_length;wire downloaded_ready;
    song_player song(
        clk, io_reset_n, frame_tick, song_on,
        song_gate, guide_note, guide_step, song_beat, song_playing,cmd_valid,cmd_kind,cmd_value,downloaded_length,downloaded_ready);

    // ------------------------------------------------------------------
    // 32-voice engine and effects
    // ------------------------------------------------------------------
    wire custom_adsr;wire [19:0] custom_adsr_config;wire adsr_rejected;
    envelope_control envelope_settings(clk,io_reset_n,cmd_valid,cmd_kind,cmd_value,
        custom_adsr,custom_adsr_config,adsr_rejected);
    synth32 synth(
        clk, io_reset_n, frame_tick, synth_gate, timbre, velocity,
        bend, vibrato, brightness, expression, tremolo,
        synth_sample, synth_active, voice_count, note_on, note_on_index, latency_frames, custom_adsr,custom_adsr_config);

    fx_engine effects(
        clk, io_reset_n, frame_tick, synth_sample, fx_on, fx_l, fx_r);

    wire spectrum_busy;
    spectrum16 analyser(
        .clk(clk), .reset_n(io_reset_n), .frame_tick(frame_tick),
        .sample(fx_l), .bands(spectrum_bands), .busy(spectrum_busy));

    assign final_l = fx_l;
    assign final_r = fx_r;

    // ------------------------------------------------------------------
    // Serial link: ESP-01S AT/TCP or transparent BLE-UART
    // ------------------------------------------------------------------
    uart8n1 serial(
        clk, io_reset_n, ESP_RX, tx_start, tx_data, uart_tx_serial,
        tx_busy, rx_valid, rx_data);

    assign ESP_TX = (LINK_MODE == 0 && armed) ? uart_tx_serial : 1'bz;

    wire [2:0] cmd_client_unused;
    wire raw_cmd_valid;wire[7:0] raw_cmd_kind;wire[31:0] raw_cmd_value;
    wire http_request,http_command;wire[2:0] http_client;wire[1:0] http_route;
    wire[7:0] http_kind;wire[31:0] http_value;
    esp_http_request http_parser(clk,io_reset_n && (LINK_MODE==0),rx_valid,rx_data,
        http_request,http_client,http_route,http_command,http_kind,http_value);
    assign cmd_valid=raw_cmd_valid|http_command;
    assign cmd_kind=http_command?http_kind:raw_cmd_kind;
    assign cmd_value=http_command?http_value:raw_cmd_value;
    esp_command_parser #(.RAW_MODE(LINK_MODE)) parser(
        .clk(clk), .reset_n(io_reset_n), .valid(rx_valid), .data(rx_data),
        .cmd_valid(raw_cmd_valid), .cmd_kind(raw_cmd_kind), .cmd_value(raw_cmd_value),
        .cmd_client(cmd_client_unused));

    generate if(LINK_MODE == 0) begin: wifi_link
        wire [7:0] dummy_volume;
        wire [1:0] dummy_timbre, dummy_page;
        wire dummy_echo;
        wire [2:0] dummy_overrides;
        wire dummy_active;
        wire [7:0] esp_diagnostic;
        wire [7:0] dummy_keys;

        if(ENABLE_WEB_RELAY)begin: cloud
            esp_cloud_control wifi(clk,io_reset_n,rx_valid,rx_data,tx_busy,tx_start,tx_data,
                esp_ready,telemetry_byte,telemetry_index,telemetry_capture,esp_diagnostic);
        end else begin: local_ap
        esp_at_control #(.TELEMETRY_BYTES(96)) wifi(
            clk, io_reset_n, rx_valid, rx_data, tx_busy, tx_start, tx_data,
            esp_ready, dummy_volume, dummy_active, esp_diagnostic,
            telemetry_byte, telemetry_index, telemetry_capture,
            dummy_timbre, dummy_page, dummy_echo, dummy_keys, dummy_overrides);
        end
    end else begin: ble_link
        assign esp_ready = 1'b1;
        assign telemetry_capture = 1'b0;
        assign tx_start = 1'b0;
        assign tx_data = 8'd0;
    end endgenerate

    // Command register file / lease
    always @(posedge clk) begin
        if(!reset_n) begin
            remote_volume <= 255;
            remote_vibrato <= 0;
            remote_brightness <= 128;
            remote_bend <= 0;
            remote_brightness_owned <= 0;
            remote_bend_owned <= 0;
            remote_timbre <= 0;
            remote_page <= 0;
            remote_fx <= 0;
            remote_screen <= 0;
            remote_song <= 0;
            remote_latch <= 0;
            remote_demo <= 0;
            app_mask <= 0;
            app_override <= 0;
            lease <= 0;
            remote_keys_byte <= 0;
        end else begin
            if(lease != 0) begin
                lease <= lease - 1'b1;
                if(lease == 1) begin
                    remote_vibrato <= 0;
                    remote_brightness_owned <= 0;
                    remote_bend_owned <= 0;
                    remote_keys_byte <= 0;
                    app_override <= 0;
                    remote_song <= 0;
                    remote_latch <= 0;
                    remote_demo <= 0;
                    remote_fx <= 0;
                    remote_screen <= 0;
                    remote_volume <= 255;
                end
            end
            if(cmd_valid) begin
                lease <= LEASE_TICKS;
                case(cmd_kind)
                    "V": remote_volume <= cmd_value[7:0];
                    "T": remote_timbre <= cmd_value[1:0];
                    "E": remote_fx[1] <= cmd_value[0];
                    "K": remote_keys_byte <= cmd_value[7:0];
                    "P": remote_page <= cmd_value[1:0];
                    "M": begin app_mask <= cmd_value; app_override <= 1; end
                    "B": begin remote_bend <= $signed(cmd_value[13:0]) - 14'sd8192; remote_bend_owned <= 1; end
                    "X": remote_vibrato <= cmd_value[7:0];
                    "Y": begin remote_brightness <= cmd_value[7:0]; remote_brightness_owned <= 1; end
                    "F": remote_fx <= cmd_value[2:0];
                    "S": remote_screen <= cmd_value[2:0];
                    "R": remote_song <= cmd_value[0];
                    "H": remote_latch <= cmd_value[0];
                    "D": remote_demo <= cmd_value[0];
                    "Q": begin end
                    "L": begin
                        remote_vibrato <= 0;
                        remote_brightness_owned <= 0;
                        remote_bend_owned <= 0;
                        lease <= 0;
                        remote_keys_byte <= 0;
                        app_override <= 0;
                        remote_song <= 0;
                        remote_latch <= 0;
                        remote_demo <= 0;
                    end
                    default: begin end
                endcase
            end
        end
    end
    assign remote_active = lease != 0;

    // ------------------------------------------------------------------
    // LEDs and display
    // ------------------------------------------------------------------
    wire [3:0] guide_led;
    // Dock LED anodes are tied to3V3; physical pins are active-low.
    // Keep a boot heartbeat independent of io_reset_n/frame_tick.
    assign led=armed?~guide_led:{heartbeat[22],3'b111};
    led_guide lamps(
        clk, io_reset_n, frame_tick, song_playing, guide_note, song_beat,
        voice_count, heartbeat, guide_led);

    generate if(ENABLE_UI) begin: ui
        wire [7:0] oled_status = {
            armed, optical_valid, controls_valid, song_on,
            latch_on, remote_active, test_mode, synth_active};
        wire [1:0] unused_tone;
        wire [7:0] unused_diag;
        oled_ui #(.HALF_TICKS(36)) screen_ui(
            clk, io_reset_n, frame_tick, final_l, final_r, spectrum_bands,
            timbre, fx_on, voice_count, latency_frames, screen,
            guide_note, guide_step, song_playing, optical_valid ? optical_keys_n : 8'hff,
            oled_status, OLED_SCL, OLED_SDA, oled_online,
            page,key_mapping,song_gate[guide_note]);

        wire [7:0] visible_keys = remote_keys_byte | {4'd0, ~keys_sync};
        begin: recording
            pcm_record recorder(clk,io_reset_n,frame_tick,final_l,cmd_valid,cmd_kind,cmd_value,
                telemetry_capture,telemetry_index,record_mode,telemetry_record,
                downloaded_length,downloaded_ready,custom_adsr,custom_adsr_config,key_mapping);
        end
        wifi_telemetry #(.EXTENDED(1)) status_packet(
            clk, io_reset_n, frame_tick, final_l, telemetry_capture,
            visible_keys,
            oled_status, axis_x, axis_y, remote_volume, timbre, |fx_on, page,
            telemetry_index, telemetry_normal,
            gesture_active, gesture_seq, gesture_pinch, gesture_y, gesture_confidence);
    end else begin: no_ui
        assign OLED_SCL = 1'bz;
        assign OLED_SDA = 1'bz;
        assign oled_online = 1'b0;
    end endgenerate

    // ------------------------------------------------------------------
    // Audio / status outputs
    // ------------------------------------------------------------------
    i2s_tx16 audio(
        clk, io_reset_n, final_l, final_r,
        pcm_bck_raw, pcm_lrck_raw, pcm_data_raw, frame_tick);

    assign PCM_BCK = armed ? pcm_bck_raw : 1'bz;
    assign PCM_LRCK = armed ? pcm_lrck_raw : 1'bz;
    assign PCM_DATA = armed ? pcm_data_raw : 1'bz;
    assign PA_EN = 0;
    assign HP_BCK = 0;
    assign HP_WS = 0;
    assign HP_DIN = 0;

    uart_status monitor(
        clk, reset_n, controls_valid && armed, adc_error,
        !armed ? 12'hfff : optical_valid ? {4'd0, optical_keys_n} : axis_x,
        axis_y, keys_sync,
        1'b1, 1'b1,
        UART_TX);

endmodule
