`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Maps the physical surfaces onto the 32 chromatic voice keys C3..G5.
//
//   optical key j on page p -> voice bit p*8+j
//   phone key j on page p   -> voice bit p*8+j
//   board buttons S1..S4    -> voice bits 28..31 (high E/F/F#/G)
//   app 32-bit mask "M"     -> optional direct access to all 32 voices
//   offline song player     -> additional gate bits (play-along)
//
// Latch mode turns every new key press into a sustained voice, so eight
// physical keys and four pages can build a full 32-note chord.  The app mask
// can also drive all 32 voices at once for verification.
// -----------------------------------------------------------------------------
module note_router(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        frame_tick,
    input  wire [3:0]  btn_n,
    input  wire [7:0]  optical_keys_n,
    input  wire        optical_valid,
    input  wire [7:0]  remote_keys,
    input  wire        remote_valid,
    input  wire [1:0]  page,
    input  wire        latch_enable,
    input  wire [31:0] app_mask,
    input  wire        app_override,
    input  wire [31:0] song_mask,
    output reg  [31:0] gate_mask,
    output reg  [7:0]  key_activity,
    output reg  [5:0]  active_count
);

    reg [1:0]  btn_meta [0:3];
    reg [1:0]  btn_sync [0:3];
    reg [5:0]  btn_count[0:3];
    reg [3:0]  btn_stable;

    reg [31:0] live_previous;
    reg [31:0] latch_mask;

    integer i;
    function [5:0] count_ones;
        input [31:0] v;
        integer n;
        begin
            count_ones = 6'd0;
            for(n = 0; n < 32; n = n + 1)
                count_ones = count_ones + {5'd0, v[n]};
        end
    endfunction

    // Simple 64-frame (1.37 ms) button filter.  The note path itself is not
    // delayed by this filter; only the stable key state is debounced.
    always @(posedge clk) begin
        if(!reset_n) begin
            for(i = 0; i < 4; i = i + 1) begin
                btn_meta[i] <= 2'b11;
                btn_sync[i] <= 2'b11;
                btn_count[i] <= 0;
            end
            btn_stable <= 4'hf;
        end else begin
            for(i = 0; i < 4; i = i + 1) begin
                btn_meta[i] <= {btn_meta[i][0], btn_n[i]};
                btn_sync[i] <= btn_meta[i];
                if(frame_tick) begin
                    if(btn_sync[i][1] == btn_stable[i]) btn_count[i] <= 0;
                    else if(btn_count[i] == 6'd63) begin
                        btn_stable[i] <= btn_sync[i][1];
                        btn_count[i] <= 0;
                    end else btn_count[i] <= btn_count[i] + 1'b1;
                end
            end
        end
    end

    wire [31:0] optical_wide = optical_valid ?
        ({24'd0, ~optical_keys_n} << {page, 3'b000}) : 32'd0;
    wire [31:0] remote_wide = remote_valid ?
        ({24'd0, remote_keys} << {page, 3'b000}) : 32'd0;
    wire [31:0] button_wide = {~btn_stable, 28'd0};
    wire [31:0] live_mask = optical_wide | remote_wide | button_wide;
    wire [31:0] rising = live_mask & ~live_previous;
    wire [31:0] local_mask = latch_enable ? latch_mask : live_mask;
    wire [31:0] base_mask = local_mask | (app_override ? app_mask : 32'd0);

    always @(posedge clk) begin
        if(!reset_n) begin
            live_previous <= 0;
            latch_mask <= 0;
            gate_mask <= 0;
            key_activity <= 0;
            active_count <= 0;
        end else if(frame_tick) begin
            live_previous <= live_mask;
            if(latch_enable)
                latch_mask <= latch_mask ^ rising;
            else
                latch_mask <= 0;
            gate_mask <= base_mask | song_mask;
            key_activity <= ~optical_keys_n | remote_keys | ~btn_stable;
            active_count <= count_ones(base_mask | song_mask);
        end
    end
endmodule
