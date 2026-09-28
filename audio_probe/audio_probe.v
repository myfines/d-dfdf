// Low-level SRAM-only headset check for Tang Primer 20K Dock.
// Output is a full-scale 440 Hz triangle tone for one second, then one second
// of silence. The PT8211 uses 16-bit MSB-first LSBJ serial audio.
// LED2 is driven as a heartbeat so a configured board is visibly alive.
module audio_probe #(
    parameter integer ENABLE_DELAY_FRAMES = 1024,
    parameter integer GATE_HALF_FRAMES = 46875,
    parameter integer FADE_FRAMES = 256,
    parameter integer LED_TOGGLE_BIT = 23
) (
    input wire clk,
    input wire rst_n,
    output wire HP_BCK,
    output reg HP_WS,
    output reg HP_DIN,
    output reg PA_EN,
    output reg LED2
);
    // Full scale: the triangle peaks exactly at PEAK, so nothing clips.
    localparam signed [15:0] PEAK = 16'sd32767;

    reg [3:0] half_bit_div;
    reg bck;
    reg [4:0] bit_number;
    reg [16:0] gate_frames;
    reg [15:0] amp_frames;
    reg [31:0] phase;
    reg signed [15:0] frame_sample;
    reg signed [15:0] wave_sample;
    reg [LED_TOGGLE_BIT:0] led_div;

    // One quadrant of the phase word spans the full triangle amplitude.
    wire [14:0] ramp = phase[29:15];
    wire signed [15:0] ramp_signed = $signed({1'b0, ramp});

    // Trapezoidal gate: the short fades remove the click that a hard on/off
    // gate would produce at full volume. env = 0..256, i.e. gain 0..1.
    wire [8:0] fade_rise =
        (gate_frames < FADE_FRAMES) ? gate_frames[8:0] : 9'd256;
    wire [16:0] gate_left = GATE_HALF_FRAMES - gate_frames;
    wire [8:0] fade_fall =
        (gate_frames >= GATE_HALF_FRAMES) ? 9'd0 :
        ((gate_left < FADE_FRAMES) ? gate_left[8:0] : 9'd256);
    wire [8:0] env = (fade_rise < fade_fall) ? fade_rise : fade_fall;

    wire signed [31:0] shaped = wave_sample * $signed({1'b0, env});
    wire signed [15:0] next_sample = shaped >>> 8; // divide by FADE_FRAMES (256)

    // 27 MHz / (2 * 9) = 1.5 MHz BCK;
    // 1.5 MHz / (2 * 16) = 46,875 stereo frames per second. The Sipeed
    // PT8211 example uses the same 1.5 MHz bit clock.
    assign HP_BCK = bck;

    always @* begin
        case (phase[31:30])
            2'b00: wave_sample = ramp_signed;
            2'b01: wave_sample = PEAK - ramp_signed;
            2'b10: wave_sample = -ramp_signed;
            default: wave_sample = -PEAK + ramp_signed;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            half_bit_div <= 4'd0;
            bck <= 1'b0;
            bit_number <= 5'd0;
            gate_frames <= 17'd0;
            amp_frames <= 16'd0;
            phase <= 32'd0;
            frame_sample <= 16'sd0;
            HP_WS <= 1'b0;
            HP_DIN <= 1'b0;
            PA_EN <= 1'b0;
            led_div <= {LED_TOGGLE_BIT + 1{1'b0}};
            LED2 <= 1'b0;
        end else begin
            // Heartbeat: LED2 changes state about every 0.31 s at 27 MHz.
            led_div <= led_div + 1'b1;
            LED2 <= led_div[LED_TOGGLE_BIT];

            if (half_bit_div == 4'd8) begin
                half_bit_div <= 4'd0;
                bck <= ~bck;
                if (bck) begin // Falling BCK: prepare data before DAC's rising edge.
                    HP_WS <= bit_number[4];
                    bit_number <= bit_number + 5'd1;
                    if (bit_number == 5'd0) begin
                        frame_sample <= next_sample;
                        HP_DIN <= next_sample[15];
                        phase <= phase + 32'd40315426; // 440 Hz at 46,875 samples/s
                        if (gate_frames == 2 * GATE_HALF_FRAMES - 1)
                            gate_frames <= 17'd0;
                        else
                            gate_frames <= gate_frames + 17'd1;
                        if (amp_frames < ENABLE_DELAY_FRAMES)
                            amp_frames <= amp_frames + 16'd1;
                        else
                            PA_EN <= 1'b1;
                    end else begin
                        HP_DIN <= frame_sample[15 - bit_number[3:0]];
                    end
                end
            end else begin
                half_bit_div <= half_bit_div + 4'd1;
            end
        end
    end
endmodule
