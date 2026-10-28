`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// synth32: 32-voice polyphonic synthesis engine for the E027 extension.
//
// * One voice per chromatic note C3..G5 (32 notes).  Every voice owns its own
//   32-bit phase accumulator, per-note envelope state/level/counter and
//   velocity.  The arithmetic (one sine ROM, one multiplier at a time) is
//   time-multiplexed, but the state is never shared: all 32 oscillators can run
//   at independent frequencies and envelopes at the same time.
// * Four distinct instruments are generated additively from a single
//   mathematically defined sine ROM.  No recorded samples are used.
// * Performance expression: per-note velocity, global pitch bend (14 bit),
//   vibrato depth, brightness (one-pole low-pass), tremolo and expression.
// * Frame rate is 46.875 kHz (576 clocks per frame at 27 MHz).  All 32 voices
//   are rendered within one frame (288 clocks worst case).
// -----------------------------------------------------------------------------
module synth32(
    input  wire               clk,
    input  wire               reset_n,
    input  wire               frame_tick,
    input  wire [31:0]        gate_mask,       // bit n -> note 48+n (C3..G5)
    input  wire [1:0]         timbre,          // 0 EPiano 1 Organ 2 Strings 3 Bass
    input  wire [7:0]         velocity,        // velocity for newly gated notes
    input  wire signed [13:0] bend,            // -8192..8191, +-2 semitones
    input  wire [7:0]         vibrato,         // 0..255 -> 0..~50 cents
    input  wire [7:0]         brightness,      // 0..255 low-pass cutoff
    input  wire [7:0]         expression,      // 0..255 output level
    input  wire [7:0]         tremolo,         // 0..255 amplitude modulation
    output reg  signed [15:0] sample,
    output reg                active,
    output reg  [5:0]         voice_count,
    output reg                note_on,
    output reg  [4:0]         note_on_index,
    output reg  [15:0]        latency_frames
);

    // ------------------------------------------------------------------
    // Per-voice state (independent for every one of the 32 voices)
    // ------------------------------------------------------------------
    reg [31:0] phase        [0:31];
    reg [15:0] env_level    [0:31];
    reg [15:0] env_counter  [0:31];
    reg [2:0]  env_state    [0:31];
    reg [7:0]  env_velocity [0:31];
    reg [1:0]  env_timbre   [0:31];

    reg [31:0] gate_prev_mask;
    reg [31:0] gate_last;
    reg [31:0] gate_frame;
    reg [31:0] lfo_phase;
    reg signed [15:0] lowpass;
    reg [4:0]  voice_index;
    reg [1:0]  harmonic;
    reg [2:0]  state;
    reg [31:0] phase_now;
    reg [31:0] phase_next;
    reg [31:0] increment_now;
    reg [31:0] lookup_phase;
    reg [15:0] level_now;
    reg [15:0] counter_now;
    reg [2:0]  estate_now;
    reg [7:0]  velocity_now;
    reg [1:0]  timbre_now;
    reg        gate_now;
    reg        gate_previous;
    reg signed [25:0] harmonic_sum;
    reg signed [23:0] mix_sum;
    reg signed [15:0] lfo_value;
    reg [15:0] latency_count;
    reg        latency_pending;

    localparam S_IDLE = 3'd0;
    localparam S_LOAD = 3'd1;
    localparam S_ENV  = 3'd2;
    localparam S_LOOK = 3'd3;
    localparam S_HARM = 3'd4;
    localparam S_COMB = 3'd5;
    localparam S_FIN  = 3'd6;

    // ------------------------------------------------------------------
    // Frequency table: equal temperament, C3 (MIDI 48) .. G5 (MIDI 79)
    // increment = f / 46875 * 2^32
    // ------------------------------------------------------------------
    function [31:0] note_increment;
        input [4:0] n;
        begin
            case(n)
                5'd0 : note_increment = 32'd11985848; // C3  130.81 Hz
                5'd1 : note_increment = 32'd12698564; // C#3 138.59 Hz
                5'd2 : note_increment = 32'd13453659; // D3  146.83 Hz
                5'd3 : note_increment = 32'd14253656; // D#3 155.56 Hz
                5'd4 : note_increment = 32'd15101222; // E3  164.81 Hz
                5'd5 : note_increment = 32'd15999188; // F3  174.61 Hz
                5'd6 : note_increment = 32'd16950549; // F#3 185.00 Hz
                5'd7 : note_increment = 32'd17958481; // G3  196.00 Hz
                5'd8 : note_increment = 32'd19026348; // G#3 207.65 Hz
                5'd9 : note_increment = 32'd20157713; // A3  220.00 Hz
                5'd10: note_increment = 32'd21356353; // A#3 233.08 Hz
                5'd11: note_increment = 32'd22626268; // B3  246.94 Hz
                5'd12: note_increment = 32'd23971696; // C4  261.63 Hz
                5'd13: note_increment = 32'd25397127; // C#4 277.18 Hz
                5'd14: note_increment = 32'd26907319; // D4  293.66 Hz
                5'd15: note_increment = 32'd28507311; // D#4 311.13 Hz
                5'd16: note_increment = 32'd30202444; // E4  329.63 Hz
                5'd17: note_increment = 32'd31998375; // F4  349.23 Hz
                5'd18: note_increment = 32'd33901097; // F#4 369.99 Hz
                5'd19: note_increment = 32'd35916962; // G4  392.00 Hz
                5'd20: note_increment = 32'd38052695; // G#4 415.30 Hz
                5'd21: note_increment = 32'd40315426; // A4  440.00 Hz
                5'd22: note_increment = 32'd42712706; // A#4 466.16 Hz
                5'd23: note_increment = 32'd45252536; // B4  493.88 Hz
                5'd24: note_increment = 32'd47943392; // C5  523.25 Hz
                5'd25: note_increment = 32'd50794254; // C#5 554.37 Hz
                5'd26: note_increment = 32'd53814638; // D5  587.33 Hz
                5'd27: note_increment = 32'd57014623; // D#5 622.25 Hz
                5'd28: note_increment = 32'd60404889; // E5  659.26 Hz
                5'd29: note_increment = 32'd63996750; // F5  698.46 Hz
                5'd30: note_increment = 32'd67802195; // F#5 739.99 Hz
                default: note_increment = 32'd71833923; // G5 783.99 Hz
            endcase
        end
    endfunction

    function [15:0] attack_step;
        input [1:0] t;
        begin
            case(t)
                2'd0: attack_step = 16'd1024;
                2'd1: attack_step = 16'd4096;
                2'd2: attack_step = 16'd48;
                default: attack_step = 16'd4096;
            endcase
        end
    endfunction

    function [15:0] decay_ticks;
        input [1:0] t;
        begin
            case(t)
                2'd0: decay_ticks = 16'd2;
                2'd1: decay_ticks = 16'd1;
                2'd2: decay_ticks = 16'd8;
                default: decay_ticks = 16'd4;
            endcase
        end
    endfunction

    function [15:0] sustain_level;
        input [1:0] t;
        begin
            case(t)
                2'd0: sustain_level = 16'd9000;
                2'd1: sustain_level = 16'd60000;
                2'd2: sustain_level = 16'd50000;
                default: sustain_level = 16'd18000;
            endcase
        end
    endfunction

    function [15:0] release_step;
        input [1:0] t;
        begin
            case(t)
                2'd0: release_step = 16'd8;  // ~175 ms
                2'd1: release_step = 16'd6;  // ~233 ms
                2'd2: release_step = 16'd4;  // ~350 ms
                default: release_step = 16'd8;
            endcase
        end
    endfunction

    function [7:0] harmonic_weight;
        input [1:0] t;
        input [1:0] h;
        input [7:0] v;
        begin
            case(t)
                2'd0: harmonic_weight = h == 2'd0 ? 8'd128 :
                                        h == 2'd1 ? (8'd24 + (v >> 2)) : 8'd8;
                2'd1: harmonic_weight = h == 2'd0 ? 8'd96 :
                                        h == 2'd1 ? 8'd100 : 8'd56;
                2'd2: harmonic_weight = h == 2'd0 ? 8'd112 :
                                        h == 2'd1 ? 8'd56 : 8'd36;
                default: harmonic_weight = h == 2'd0 ? 8'd176 : h == 2'd1 ? 8'd16 : 8'd0;
            endcase
        end
    endfunction

    function signed [7:0] lfo_sine;
        input [5:0] n;
        begin case(n)
                6'd0: lfo_sine = 8'sd0;
                6'd1: lfo_sine = 8'sd12;
                6'd2: lfo_sine = 8'sd25;
                6'd3: lfo_sine = 8'sd37;
                6'd4: lfo_sine = 8'sd49;
                6'd5: lfo_sine = 8'sd60;
                6'd6: lfo_sine = 8'sd71;
                6'd7: lfo_sine = 8'sd81;
                6'd8: lfo_sine = 8'sd90;
                6'd9: lfo_sine = 8'sd98;
                6'd10: lfo_sine = 8'sd106;
                6'd11: lfo_sine = 8'sd112;
                6'd12: lfo_sine = 8'sd117;
                6'd13: lfo_sine = 8'sd122;
                6'd14: lfo_sine = 8'sd125;
                6'd15: lfo_sine = 8'sd126;
                6'd16: lfo_sine = 8'sd127;
                6'd17: lfo_sine = 8'sd126;
                6'd18: lfo_sine = 8'sd125;
                6'd19: lfo_sine = 8'sd122;
                6'd20: lfo_sine = 8'sd117;
                6'd21: lfo_sine = 8'sd112;
                6'd22: lfo_sine = 8'sd106;
                6'd23: lfo_sine = 8'sd98;
                6'd24: lfo_sine = 8'sd90;
                6'd25: lfo_sine = 8'sd81;
                6'd26: lfo_sine = 8'sd71;
                6'd27: lfo_sine = 8'sd60;
                6'd28: lfo_sine = 8'sd49;
                6'd29: lfo_sine = 8'sd37;
                6'd30: lfo_sine = 8'sd25;
                6'd31: lfo_sine = 8'sd12;
                6'd32: lfo_sine = 8'sd0;
                6'd33: lfo_sine = -8'sd12;
                6'd34: lfo_sine = -8'sd25;
                6'd35: lfo_sine = -8'sd37;
                6'd36: lfo_sine = -8'sd49;
                6'd37: lfo_sine = -8'sd60;
                6'd38: lfo_sine = -8'sd71;
                6'd39: lfo_sine = -8'sd81;
                6'd40: lfo_sine = -8'sd90;
                6'd41: lfo_sine = -8'sd98;
                6'd42: lfo_sine = -8'sd106;
                6'd43: lfo_sine = -8'sd112;
                6'd44: lfo_sine = -8'sd117;
                6'd45: lfo_sine = -8'sd122;
                6'd46: lfo_sine = -8'sd125;
                6'd47: lfo_sine = -8'sd126;
                6'd48: lfo_sine = -8'sd127;
                6'd49: lfo_sine = -8'sd126;
                6'd50: lfo_sine = -8'sd125;
                6'd51: lfo_sine = -8'sd122;
                6'd52: lfo_sine = -8'sd117;
                6'd53: lfo_sine = -8'sd112;
                6'd54: lfo_sine = -8'sd106;
                6'd55: lfo_sine = -8'sd98;
                6'd56: lfo_sine = -8'sd90;
                6'd57: lfo_sine = -8'sd81;
                6'd58: lfo_sine = -8'sd71;
                6'd59: lfo_sine = -8'sd60;
                6'd60: lfo_sine = -8'sd49;
                6'd61: lfo_sine = -8'sd37;
                6'd62: lfo_sine = -8'sd25;
                6'd63: lfo_sine = -8'sd12;
        endcase end
    endfunction

    function [5:0] count_ones;
        input [31:0] v;
        integer i;
        begin
            count_ones = 6'd0;
            for(i = 0; i < 32; i = i + 1)
                count_ones = count_ones + {5'd0, v[i]};
        end
    endfunction

    function [31:0] phase_seed;
        input [4:0] n;
        begin
            phase_seed = n * 32'h9E3779B9;
        end
    endfunction

    wire signed [15:0] sine_wave;
    wave_source sine_rom(.phase(lookup_phase), .timbre(2'd1), .sample(sine_wave));

    wire signed [15:0] bend_ext = {{2{bend[13]}}, bend};
    wire signed [31:0] bend_product = bend_ext * 16'sd8600;
    wire signed [31:0] bend_offset = bend_product >>> 13;
    wire signed [15:0] vibrato_product = lfo_value * $signed({1'b0, vibrato});
    wire signed [31:0] vibrato_offset = vibrato_product >>> 4;
    wire signed [31:0] ratio_signed = 32'sd65536 + bend_offset + vibrato_offset;
    wire [16:0] ratio = ratio_signed < 32'sd40000 ? 17'd40000 :
                       ratio_signed > 32'sd90000 ? 17'd90000 : ratio_signed[16:0];

    wire [48:0] increment_product = note_increment(voice_index) * ratio;
    wire [31:0] increment_final = increment_product[47:16];

    // Band-limited additive partials only: no discontinuous saw/square extras.
    wire signed [17:0] wave_extra = 18'sd0;
    wire signed [17:0] harmonic_scaled = $signed(harmonic_sum[25:8]);
    wire signed [17:0] wave_wide = harmonic_scaled + wave_extra;
    wire signed [15:0] wave_value =
        wave_wide > 18'sd32767 ? 16'sd32767 :
        wave_wide < -18'sd32768 ? -16'sd32768 : wave_wide[15:0];

    wire [23:0] gain_product = level_now * {8'd0, velocity_now};
    wire [15:0] gain_value = gain_product[23:8];
    wire signed [31:0] voice_product = wave_value * $signed({1'b0, gain_value});
    wire signed [15:0] voice_sample = voice_product >>> 15;

    // Fixed 4x headroom.  A per-voice-count variable shift caused audible
    // gain steps/pops whenever a note or release tail crossed a boundary.
    wire signed [23:0] mix_now = mix_sum >>> 2;
    wire signed [15:0] mix_sat =
        mix_now > 24'sd32767 ? 16'sd32767 :
        mix_now < -24'sd32768 ? -16'sd32768 : mix_now[15:0];
    wire signed [17:0] lowpass_delta = $signed({{2{mix_sat[15]}}, mix_sat}) -
                                        $signed({{2{lowpass[15]}}, lowpass});
    wire [7:0] filter_alpha = brightness > 8'd247 ? 8'd255 : brightness + 8'd8;
    wire signed [25:0] lowpass_product = lowpass_delta * $signed({1'b0, filter_alpha});
    wire signed [25:0] lowpass_sum = $signed({{10{lowpass[15]}}, lowpass}) + (lowpass_product >>> 8);
    wire signed [15:0] lowpass_next =
        lowpass_sum > 26'sd32767 ? 16'sd32767 :
        lowpass_sum < -26'sd32768 ? -16'sd32768 : lowpass_sum[15:0];
    wire signed [16:0] tremolo_depth = 17'sd128 - $signed({{9{lfo_value[15]}}, lfo_value});
    wire [17:0] tremolo_product_raw = {1'b0, tremolo} * tremolo_depth[8:0];
    wire [8:0] tremolo_gain = 9'd256 - tremolo_product_raw[15:8];
    wire signed [24:0] tremolo_product = $signed({{9{lowpass_next[15]}}, lowpass_next}) *
                                          $signed({1'b0, tremolo_gain});
    wire signed [15:0] tremolo_sample = tremolo_product >>> 8;
    wire signed [23:0] expression_product = $signed({{8{tremolo_sample[15]}}, tremolo_sample}) *
                                            $signed({1'b0, expression});
    wire signed [15:0] expression_sample = expression_product >>> 8;

    integer k;
    always @(posedge clk) begin
        if(!reset_n) begin
            state <= S_IDLE;
            voice_index <= 0;
            harmonic <= 0;
            phase_now <= 0;
            phase_next <= 0;
            increment_now <= 0;
            lookup_phase <= 0;
            level_now <= 0;
            counter_now <= 0;
            estate_now <= 0;
            velocity_now <= 0;
            timbre_now <= 0;
            gate_now <= 0;
            gate_previous <= 0;
            harmonic_sum <= 0;
            mix_sum <= 0;
            lfo_value <= 0;
            lfo_phase <= 0;
            sample <= 0;
            active <= 0;
            voice_count <= 0;
            note_on <= 0;
            note_on_index <= 0;
            latency_frames <= 0;
            latency_count <= 0;
            latency_pending <= 0;
            gate_prev_mask <= 0;
            gate_last <= 0;
            gate_frame <= 0;
            lowpass <= 0;
            for(k = 0; k < 32; k = k + 1) begin
                phase[k] <= 0;
                env_level[k] <= 0;
                env_counter[k] <= 0;
                env_state[k] <= 0;
                env_velocity[k] <= 0;
                env_timbre[k] <= 0;
            end
        end else begin
            if(frame_tick && state == S_IDLE) begin
                gate_frame <= gate_mask;
                gate_last <= gate_prev_mask;
                gate_prev_mask <= gate_mask;
                lfo_value <= lfo_sine(lfo_phase[31:26]);
                lfo_phase <= lfo_phase + 32'd458130; // 5.0 Hz at 46.875 kHz
                voice_count <= count_ones(gate_mask);
                note_on <= |(gate_mask & ~gate_prev_mask);
                note_on_index <= gate_mask[31] ? 5'd31 : gate_mask[30] ? 5'd30 :
                                 gate_mask[29] ? 5'd29 : gate_mask[28] ? 5'd28 :
                                 gate_mask[27] ? 5'd27 : gate_mask[26] ? 5'd26 :
                                 gate_mask[25] ? 5'd25 : gate_mask[24] ? 5'd24 :
                                 gate_mask[23] ? 5'd23 : gate_mask[22] ? 5'd22 :
                                 gate_mask[21] ? 5'd21 : gate_mask[20] ? 5'd20 :
                                 gate_mask[19] ? 5'd19 : gate_mask[18] ? 5'd18 :
                                 gate_mask[17] ? 5'd17 : gate_mask[16] ? 5'd16 :
                                 gate_mask[15] ? 5'd15 : gate_mask[14] ? 5'd14 :
                                 gate_mask[13] ? 5'd13 : gate_mask[12] ? 5'd12 :
                                 gate_mask[11] ? 5'd11 : gate_mask[10] ? 5'd10 :
                                 gate_mask[9]  ? 5'd9  : gate_mask[8]  ? 5'd8  :
                                 gate_mask[7]  ? 5'd7  : gate_mask[6]  ? 5'd6  :
                                 gate_mask[5]  ? 5'd5  : gate_mask[4]  ? 5'd4  :
                                 gate_mask[3]  ? 5'd3  : gate_mask[2]  ? 5'd2  :
                                 gate_mask[1]  ? 5'd1  : 5'd0;
                if(|(gate_mask & ~gate_prev_mask)) begin
                    latency_pending <= 1'b1;
                    latency_count <= 0;
                end else if(latency_pending) begin
                    latency_count <= latency_count + 1'b1;
                end
                voice_index <= 0;
                mix_sum <= 0;
                    state <= S_LOAD;
            end

            case(state)
                S_IDLE: begin
                    // Frame boundary is handled by the frame_tick branch above.
                end

                S_LOAD: begin
                    phase_now <= phase[voice_index];
                    level_now <= env_level[voice_index];
                    counter_now <= env_counter[voice_index];
                    estate_now <= env_state[voice_index];
                    velocity_now <= env_velocity[voice_index];
                    timbre_now <= env_timbre[voice_index];
                    gate_now <= gate_frame[voice_index];
                    gate_previous <= gate_last[voice_index];
                    increment_now <= increment_final;
                    harmonic <= 0;
                    harmonic_sum <= 0;
                    state <= S_ENV;
                end

                S_ENV: begin
                    phase_next <= phase_now + increment_now;
                    if(gate_now && !gate_previous) begin
                        level_now <= attack_step(timbre);
                        estate_now <= 3'd1;
                        counter_now <= 0;
                        velocity_now <= velocity;
                        timbre_now <= timbre;
                    end else if(!gate_now && gate_previous) begin
                        estate_now <= 3'd4;
                        counter_now <= 0;
                    end else begin
                        case(estate_now)
                            3'd1: if(level_now >= (16'hffff - attack_step(timbre_now))) begin
                                      level_now <= 16'hffff;
                                      estate_now <= 3'd2;
                                      counter_now <= 0;
                                  end else level_now <= level_now + attack_step(timbre_now);
                            3'd2: if(level_now <= sustain_level(timbre_now)) begin
                                      level_now <= sustain_level(timbre_now);
                                      estate_now <= 3'd3;
                                      counter_now <= 0;
                                  end else if(counter_now >= (decay_ticks(timbre_now) - 1'b1)) begin
                                      counter_now <= 0;
                                      level_now <= level_now > sustain_level(timbre_now) + 16'd15 ? level_now - 16'd16 : sustain_level(timbre_now);
                                  end else counter_now <= counter_now + 1'b1;
                            3'd3: begin
                                      level_now <= sustain_level(timbre_now);
                                      counter_now <= 0;
                                  end
                            3'd4: if(level_now == 0) begin
                                      estate_now <= 3'd0;
                                      counter_now <= 0;
                                  end else if(level_now <= release_step(timbre_now)) begin
                                      level_now <= 0;
                                      estate_now <= 3'd0;
                                      counter_now <= 0;
                                  end else begin
                                      level_now <= level_now - release_step(timbre_now);
                                      counter_now <= 0;
                                  end
                            default: begin
                                      level_now <= 0;
                                      estate_now <= 3'd0;
                                      counter_now <= 0;
                                  end
                        endcase
                    end
                    state <= S_LOOK;
                end

                S_LOOK: begin
                    // Distinct bounded harmonic families: piano 1/2/3,
                    // organ 1/2/4, bowed strings 1/3/5, bass 1/2.
                    if(harmonic == 0) lookup_phase <= phase_next;
                    else if(timbre_now == 2'd2)
                        lookup_phase <= harmonic == 1 ? phase_next + (phase_next<<1) : phase_next + (phase_next<<2);
                    else if(timbre_now == 2'd1 && harmonic == 2)
                        lookup_phase <= phase_next << 2;
                    else lookup_phase <= harmonic == 1 ? phase_next<<1 : phase_next + (phase_next<<1);
                    state <= S_HARM;
                end

                S_HARM: begin
                    harmonic_sum <= harmonic_sum +
                        (sine_wave * $signed({1'b0, harmonic_weight(timbre_now, harmonic, velocity_now)}));
                    if(harmonic == 2'd2) state <= S_COMB;
                    else begin
                        harmonic <= harmonic + 1'b1;
                        state <= S_LOOK;
                    end
                end

                S_COMB: begin
                    if(gate_now && !gate_previous)
                        phase[voice_index] <= phase_seed(voice_index);
                    else
                        phase[voice_index] <= phase_next;
                    env_level[voice_index] <= level_now;
                    env_counter[voice_index] <= counter_now;
                    env_state[voice_index] <= estate_now;
                    env_velocity[voice_index] <= velocity_now;
                    env_timbre[voice_index] <= timbre_now;
                    mix_sum <= mix_sum + voice_sample;
                    if(voice_index == 5'd31) state <= S_FIN;
                    else begin
                        voice_index <= voice_index + 1'b1;
                        state <= S_LOAD;
                    end
                end

                S_FIN: begin
                    lowpass <= lowpass_next;
                    sample <= expression_sample;
                    active <= (gate_frame != 0) || (mix_sum != 0);
                    if(latency_pending) begin
                        latency_frames <= latency_count + 16'd1;
                        latency_pending <= 0;
                    end
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
