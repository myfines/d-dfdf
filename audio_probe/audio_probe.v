// Low-level SRAM-only headset check for Tang Primer 20K Dock.
// Output is a quiet 440 Hz triangle tone for one second, then one second
// of silence. The PT8211 uses 16-bit MSB-first LSBJ serial audio.
module audio_probe #(
    parameter integer ENABLE_DELAY_FRAMES = 1024,
    parameter integer GATE_HALF_FRAMES = 46875
) (
    input wire clk,
    input wire rst_n,
    output wire HP_BCK,
    output reg HP_WS,
    output reg HP_DIN,
    output reg PA_EN
);
    reg [3:0] half_bit_div;
    reg bck;
    reg [4:0] bit_number;
    reg [16:0] gate_frames;
    reg [15:0] amp_frames;
    reg [31:0] phase;
    reg signed [15:0] frame_sample;
    reg signed [15:0] wave_sample;
    wire [8:0] ramp = {phase[29:22], 1'b0};
    wire signed [15:0] ramp_signed = $signed({7'b0, ramp});
    wire signed [15:0] next_sample =
        (gate_frames < GATE_HALF_FRAMES) ? wave_sample : 16'sd0;

    // 27 MHz / (2 * 9) = 1.5 MHz BCK;
    // 1.5 MHz / (2 * 16) = 46,875 stereo frames per second.
    assign HP_BCK = bck;

    always @* begin
        case (phase[31:30])
            2'b00: wave_sample = ramp_signed;
            2'b01: wave_sample = 16'sd512 - ramp_signed;
            2'b10: wave_sample = -ramp_signed;
            default: wave_sample = -16'sd512 + ramp_signed;
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
        end else if (half_bit_div == 4'd8) begin
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
endmodule
