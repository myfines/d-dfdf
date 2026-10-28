`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// 128x64 SSD1306 performance display.
//
// Five screens, selected by the panel/app:
//   0 waveform      : real post-effects audio, zero-crossing triggered
//   1 spectrum      : 16 real-time biquad bands, 8 columns per band
//   2 Lissajous     : X/Y plot of the stereo post-effects signal, phosphor decay
//   3 guide         : eight key boxes with the next song note highlighted
//   4 status        : instrument, effects, voice count, latency, song, screen
//
// The I2C master is the same bounded open-drain engine used by E027.  A full
// 1024-byte frame takes about 100 ms at 100 kHz; audio never waits for it.
// -----------------------------------------------------------------------------
module oled_ui #(
    parameter integer HALF_TICKS = 36,
    parameter integer BOOT_TICKS = 8100000,
    parameter integer RETRY_TICKS = 27000000,
    parameter integer REFRESH_TICKS = 27000
)(
    input  wire               clk,
    input  wire               reset_n,
    input  wire               frame_tick,
    input  wire signed [15:0] sample_l,
    input  wire signed [15:0] sample_r,
    input  wire [127:0]       bands,
    input  wire [1:0]         timbre,
    input  wire [2:0]         fx_enable,
    input  wire [5:0]         voices,
    input  wire [15:0]        latency_frames,
    input  wire [2:0]         screen,
    input  wire [4:0]         guide_note,
    input  wire [5:0]         guide_step,
    input  wire               song_playing,
    input  wire [7:0]         keys_n,
    input  wire [7:0]         status,
    inout  wire               scl,
    inout  wire               sda,
    output reg                online
);

    reg start;
    reg [7:0] byte_data;
    wire busy, done, ok;
    reg [2:0] state;
    reg [31:0] timer;
    reg initializing;
    reg [4:0] init_index;
    reg [2:0] setup;
    wire [9:0] pixel;
    reg [6:0] write_index;
    reg [5:0] wave [0:127];
    reg [5:0] wave_snap [0:127];
    reg [5:0] wave_point;
    reg capture_ready, capturing;
    reg signed [15:0] previous;
    reg [9:0] trigger_wait;
    reg [1:0] decimate;
    reg [7:0] keys_hold, status_hold, mode_hold;
    reg [1:0] timbre_hold;
    reg [2:0] fx_hold, screen_hold;
    reg [5:0] voices_hold;
    reg [15:0] latency_hold;
    reg [4:0] guide_hold;
    reg [5:0] step_hold;
    reg song_hold;

    reg stream_start;
    wire stream_busy, stream_done, stream_ok;
    wire bulk = !initializing && setup == 6;
    wire selected_busy = bulk ? stream_busy : busy;
    wire selected_done = bulk ? stream_done : done;
    wire selected_ok = bulk ? stream_ok : ok;
    reg [7:0] pixels;
    integer b, k;

    // Lissajous persistence: 64 columns x 32 rows, one bit per pixel.
    reg [7:0] liss [0:255];
    reg [5:0] liss_x;
    reg [4:0] liss_y;
    reg [3:0] plot_div;
    reg [9:0] clear_timer;
    reg [1:0] clear_page;
    reg [5:0] clear_col;

    reg [7:0] character;
    wire [34:0] glyph_bits;
    wire [4:0] char_index = pixel[6:0] / 6;
    wire [2:0] glyph_column = pixel[6:0] % 6;

    assign glyph_bits = glyph(character);

    function [34:0] glyph;
        input [7:0] c;
        begin
            case(c)
                "A": glyph = {7'h7e,7'h09,7'h09,7'h09,7'h7e};
                "B": glyph = {7'h7f,7'h49,7'h49,7'h49,7'h36};
                "C": glyph = {7'h3e,7'h41,7'h41,7'h41,7'h22};
                "D": glyph = {7'h7f,7'h41,7'h41,7'h22,7'h1c};
                "E": glyph = {7'h7f,7'h49,7'h49,7'h49,7'h41};
                "F": glyph = {7'h7f,7'h09,7'h09,7'h09,7'h01};
                "G": glyph = {7'h3e,7'h41,7'h49,7'h49,7'h7a};
                "H": glyph = {7'h7f,7'h08,7'h08,7'h08,7'h7f};
                "I": glyph = {7'h00,7'h41,7'h7f,7'h41,7'h00};
                "L": glyph = {7'h7f,7'h40,7'h40,7'h40,7'h40};
                "M": glyph = {7'h7f,7'h02,7'h0c,7'h02,7'h7f};
                "N": glyph = {7'h7f,7'h04,7'h08,7'h10,7'h7f};
                "O": glyph = {7'h3e,7'h41,7'h41,7'h41,7'h3e};
                "P": glyph = {7'h7f,7'h09,7'h09,7'h09,7'h06};
                "R": glyph = {7'h7f,7'h09,7'h19,7'h29,7'h46};
                "S": glyph = {7'h26,7'h49,7'h49,7'h49,7'h32};
                "T": glyph = {7'h01,7'h01,7'h7f,7'h01,7'h01};
                "U": glyph = {7'h3f,7'h40,7'h40,7'h40,7'h3f};
                "V": glyph = {7'h1f,7'h20,7'h40,7'h20,7'h1f};
                "X": glyph = {7'h63,7'h14,7'h08,7'h14,7'h63};
                "Y": glyph = {7'h07,7'h08,7'h70,7'h08,7'h07};
                "0": glyph = {7'h3e,7'h51,7'h49,7'h45,7'h3e};
                "1": glyph = {7'h00,7'h42,7'h7f,7'h40,7'h00};
                "2": glyph = {7'h42,7'h61,7'h51,7'h49,7'h46};
                "3": glyph = {7'h21,7'h41,7'h45,7'h4b,7'h31};
                "4": glyph = {7'h18,7'h14,7'h12,7'h7f,7'h10};
                "5": glyph = {7'h27,7'h45,7'h45,7'h45,7'h39};
                "6": glyph = {7'h3c,7'h4a,7'h49,7'h49,7'h30};
                "7": glyph = {7'h01,7'h71,7'h09,7'h05,7'h03};
                "8": glyph = {7'h36,7'h49,7'h49,7'h49,7'h36};
                "9": glyph = {7'h06,7'h49,7'h49,7'h29,7'h1e};
                ":": glyph = {7'h00,7'h36,7'h36,7'h00,7'h00};
                "-": glyph = {7'h08,7'h08,7'h08,7'h08,7'h08};
                default: glyph = 0;
            endcase
        end
    endfunction

    function [7:0] hex_char;
        input [3:0] n;
        begin hex_char = n < 10 ? 8'd48 + n : 8'd55 + n; end
    endfunction

    function [7:0] text_char;
        input [2:0] line;
        input [4:0] idx;
        reg [7:0] v;
        begin
            v = " ";
            case(line)
                3'd0: case(idx)
                    0:v="E";1:v="0";2:v="2";3:v="7";4:v=" ";5:v="E";6:v="X";7:v="T";
                    default:v=" ";
                endcase
                3'd1: case(idx)
                    0:v="3";1:v="2";2:v="V";3:v="O";4:v="I";5:v="C";6:v="E";
                    7:v=" ";8:v="E";9:v="N";10:v="G";11:v="I";12:v="N";13:v="E";
                    default:v=" ";
                endcase
                3'd2: case(idx)
                    0:v="T";1:v=":";2:v=48+{6'd0,timbre_hold};
                    default:v=" ";
                endcase
                3'd3: case(idx)
                    0:v="F";1:v="X";2:v=":";3:v=hex_char({1'b0,fx_hold});
                    default:v=" ";
                endcase
                3'd4: case(idx)
                    0:v="V";1:v=":";2:v=hex_char({2'b0,voices_hold[5:4]});3:v=hex_char(voices_hold[3:0]);
                    default:v=" ";
                endcase
                3'd5: case(idx)
                    0:v="L";1:v="A";2:v="T";3:v=":";
                    4:v=hex_char(latency_hold[15:12]);5:v=hex_char(latency_hold[11:8]);
                    6:v=hex_char(latency_hold[7:4]);7:v=hex_char(latency_hold[3:0]);
                    default:v=" ";
                endcase
                3'd6: case(idx)
                    0:v="S";1:v="O";2:v="N";3:v="G";4:v=":";
                    5:v=song_hold ? "O" : "O";6:v=song_hold ? "N" : "F";7:v=song_hold ? " " : "F";
                    default:v=" ";
                endcase
                default: case(idx)
                    0:v="S";1:v="C";2:v="R";3:v=":";4:v=48+{5'd0,screen_hold};
                    default:v=" ";
                endcase
            endcase
            text_char = v;
        end
    endfunction

    // ------------------------------------------------------------------
    // I2C master instances
    // ------------------------------------------------------------------
    wire [9:0] command_index_unused;
    oled_i2c_stream #(.HALF_TICKS(HALF_TICKS), .DATA_BYTES(1), .CONTROL(8'h00)) command_bus(
        clk, reset_n, start, byte_data, command_index_unused, scl, sda, busy, done, ok);
    oled_i2c_stream #(.HALF_TICKS(HALF_TICKS)) stream_bus(
        clk, reset_n, stream_start, pixels, pixel, scl, sda, stream_busy, stream_done, stream_ok);

    function [7:0] init_byte;
        input [4:0] n;
        begin case(n)
            5'd0:init_byte=8'hae; 5'd1:init_byte=8'hd5; 5'd2:init_byte=8'h80;
            5'd3:init_byte=8'ha8; 5'd4:init_byte=8'h3f; 5'd5:init_byte=8'hd3;
            5'd6:init_byte=8'h00; 5'd7:init_byte=8'h40; 5'd8:init_byte=8'h8d;
            5'd9:init_byte=8'h14; 5'd10:init_byte=8'h20;5'd11:init_byte=8'h00;
            5'd12:init_byte=8'ha1;5'd13:init_byte=8'hc8;5'd14:init_byte=8'hda;
            5'd15:init_byte=8'h12;5'd16:init_byte=8'h81;5'd17:init_byte=8'h40;
            5'd18:init_byte=8'hd9;5'd19:init_byte=8'hf1;5'd20:init_byte=8'hdb;
            5'd21:init_byte=8'h40;5'd22:init_byte=8'ha4;5'd23:init_byte=8'ha6;
            default:init_byte=8'haf;
        endcase end
    endfunction

    function [7:0] setup_byte;
        input [2:0] n;
        begin case(n)
            3'd0:setup_byte=8'h21;3'd1:setup_byte=0;3'd2:setup_byte=127;
            3'd3:setup_byte=8'h22;3'd4:setup_byte=0;default:setup_byte=7;
        endcase end
    endfunction

    // ------------------------------------------------------------------
    // Waveform capture (screen 0)
    // ------------------------------------------------------------------
    wire signed [15:0] wave_shift = sample_l >>> 10; // -32..31
    wire signed [7:0] wave_scaled = 8'sd32 + wave_shift[7:0];
    wire [5:0] wave_y = wave_scaled < 0 ? 6'd0 :
                        wave_scaled > 63 ? 6'd63 : wave_scaled[5:0];
    always @(posedge clk) begin
        if(!reset_n) begin
            wave_point <= 32;
            capturing <= 0;
            capture_ready <= 0;
            previous <= 0;
            trigger_wait <= 0;
            decimate <= 0;
            write_index <= 0;
            for(k = 0; k < 128; k = k + 1) wave[k] <= 32;
        end else if(frame_tick) begin
            previous <= sample_l;
            if(!capture_ready) begin
                if(!capturing) begin
                    if((previous <= 0 && sample_l > 0) || trigger_wait == 1023) begin
                        capturing <= 1;
                        write_index <= 0;
                        decimate <= 0;
                        trigger_wait <= 0;
                    end else trigger_wait <= trigger_wait + 1'b1;
                end else begin
                    decimate <= decimate + 1'b1;
                    if(decimate == 0) begin
                        wave[write_index] <= wave_y;
                        write_index <= write_index + 1'b1;
                        if(write_index == 127) begin
                            capturing <= 0;
                            capture_ready <= 1;
                        end
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Lissajous plot / decay
    // ------------------------------------------------------------------
    wire signed [15:0] liss_x_raw = (sample_l >>> 11) + 16'sd32;
    wire signed [15:0] liss_y_raw = (sample_r >>> 11) + 16'sd16;
    wire [5:0] liss_px = liss_x_raw < 0 ? 6'd0 : liss_x_raw > 63 ? 6'd63 : liss_x_raw[5:0];
    wire [4:0] liss_py = liss_y_raw < 0 ? 5'd0 : liss_y_raw > 31 ? 5'd31 : liss_y_raw[4:0];

    always @(posedge clk) begin
        if(!reset_n) begin
            plot_div <= 0;
            clear_timer <= 0;
            clear_page <= 0;
            clear_col <= 0;
            for(k = 0; k < 256; k = k + 1) liss[k] <= 0;
        end else if(frame_tick) begin
            if(clear_timer == 1023) begin
                clear_timer <= 0;
                liss[{clear_page, clear_col}] <= 0;
                if(clear_col == 63) begin
                    clear_col <= 0;
                    clear_page <= clear_page + 1'b1;
                end else clear_col <= clear_col + 1'b1;
            end else clear_timer <= clear_timer + 1'b1;

            plot_div <= plot_div + 1'b1;
            if(plot_div == 4'd15) begin
                plot_div <= 0;
                // Screen 2 is the only consumer; plotting while hidden is harmless.
                liss[{liss_py[4:3], liss_px}] <= liss[{liss_py[4:3], liss_px}] |
                    (8'd1 << liss_py[2:0]);
            end
        end
    end

    // ------------------------------------------------------------------
    // Pixel renderer
    // ------------------------------------------------------------------
    wire [2:0] page = pixel[9:7];
    wire [6:0] column = pixel[6:0];
    wire [3:0] band_index = column[6:3];
    wire [5:0] bar_height = bands[band_index*8 +: 8] >> 2;
    wire [5:0] guide_key = column[6:4];

    function liss_bit;
        input [6:0] c;
        input [2:0] p;
        input [2:0] bi;
        reg [4:0] ly;
        reg [7:0] lb;
        begin
            ly = ({p,3'b000} + bi) >> 1;
            lb = liss[{ly[4:3], c[6:1]}];
            liss_bit = lb[ly[2:0]];
        end
    endfunction

    always @* begin
        pixels = 0;
        character = " ";
        case(screen_hold)
            3'd0: begin // waveform
                pixels = 8'h00;
                if(page == 7 && column[3:0] == 0) pixels[0] = 1;
                // draw a one-pixel line segment from the previous sample
                if(column == 0) pixels[wave_snap[0][5:0] >> 3] = 1;
                else begin
                    for(b = 0; b < 8; b = b + 1) begin
                        if(({page,3'b000} + b) >= wave_snap[column] &&
                           ({page,3'b000} + b) <= wave_snap[column-1])
                            pixels[b] = 1;
                        if(({page,3'b000} + b) >= wave_snap[column-1] &&
                           ({page,3'b000} + b) <= wave_snap[column])
                            pixels[b] = 1;
                    end
                end
                if(page == 7 && column < {2'b0, voices_hold, 1'b0}) pixels = 8'h0f;
            end
            3'd1: begin // spectrum
                for(b = 0; b < 8; b = b + 1) begin
                    if({page,3'b000} + b < bar_height) pixels[b] = 1;
                    if({page,3'b000} + b == 63) pixels[b] = 1;
                end
            end
            3'd2: begin // Lissajous
                for(b = 0; b < 8; b = b + 1)
                    pixels[b] = liss_bit(column, page, b[2:0]);
            end
            3'd3: begin // performance guide
                if(page < 6) begin
                    if(guide_key == guide_hold[2:0]) pixels = 8'h7e;
                    else if((page == 0 || page == 5) &&
                            column[3:0] >= 1 && column[3:0] <= 14) pixels = 8'h42;
                    if(page == 5 && column < {step_hold[5:0],1'b0}) pixels = 8'h7e;
                end else begin
                    character = text_char(page, char_index);
                    pixels = glyph_column < 5 ?
                        ((glyph_bits >> ((4-glyph_column)*7)) & 7'h7f) : 8'h00;
                end
            end
            default: begin // status
                character = text_char(page, char_index);
                pixels = glyph_column < 5 ?
                    ((glyph_bits >> ((4-glyph_column)*7)) & 7'h7f) : 8'h00;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Control / refresh state machine
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if(!reset_n) begin
            state <= 0;
            timer <= 0;
            initializing <= 1;
            init_index <= 0;
            setup <= 0;
            start <= 0;
            byte_data <= 0;
            online <= 0;
            stream_start <= 0;
            keys_hold <= 255;
            status_hold <= 0;
            timbre_hold <= 0;
            fx_hold <= 0;
            screen_hold <= 0;
            voices_hold <= 0;
            latency_hold <= 0;
            guide_hold <= 16;
            step_hold <= 0;
            song_hold <= 0;
            for(k = 0; k < 128; k = k + 1) wave_snap[k] <= 32;
        end else begin
            start <= 0;
            stream_start <= 0;
            case(state)
                0: if(timer == BOOT_TICKS-1) begin timer <= 0; state <= 1; end
                   else timer <= timer + 1'b1;
                1: if(!selected_busy) begin
                       byte_data <= initializing ? init_byte(init_index) :
                                     setup < 6 ? setup_byte(setup) : pixels;
                       if(bulk) stream_start <= 1;
                       else start <= 1;
                       state <= 2;
                   end
                2: if(selected_busy) state <= 3;
                3: if(selected_done) begin
                       if(!selected_ok) begin
                           online <= 0;
                           timer <= 0;
                           state <= 5;
                           initializing <= 1;
                           init_index <= 0;
                       end else if(initializing) begin
                           if(init_index == 24) begin
                               initializing <= 0;
                               online <= 1;
                               setup <= 0;
                               state <= 4;
                               timer <= 0;
                           end else begin
                               init_index <= init_index + 1'b1;
                               state <= 1;
                           end
                       end else if(setup < 6) begin
                           setup <= setup + 1'b1;
                           state <= 1;
                       end else begin
                           state <= 4;
                           timer <= 0;
                       end
                   end
                4: if(timer == REFRESH_TICKS-1) begin
                       if(capture_ready)
                           for(k = 0; k < 128; k = k + 1) wave_snap[k] <= wave[k];
                       keys_hold <= keys_n;
                       status_hold <= status;
                       timbre_hold <= timbre;
                       fx_hold <= fx_enable;
                       screen_hold <= screen;
                       voices_hold <= voices;
                       latency_hold <= latency_frames;
                       guide_hold <= guide_note;
                       step_hold <= guide_step;
                       song_hold <= song_playing;
                       setup <= 0;
                       timer <= 0;
                       state <= 1;
                   end else timer <= timer + 1'b1;
                5: if(timer == RETRY_TICKS-1) begin timer <= 0; state <= 1; end
                   else timer <= timer + 1'b1;
                default: state <= 0;
            endcase
        end
    end
endmodule
