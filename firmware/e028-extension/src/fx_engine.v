`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Stereo effects chain inside the FPGA:
//   chorus  : 320..447 sample modulated delay (6.8..9.5 ms)
//   delay   : 2047 sample (43.7 ms) feedback echo
//   reverb  : 2-line feedback delay network (31.9 ms / 40.0 ms) preceded by two
//             Schroeder all-pass diffusers (4.8 ms / 9.4 ms)
//
// All delay memories are synchronous block RAM.  A frame needs six read
// addresses, one calculation cycle and one write cycle, so the effect never
// touches the dry path timing.  When all effects are off the block RAMs are not
// addressed at all.
// -----------------------------------------------------------------------------
module fx_engine(
    input  wire               clk,
    input  wire               reset_n,
    input  wire               frame_tick,
    input  wire signed [15:0] dry,
    input  wire [2:0]         enable,       // {reverb, delay, chorus}
    output reg signed [15:0]  sample_l,
    output reg signed [15:0]  sample_r
);

    localparam S_IDLE  = 2'd0;
    localparam S_READ  = 2'd1;
    localparam S_CALC  = 2'd2;
    localparam S_WRITE = 2'd3;

    reg [1:0] state;
    reg signed [15:0] dry_hold;

    reg signed [15:0] chorus_ram [0:1023];
    reg signed [15:0] delay_ram  [0:2047];
    reg signed [15:0] rev1_ram   [0:2047];
    reg signed [15:0] rev2_ram   [0:2047];
    reg signed [15:0] ap1_ram    [0:255];
    reg signed [15:0] ap2_ram    [0:511];

    reg [9:0]  chorus_wr;
    reg [10:0] delay_wr, rev1_wr, rev2_wr;
    reg [7:0]  ap1_wr;
    reg [8:0]  ap2_wr;
    reg [31:0] chorus_lfo;

    reg [9:0]  chorus_addr;
    reg [10:0] delay_addr, rev1_addr, rev2_addr;
    reg [7:0]  ap1_addr;
    reg [8:0]  ap2_addr;

    reg signed [15:0] chorus_q, delay_q, rev1_q, rev2_q, ap1_q, ap2_q;
    reg signed [15:0] delay_write, rev1_write, rev2_write, ap1_write, ap2_write;
    reg signed [15:0] out_l, out_r;

    wire [7:0] chorus_tri = chorus_lfo[31] ? ~chorus_lfo[30:23] : chorus_lfo[30:23];
    wire [9:0] chorus_delay = 10'd320 + {2'd0, chorus_tri[7:1]};

    function signed [15:0] sat16;
        input signed [17:0] v;
        begin
            sat16 = v > 18'sd32767 ? 16'sd32767 :
                    v < -18'sd32768 ? -16'sd32768 : v[15:0];
        end
    endfunction

    // 18-bit working values for the all-pass / FDN arithmetic
    wire signed [17:0] dry18 = $signed({{2{dry_hold[15]}}, dry_hold});
    wire signed [17:0] ap1_v = dry18 - ($signed({{2{ap1_q[15]}}, ap1_q}) >>> 1);
    wire signed [17:0] ap1_y = $signed({{2{ap1_q[15]}}, ap1_q}) + (ap1_v >>> 1);
    wire signed [17:0] ap2_v = ap1_y - ($signed({{2{ap2_q[15]}}, ap2_q}) >>> 1);
    wire signed [17:0] ap2_y = $signed({{2{ap2_q[15]}}, ap2_q}) + (ap2_v >>> 1);

    wire signed [17:0] rev1_18 = $signed({{2{rev1_q[15]}}, rev1_q});
    wire signed [17:0] rev2_18 = $signed({{2{rev2_q[15]}}, rev2_q});
    wire signed [17:0] inject = ap2_y >>> 1;
    wire signed [17:0] rev1_next = inject + (rev2_18 >>> 1);
    wire signed [17:0] rev2_next = inject - (rev1_18 >>> 1);
    wire signed [17:0] reverb_out = (rev1_18 + rev2_18) >>> 2;

    wire signed [17:0] delay_next = dry18 + (({{2{delay_q[15]}}, delay_q} * 18'sd3) >>> 3);

    wire signed [17:0] chorus_wet = enable[0] ? ($signed({{2{chorus_q[15]}}, chorus_q}) >>> 3) : 18'sd0;
    wire signed [17:0] delay_wet  = enable[1] ? ($signed({{2{delay_q[15]}}, delay_q}) >>> 3) : 18'sd0;
    wire signed [17:0] delay_wet_r= enable[1] ? ($signed({{2{delay_q[15]}}, delay_q}) >>> 2) : 18'sd0;
    wire signed [17:0] reverb_wet = enable[2] ? (reverb_out >>> 3) : 18'sd0;
    wire signed [17:0] mix_l = (dry18 >>> 1) + chorus_wet + delay_wet + reverb_wet;
    wire signed [17:0] mix_r = (dry18 >>> 1) + chorus_wet + delay_wet_r + reverb_wet;

    always @(posedge clk) begin
        if(!reset_n) begin
            state <= S_IDLE;
            dry_hold <= 0;
            chorus_wr <= 0;
            delay_wr <= 0;
            rev1_wr <= 0;
            rev2_wr <= 0;
            ap1_wr <= 0;
            ap2_wr <= 0;
            chorus_lfo <= 0;
            chorus_addr <= 0;
            delay_addr <= 0;
            rev1_addr <= 0;
            rev2_addr <= 0;
            ap1_addr <= 0;
            ap2_addr <= 0;
            chorus_q <= 0;
            delay_q <= 0;
            rev1_q <= 0;
            rev2_q <= 0;
            ap1_q <= 0;
            ap2_q <= 0;
            delay_write <= 0;
            rev1_write <= 0;
            rev2_write <= 0;
            ap1_write <= 0;
            ap2_write <= 0;
            sample_l <= 0;
            sample_r <= 0;
        end else begin
            case(state)
                S_IDLE: begin
                    if(frame_tick) begin
                        dry_hold <= dry;
                        chorus_lfo <= chorus_lfo + 32'd45813; // 0.5 Hz
                        if(enable != 0) begin
                            chorus_addr <= chorus_wr - chorus_delay;
                            delay_addr  <= delay_wr + 11'd1;
                            rev1_addr   <= rev1_wr - 11'd1497;
                            rev2_addr   <= rev2_wr - 11'd1877;
                            ap1_addr    <= ap1_wr - 8'd225;
                            ap2_addr    <= ap2_wr - 9'd441;
                            state <= S_READ;
                        end else begin
                            sample_l <= dry;
                            sample_r <= dry;
                        end
                    end
                end

                S_READ: begin
                    chorus_q <= chorus_ram[chorus_addr];
                    delay_q  <= delay_ram[delay_addr];
                    rev1_q   <= rev1_ram[rev1_addr];
                    rev2_q   <= rev2_ram[rev2_addr];
                    ap1_q    <= ap1_ram[ap1_addr];
                    ap2_q    <= ap2_ram[ap2_addr];
                    state <= S_CALC;
                end

                S_CALC: begin
                    delay_write <= sat16(delay_next);
                    rev1_write  <= sat16(rev1_next);
                    rev2_write  <= sat16(rev2_next);
                    ap1_write   <= sat16(ap1_v);
                    ap2_write   <= sat16(ap2_v);
                    out_l <= (enable != 0) ? sat16(mix_l) : dry_hold;
                    out_r <= (enable != 0) ? sat16(mix_r) : dry_hold;
                    state <= S_WRITE;
                end

                S_WRITE: begin
                    chorus_ram[chorus_wr] <= dry_hold;
                    delay_ram[delay_wr]   <= delay_write;
                    rev1_ram[rev1_wr]     <= rev1_write;
                    rev2_ram[rev2_wr]     <= rev2_write;
                    ap1_ram[ap1_wr]       <= ap1_write;
                    ap2_ram[ap2_wr]       <= ap2_write;
                    chorus_wr <= chorus_wr + 1'b1;
                    delay_wr  <= delay_wr + 1'b1;
                    rev1_wr   <= rev1_wr + 1'b1;
                    rev2_wr   <= rev2_wr + 1'b1;
                    ap1_wr    <= ap1_wr + 1'b1;
                    ap2_wr    <= ap2_wr + 1'b1;
                    sample_l <= out_l;
                    sample_r <= out_r;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
