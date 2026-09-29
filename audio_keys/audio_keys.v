// Four-key playable tone for the Tang Primer 20K Dock.
// Physical keys S0-S3 are active low: T10, T3, T2, D7. T10 is in a 3.3 V
// bank and requires SSPI-as-GPIO; the other three are in a 1.5 V bank.
// The physical RCFG button is reserved for hardware reconfiguration.
//
// Note-on is immediate (only a two-flop synchronizer) so the key-to-sound
// latency stays in the millisecond range; note-off waits out contact bounce.
// The envelope attacks in about 1 ms and releases in about 5 ms, so notes
// start and stop without clicks.
// The PT8211 on the Dock is driven with 16-bit MSB-first serial audio.
module audio_keys #(
    parameter integer RELEASE_FRAMES = 235,   // about 5 ms at 46,875 frames/s
    parameter integer ATTACK_STEP = 6,        // envelope reaches full in about 1 ms
    parameter integer LED_TOGGLE_BIT = 23     // about 0.31 s per level at 27 MHz
) (
    input wire clk,
    input wire [3:0] btn_n,     // active low
    output wire HP_BCK,
    output reg HP_WS,
    output reg HP_DIN,
    output reg PA_EN,
    output reg LED_ALIVE,       // N16: heartbeat
    output reg LED_KEY          // N14: lit while a note sounds
);
    // Full scale: the triangle peaks exactly at PEAK, so nothing clips.
    localparam signed [15:0] PEAK = 16'sd32767;
    localparam [7:0] REL_MAX = RELEASE_FRAMES;

    reg [15:0] por_cnt = 16'd0;
    wire por_n = por_cnt[15];   // holds reset for about 1.2 ms after configuration

    reg [3:0] half_bit_div;
    reg bck;
    reg [4:0] bit_number;
    reg [31:0] phase;
    reg signed [15:0] frame_sample;
    reg signed [15:0] wave_sample;
    reg [8:0] env;
    reg [LED_TOGGLE_BIT:0] led_div;
    reg [3:0] btn_meta, btn_sync;
    reg sounding;
    reg [7:0] rel_cnt;
    reg [2:0] held_idx;

    wire frame_tick = (half_bit_div == 4'd8) && bck && (bit_number == 5'd0);

    // Lowest held key wins; 3'd4 means "no key".
    wire [2:0] raw_idx =
        (~btn_sync[0]) ? 3'd0 :
        (~btn_sync[1]) ? 3'd1 :
        (~btn_sync[2]) ? 3'd2 :
        (~btn_sync[3]) ? 3'd3 : 3'd4;
    wire any_raw = (raw_idx != 3'd4);

    // While a note is releasing, keep the pitch of the note that was played.
    wire [2:0] play_idx = any_raw ? raw_idx : held_idx;

    // Phase increment for 46,875 frames/s: inc = f * 2^32 / 46875.
    wire [31:0] phase_inc =
        (play_idx == 3'd0) ? 32'd47943389 :  // C5  523.2511 Hz
        (play_idx == 3'd1) ? 32'd53814635 :  // D5  587.3295 Hz
        (play_idx == 3'd2) ? 32'd60404887 :  // E5  659.2551 Hz
        (play_idx == 3'd3) ? 32'd71833926 :  // G5  783.9909 Hz
                             32'd0;

    wire [14:0] ramp = phase[29:15];
    wire signed [15:0] ramp_signed = $signed({1'b0, ramp});
    wire signed [31:0] shaped = wave_sample * $signed({1'b0, env});
    wire signed [15:0] next_sample = $signed(shaped[23:8]); // gain env/256

    // 27 MHz / (2 * 9) = 1.5 MHz BCK; 1.5 MHz / 32 = 46,875 frames per second.
    assign HP_BCK = bck;

    always @* begin
        case (phase[31:30])
            2'b00: wave_sample = ramp_signed;
            2'b01: wave_sample = PEAK - ramp_signed;
            2'b10: wave_sample = -ramp_signed;
            default: wave_sample = -PEAK + ramp_signed;
        endcase
    end

    always @(posedge clk) begin
        if (!por_n) por_cnt <= por_cnt + 16'd1;

        // Two-flop synchronizers for the mechanical keys.
        btn_meta <= btn_n;
        btn_sync <= btn_meta;

        // Heartbeat LED: the board is configured and running.
        led_div <= led_div + 1'b1;
        LED_ALIVE <= led_div[LED_TOGGLE_BIT];

        if (!por_n) begin
            half_bit_div <= 4'd0;
            bck <= 1'b0;
            bit_number <= 5'd0;
            phase <= 32'd0;
            frame_sample <= 16'sd0;
            env <= 9'd0;
            led_div <= {LED_TOGGLE_BIT + 1{1'b0}};
            LED_ALIVE <= 1'b0;
            LED_KEY <= 1'b0;
            sounding <= 1'b0;
            rel_cnt <= 8'd0;
            held_idx <= 3'd0;
            HP_WS <= 1'b0;
            HP_DIN <= 1'b0;
            PA_EN <= 1'b0;
        end else begin
            if (frame_tick) begin
                // Note-on is immediate; note-off needs the key released long
                // enough that contact bounce cannot cut a held note.
                if (any_raw) begin
                    sounding <= 1'b1;
                    rel_cnt <= 8'd0;
                    held_idx <= raw_idx;
                end else if (sounding) begin
                    if (rel_cnt == REL_MAX) sounding <= 1'b0;
                    else rel_cnt <= rel_cnt + 8'd1;
                end

                // Fast attack, slower release: no click on either edge.
                if (sounding) begin
                    if (env > 9'd250) env <= 9'd256;
                    else env <= env + ATTACK_STEP[8:0];
                end else begin
                    if (env == 9'd0) env <= 9'd0;
                    else env <= env - 9'd1;
                end

                phase <= phase + phase_inc;
            end

            if (half_bit_div == 4'd8) begin
                half_bit_div <= 4'd0;
                bck <= ~bck;
                if (bck) begin // Falling BCK: prepare data before the DAC's rising edge.
                    HP_WS <= bit_number[4];
                    bit_number <= bit_number + 5'd1;
                    if (bit_number == 5'd0) begin
                        frame_sample <= next_sample;
                        HP_DIN <= next_sample[15];
                    end else begin
                        HP_DIN <= frame_sample[15 - bit_number[3:0]];
                    end
                end
            end else begin
                half_bit_div <= half_bit_div + 4'd1;
            end

            // The headphone amplifier is only enabled while a note sounds, so
            // an idle board does not hiss.
            PA_EN <= (env != 9'd0);
            LED_KEY <= (env != 9'd0);
        end
    end
endmodule
