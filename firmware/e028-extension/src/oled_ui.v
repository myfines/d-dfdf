`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// 128x64 SSD1306 performance display.
//
// Five screens, selected by the panel/app:
//   0 waveform      : real post-effects audio, zero-crossing triggered
//   1 spectrum      : 16 real-time biquad bands, 8 columns per band
//   2 Lissajous     : X/Y plot of the stereo post-effects signal, frame snapshot
//   3 guide         : eight key boxes with the next song note highlighted
//   4 status        : instrument, effects, voice count, latency, song, screen
//
// The I2C master is the same bounded open-drain engine used by E027.  At HALF_TICKS=36 the nominal bus rate is 375 kHz before synchronizer
// overhead; actual refresh includes I2C ACKs/retries. Audio never waits for it.
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
    reg capture_ready, capturing;
    reg signed [15:0] previous;
    reg [9:0] trigger_wait;
    reg [1:0] decimate;
    reg [7:0] keys_hold, status_hold;
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

    reg [5:0] wave_r [0:127];
    reg [5:0] wave_r_snap [0:127];
    reg [127:0] bands_hold;
    wire snapshot = state == 4 && timer == REFRESH_TICKS-1;
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
                "K": glyph = {7'h7f,7'h08,7'h14,7'h22,7'h41};
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
        reg [167:0] row;
        begin
            row = "                     ";
            case(line)
                0: case(screen_hold)
                    0: row="SCOPE       LIVE     ";
                    1: row="SPECTRUM    16 BANDS ";
                    2: row="STEREO      XY       ";
                    3: row="PRACTICE    TARGET   ";
                    default: row="ENGINE      STATUS   ";
                endcase
                1: case(timbre_hold)
                    0: row="E PIANO              ";
                    1: row="ORGAN                ";
                    2: row="STRINGS              ";
                    3: row="BASS                 ";
                endcase
                2: begin row="VOICES 00     FX 0   ";row[111:104]="0"+voices_hold/10;row[103:96]="0"+voices_hold%10;row[31:24]=hex_char({1'b0,fx_hold});end
                3: begin row="LINK 00    KEYS 00   ";row[127:120]=hex_char(status_hold[7:4]);row[119:112]=hex_char(status_hold[3:0]);row[39:32]=hex_char(~keys_hold[7:4]);row[31:24]=hex_char(~keys_hold[3:0]);end
                4: begin row="DSP FRAMES 0000      ";row[79:72]=hex_char(latency_hold[15:12]);row[71:64]=hex_char(latency_hold[11:8]);row[63:56]=hex_char(latency_hold[7:4]);row[55:48]=hex_char(latency_hold[3:0]);end
                5: row=song_hold?"SONG PLAYING         ":"SONG STOPPED         ";
                6: row="S1 RANGE  S2 DISPLAY ";
                7: row="S3 SONG   STICK TONE ";
            endcase
            text_char=idx<21 ? (row >> ((20-idx)*8)) : 8'h20;
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
            capturing <= 0;
            capture_ready <= 0;
            previous <= 0;
            trigger_wait <= 0;
            decimate <= 0;
            write_index <= 0;
            for(k = 0; k < 128; k = k + 1) begin wave[k] <= 32; wave_r[k] <= 32; end
        end else begin
            if(snapshot) capture_ready <= 0;
            if(frame_tick) begin
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
                        wave_r[write_index] <= 6'd32 + (sample_r >>> 10);
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
    end

    // ------------------------------------------------------------------
    // capture_ready is consumed by snapshot; only the capture process drives it.
    wire [2:0] page = pixel[9:7];
    wire [6:0] column = pixel[6:0];
    integer y, lo, hi, point_x, point_y, q;
    reg hit;
    // Fixed header/footer; graphics occupy rows 16..55. All source data is
    // frozen between complete SSD1306 transfers, preventing tearing.
    always @* begin
        pixels=0; character=" "; y=0;lo=0;hi=0;point_x=0;point_y=0;hit=0;
        if(screen_hold>=4 || page<2 || page==7) begin
            character=text_char(page,char_index);
            pixels=glyph_column<5 ? ((glyph_bits >> ((4-glyph_column)*7)) & 7'h7f):0;
        end else begin
            for(b=0;b<8;b=b+1) begin
                y=page*8+b;
                case(screen_hold)
                    0: begin
                        lo=20+(wave_snap[column]>>1);
                        hi=20+(wave_snap[column==0?0:column-1]>>1);
                        if(lo>hi) begin point_y=lo;lo=hi;hi=point_y;end
                        pixels[b]=(y>=lo && y<=hi) || (y==36 && column[2:0]==0);
                    end
                    1: begin
                        hi=bands_hold[(column>>3)*8 +:8]>>3;
                        pixels[b]=column[2:0]!=7 && y>=55-hi && y<=55;
                    end
                    2: begin
                        // Bounded 32-point snapshot scatter, no persistent ghost buffer.
                        hit=0;
                        for(q=0;q<32;q=q+1) begin
                            point_x=wave_snap[q*4]*2;
                            point_y=20+(wave_r_snap[q*4]>>1);
                            if(column==point_x && y==point_y) hit=1;
                        end
                        pixels[b]=hit || (y==36 && column[3:0]==0);
                    end
                    3: begin
                        hit=(!keys_hold[column>>4]) || (song_hold && (column>>4)==guide_hold[2:0]);
                        pixels[b]=(column[3:0]>=1 && column[3:0]<=14) &&
                           ((y>=19 && y<=46 && (hit || column[3:0]==1 || column[3:0]==14 || y==19 || y==46)) ||
                            (y>=51 && y<=53 && song_hold && column<({step_hold,1'b0})));
                    end
                endcase
            end
        end
    end

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
            bands_hold <= 0;
            for(k = 0; k < 128; k = k + 1) begin wave_snap[k] <= 32; wave_r_snap[k] <= 32; end
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
                           for(k = 0; k < 128; k = k + 1) begin wave_snap[k] <= wave[k]; wave_r_snap[k] <= wave_r[k]; end
                       bands_hold <= bands;
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
