`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Physical control panel for the extension build.
//
//   S1 short  : page 0..3 (which group of eight optical keys is active)
//   S2 short  : OLED screen 0..4
//   S3 short  : start/stop the offline song guide
//   S3 long   : latch on/off (build a 32-note chord from the eight keys)
//   S4 short  : effects preset  off -> chorus -> chorus+delay -> all
//   S4 long   : 32-voice stress test (all 32 gates on)
//   stick click: next instrument (EPiano / Organ / Strings / Bass)
//
// Buttons still play their own notes; the panel actions are edge triggered and
// never block the audio path.  A 64-frame (1.37 ms) digital filter debounces
// every mechanical contact.
// -----------------------------------------------------------------------------
module panel_ctrl(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       frame_tick,
    input  wire       sw_n,
    input  wire [3:0] keys_n,
    output reg  [1:0] timbre,
    output reg  [1:0] page,
    output reg  [2:0] screen,
    output reg        song_enable,
    output reg        latch_enable,
    output reg  [2:0] fx_enable,
    output reg        test_mode
);
    localparam integer LONG_FRAMES = 46875; // 1 s

    reg [3:0] key_sync;
    reg [3:0] key_stable;
    reg [3:0] key_prev;
    reg [5:0] key_filter [0:3];
    reg [31:0] hold_count [0:3];
    reg [3:0] long_done;

    reg sw_sync, sw_stable, sw_prev;
    reg [5:0] sw_filter;
    reg [31:0] sw_hold;
    reg sw_long_done;

    integer i;
    wire [3:0] pressed  = key_stable & ~key_prev;
    wire [3:0] released = ~key_stable & key_prev;

    always @(posedge clk) begin
        if(!reset_n) begin
            key_sync <= 0;
            key_stable <= 0;
            key_prev <= 0;
            long_done <= 0;
            sw_sync <= 0;
            sw_stable <= 0;
            sw_prev <= 0;
            sw_hold <= 0;
            sw_long_done <= 0;
            timbre <= 0;
            page <= 0;
            screen <= 0;
            song_enable <= 0;
            latch_enable <= 0;
            fx_enable <= 3'b001;
            test_mode <= 0;
            for(i = 0; i < 4; i = i + 1) begin
                key_filter[i] <= 0;
                hold_count[i] <= 0;
            end
        end else if(frame_tick) begin
            key_sync <= ~keys_n;
            sw_sync <= ~sw_n;
            key_prev <= key_stable;
            sw_prev <= sw_stable;

            for(i = 0; i < 4; i = i + 1) begin
                if(key_sync[i] == key_stable[i]) key_filter[i] <= 0;
                else if(key_filter[i] == 6'd63) begin
                    key_stable[i] <= key_sync[i];
                    key_filter[i] <= 0;
                end else key_filter[i] <= key_filter[i] + 1'b1;

                if(!key_stable[i]) begin
                    hold_count[i] <= 0;
                    long_done[i] <= 0;
                end else if(!long_done[i]) begin
                    if(hold_count[i] == LONG_FRAMES-1) begin
                        long_done[i] <= 1;
                        case(i)
                            2: latch_enable <= ~latch_enable;
                            3: test_mode <= ~test_mode;
                            default: begin end
                        endcase
                    end else hold_count[i] <= hold_count[i] + 1'b1;
                end
            end

            // Short actions on release, so a long press does not also fire.
            if(released[0] && !long_done[0]) page <= page + 1'b1;
            if(released[1] && !long_done[1]) screen <= screen == 3'd4 ? 3'd0 : screen + 1'b1;
            if(released[2] && !long_done[2]) song_enable <= ~song_enable;
            if(released[3] && !long_done[3]) begin
                case(fx_enable)
                    3'b000: fx_enable <= 3'b001;
                    3'b001: fx_enable <= 3'b011;
                    3'b011: fx_enable <= 3'b111;
                    default: fx_enable <= 3'b000;
                endcase
            end

            if(sw_sync == sw_stable) sw_filter <= 0;
            else if(sw_filter == 6'd63) begin
                sw_stable <= sw_sync;
                sw_filter <= 0;
            end else sw_filter <= sw_filter + 1'b1;

            if(!sw_stable) begin
                sw_hold <= 0;
                sw_long_done <= 0;
            end else if(!sw_long_done) begin
                if(sw_hold == LONG_FRAMES-1) begin
                    sw_long_done <= 1;
                    test_mode <= ~test_mode;
                end else sw_hold <= sw_hold + 1'b1;
            end
            if(sw_prev && !sw_stable && !sw_long_done) timbre <= timbre + 1'b1;
        end
    end
endmodule
