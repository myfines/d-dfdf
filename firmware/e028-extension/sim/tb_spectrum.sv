`timescale 1ns/1ps
module tb_spectrum;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg signed [15:0] sample = 0;
    wire [127:0] bands;
    wire busy;
    integer cycle = 0, frame = 0;
    integer i, best, best_idx;
    real t;

    spectrum16 dut(.clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
                   .sample(sample), .bands(bands), .busy(busy));

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin
            cycle <= 0; frame_tick <= 1; frame <= frame + 1;
            t = frame / 46875.0;
            sample <= $rtoi(20000.0 * $sin(2.0 * 3.141592653589793 * 1000.0 * t));
        end else frame_tick <= 0;
    end

    initial begin
        repeat(4) @(posedge clk);
        reset_n = 1;
        repeat(576*600) @(posedge clk);
        for(i=0;i<16;i=i+1)
            $display("band %0d = %0d", i, bands[i*8 +: 8]);
        if(bands[7*8 +: 8] < 60 && bands[8*8 +: 8] < 60)
            $fatal(1, "1 kHz did not excite bands 7/8: %0d/%0d",
                   bands[7*8 +: 8], bands[8*8 +: 8]);
        if(bands[0] > 60) $fatal(1, "low band leaked: %0d", bands[0]);
        best = bands[7*8 +: 8] > bands[8*8 +: 8] ? bands[7*8 +: 8] : bands[8*8 +: 8];
        best_idx = bands[7*8 +: 8] > bands[8*8 +: 8] ? 7 : 8;
        $display("PASS spectrum peak_band=%0d level=%0d", best_idx, best);
        $finish;
    end

    initial begin
        #30000000;
        $fatal(1, "timeout");
    end
endmodule
