`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Real-time 16-band spectrum analyser.
//
// Sixteen fixed biquad band-pass filters (100 Hz .. 10 kHz, Q=2) are evaluated
// once per 46.875 kHz audio frame.  One multiplier is time-shared, so the whole
// bank costs four multiplies per band (64 per frame) and no block RAM.  The
// output is the smoothed logarithmic magnitude of each band, 0..255.
//
// This is a measurement of the actual post-mix audio, not a replay of a stored
// pattern.  The OLED currently refreshes at roughly 10 frames/s (100 kHz I2C),
// while the filter bank itself updates at the audio frame rate.
// -----------------------------------------------------------------------------
module spectrum16(
    input  wire               clk,
    input  wire               reset_n,
    input  wire               frame_tick,
    input  wire signed [15:0] sample,
    output reg  [127:0]       bands,        // 16 x 8 bit, band 0 in [7:0]
    output wire               busy
);

    localparam S_IDLE = 2'd0;
    localparam S_CALC = 2'd1;
    localparam S_FIN  = 2'd2;

    reg [1:0] state;
    reg [3:0] band;
    reg [1:0] tap;
    reg signed [39:0] accumulator;
    reg signed [15:0] x_hold;
    reg signed [15:0] x1 [0:15];
    reg signed [15:0] x2 [0:15];
    reg signed [15:0] y1 [0:15];
    reg signed [15:0] y2 [0:15];
    reg [7:0] level [0:15];

    integer k;
    assign busy = state != S_IDLE;

    // Coefficients are Q14.  b1 is zero for a constant-skirt band-pass.
    function signed [17:0] coefficient;
        input [3:0] b;
        input [1:0] t;
        begin
            case({b, t})
                // band 0, 100 Hz
                {4'd0,2'd0}: coefficient = 18'sd55;
                {4'd0,2'd1}: coefficient = -18'sd55;
                {4'd0,2'd2}: coefficient = -18'sd32656;
                {4'd0,2'd3}: coefficient = 18'sd16275;
                // band 1, 136 Hz
                {4'd1,2'd0}: coefficient = 18'sd74;
                {4'd1,2'd1}: coefficient = -18'sd74;
                {4'd1,2'd2}: coefficient = -18'sd32614;
                {4'd1,2'd3}: coefficient = 18'sd16235;
                // band 2, 185 Hz
                {4'd2,2'd0}: coefficient = 18'sd101;
                {4'd2,2'd1}: coefficient = -18'sd101;
                {4'd2,2'd2}: coefficient = -18'sd32556;
                {4'd2,2'd3}: coefficient = 18'sd16182;
                // band 3, 251 Hz
                {4'd3,2'd0}: coefficient = 18'sd137;
                {4'd3,2'd1}: coefficient = -18'sd137;
                {4'd3,2'd2}: coefficient = -18'sd32476;
                {4'd3,2'd3}: coefficient = 18'sd16111;
                // band 4, 342 Hz
                {4'd4,2'd0}: coefficient = 18'sd185;
                {4'd4,2'd1}: coefficient = -18'sd185;
                {4'd4,2'd2}: coefficient = -18'sd32364;
                {4'd4,2'd3}: coefficient = 18'sd16013;
                // band 5, 464 Hz
                {4'd5,2'd0}: coefficient = 18'sd251;
                {4'd5,2'd1}: coefficient = -18'sd251;
                {4'd5,2'd2}: coefficient = -18'sd32204;
                {4'd5,2'd3}: coefficient = 18'sd15882;
                // band 6, 631 Hz
                {4'd6,2'd0}: coefficient = 18'sd339;
                {4'd6,2'd1}: coefficient = -18'sd339;
                {4'd6,2'd2}: coefficient = -18'sd31976;
                {4'd6,2'd3}: coefficient = 18'sd15706;
                // band 7, 858 Hz
                {4'd7,2'd0}: coefficient = 18'sd457;
                {4'd7,2'd1}: coefficient = -18'sd457;
                {4'd7,2'd2}: coefficient = -18'sd31644;
                {4'd7,2'd3}: coefficient = 18'sd15470;
                // band 8, 1166 Hz
                {4'd8,2'd0}: coefficient = 18'sd614;
                {4'd8,2'd1}: coefficient = -18'sd614;
                {4'd8,2'd2}: coefficient = -18'sd31156;
                {4'd8,2'd3}: coefficient = 18'sd15157;
                // band 9, 1585 Hz
                {4'd9,2'd0}: coefficient = 18'sd820;
                {4'd9,2'd1}: coefficient = -18'sd820;
                {4'd9,2'd2}: coefficient = -18'sd30427;
                {4'd9,2'd3}: coefficient = 18'sd14743;
                // band 10, 2154 Hz
                {4'd10,2'd0}: coefficient = 18'sd1089;
                {4'd10,2'd1}: coefficient = -18'sd1089;
                {4'd10,2'd2}: coefficient = -18'sd29323;
                {4'd10,2'd3}: coefficient = 18'sd14206;
                // band 11, 2929 Hz
                {4'd11,2'd0}: coefficient = 18'sd1430;
                {4'd11,2'd1}: coefficient = -18'sd1430;
                {4'd11,2'd2}: coefficient = -18'sd27633;
                {4'd11,2'd3}: coefficient = 18'sd13524;
                // band 12, 3981 Hz
                {4'd12,2'd0}: coefficient = 18'sd1848;
                {4'd12,2'd1}: coefficient = -18'sd1848;
                {4'd12,2'd2}: coefficient = -18'sd25029;
                {4'd12,2'd3}: coefficient = 18'sd12687;
                // band 13, 5412 Hz
                {4'd13,2'd0}: coefficient = 18'sd2331;
                {4'd13,2'd1}: coefficient = -18'sd2331;
                {4'd13,2'd2}: coefficient = -18'sd21030;
                {4'd13,2'd3}: coefficient = 18'sd11722;
                // band 14, 7356 Hz
                {4'd14,2'd0}: coefficient = 18'sd2826;
                {4'd14,2'd1}: coefficient = -18'sd2826;
                {4'd14,2'd2}: coefficient = -18'sd14967;
                {4'd14,2'd3}: coefficient = 18'sd10731;
                // band 15, 10000 Hz
                {4'd15,2'd0}: coefficient = 18'sd3207;
                {4'd15,2'd1}: coefficient = -18'sd3207;
                {4'd15,2'd2}: coefficient = -18'sd6018;
                default: coefficient = 18'sd9970;
            endcase
        end
    endfunction

    wire signed [17:0] coef = coefficient(band, tap);
    wire signed [15:0] source =
        tap == 2'd0 ? x_hold :
        tap == 2'd1 ? x2[band] :
        tap == 2'd2 ? y1[band] : y2[band];
    wire signed [33:0] product = coef * source;
    wire signed [39:0] combined =
        tap == 2'd0 ? {{6{product[33]}}, product} :
        tap == 2'd1 ? accumulator + {{6{product[33]}}, product} :
                      accumulator - {{6{product[33]}}, product};
    wire signed [39:0] filtered_full = combined >>> 14;
    wire signed [15:0] filtered_sat =
        filtered_full > 40'sd32767 ? 16'sd32767 :
        filtered_full < -40'sd32768 ? -16'sd32768 : filtered_full[15:0];
    wire signed [16:0] filtered_wide = $signed({{1{filtered_sat[15]}}, filtered_sat});
    wire [16:0] magnitude_wide = filtered_sat[15] ?
        (17'd0 - filtered_wide) : filtered_wide[16:0];
    wire [7:0] magnitude = magnitude_wide[16] ? 8'd255 : magnitude_wide[15:7];

    always @(posedge clk) begin
        if(!reset_n) begin
            state <= S_IDLE;
            band <= 0;
            tap <= 0;
            accumulator <= 0;
            x_hold <= 0;
            bands <= 0;
            for(k = 0; k < 16; k = k + 1) begin
                x1[k] <= 0;
                x2[k] <= 0;
                y1[k] <= 0;
                y2[k] <= 0;
                level[k] <= 0;
            end
        end else begin
            case(state)
                S_IDLE: if(frame_tick) begin
                    x_hold <= sample;
                    band <= 0;
                    tap <= 0;
                    accumulator <= 0;
                    state <= S_CALC;
                end

                S_CALC: begin
                    accumulator <= combined;
                    if(tap != 2'd3) begin
                        tap <= tap + 1'b1;
                    end else begin
                        x2[band] <= x1[band];
                        x1[band] <= x_hold;
                        y2[band] <= y1[band];
                        y1[band] <= filtered_sat;
                        if(magnitude > level[band])
                            level[band] <= level[band] + ((magnitude - level[band]) >> 1);
                        else
                            level[band] <= level[band] - ((level[band] - magnitude) >> 3);
                        bands[band*8 +: 8] <= magnitude > level[band] ?
                            ((level[band] + ((magnitude - level[band]) >> 1)) > 255 ?
                             8'd255 : level[band] + ((magnitude - level[band]) >> 1)) : magnitude;
                        if(band == 4'd15) state <= S_FIN;
                        else begin
                            band <= band + 1'b1;
                            tap <= 0;
                        end
                    end
                end

                S_FIN: state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
