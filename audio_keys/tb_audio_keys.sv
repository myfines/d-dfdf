`timescale 1ns/1ps

// Checks the four-key tone:
//   - idle is silent and the headphone amplifier is off
//   - a key press starts the correct pitch within a couple of milliseconds
//   - contact bounce while a key is held must not cut the note
//   - release fades out and disables the amplifier again
// The serial stream is decoded against HP_WS so the 16-bit halves are framed
// exactly, never offset by a bit.
module tb_audio_keys;
    reg clk = 0;
    reg [3:0] btn_n = 4'b1111;
    wire HP_BCK, HP_WS, HP_DIN, PA_EN, LED_ALIVE, LED_KEY;

    always #18.519 clk = ~clk; // 27 MHz input clock

    audio_keys #(
        .RELEASE_FRAMES(235),
        .ATTACK_STEP(6),
        .LED_TOGGLE_BIT(23)
    ) dut (
        .clk(clk), .btn_n(btn_n),
        .HP_BCK(HP_BCK), .HP_WS(HP_WS), .HP_DIN(HP_DIN), .PA_EN(PA_EN),
        .LED_ALIVE(LED_ALIVE), .LED_KEY(LED_KEY)
    );

    integer bit_a = 0;
    integer bit_b = 0;
    reg [15:0] right_w = 0;
    reg [15:0] left_w = 0;
    integer frames = 0;
    integer nonzero_frames = 0;
    integer max_abs = 0;
    integer sample_s = 0;
    reg last_neg = 0;
    reg have_last = 0;
    reg measuring = 0;
    integer cross_n = 0;
    integer t_first = 0;
    integer t_last_cross = 0;
    integer half_ns = 0;

    always @(posedge HP_BCK) begin
        if (HP_WS === 1'b0) begin
            if (bit_a < 16) begin
                if (bit_a == 0) right_w = 16'd0;
                right_w = {right_w[14:0], HP_DIN};
                bit_a = bit_a + 1;
            end
        end else if (HP_WS === 1'b1) begin
            if (bit_b < 16) begin
                if (bit_b == 0) left_w = 16'd0;
                left_w = {left_w[14:0], HP_DIN};
                bit_b = bit_b + 1;
            end
        end

        if (bit_a == 16 && bit_b == 16) begin
            bit_a = 0;
            bit_b = 0;

            if (right_w !== left_w)
                $fatal(1, "right and left words differ: %h %h", right_w, left_w);

            sample_s = right_w[15] ? (right_w - 65536) : right_w;
            if (sample_s > 32767 || sample_s < -32768)
                $fatal(1, "sample out of 16-bit range: %0d", sample_s);
            if (sample_s != 0) nonzero_frames = nonzero_frames + 1;
            if (sample_s > max_abs) max_abs = sample_s;
            if (-sample_s > max_abs) max_abs = -sample_s;

            if (have_last && ((sample_s < 0) != last_neg)) begin
                if (measuring) begin
                    cross_n = cross_n + 1;
                    if (cross_n == 1) t_first = $realtime;
                    t_last_cross = $realtime;
                end
            end
            if (sample_s != 0) begin
                last_neg = (sample_s < 0);
                have_last = 1;
            end

            frames = frames + 1;
        end
    end

    initial begin
        #2500000; // outlast the 1.2 ms internal power-on reset

        // 1) idle: silent, amplifier off, key LED off
        nonzero_frames = 0; max_abs = 0; frames = 0;
        #1000000;
        if (nonzero_frames != 0)
            $fatal(1, "expected silence with no key, got %0d frames", nonzero_frames);
        if (PA_EN !== 1'b0) $fatal(1, "amplifier enabled while idle");
        if (LED_KEY !== 1'b0) $fatal(1, "key LED lit while idle");
        $display("idle: silent, amplifier off, %0d frames decoded", frames);

        // 2) press key 0: the tone must be up within a couple of milliseconds
        max_abs = 0;
        btn_n[0] = 1'b0;
        #2000000;
        if (LED_KEY !== 1'b1) $fatal(1, "key LED did not light for key 0");
        if (PA_EN !== 1'b1) $fatal(1, "amplifier did not enable for key 0");
        if (max_abs < 20000) $fatal(1, "note too quiet 2 ms after press, peak %0d", max_abs);

        // 3) pitch of key 0 -> C5 = 523.2511 Hz, half period 955.7 us
        measuring = 1; cross_n = 0; t_first = 0; t_last_cross = 0;
        #10000000;
        measuring = 0;
        if (cross_n < 8) $fatal(1, "too few zero crossings for key 0: %0d", cross_n);
        half_ns = (t_last_cross - t_first) / (cross_n - 1);
        if (half_ns < 927000 || half_ns > 985000)
            $fatal(1, "key 0 pitch wrong: half period %0d ns", half_ns);
        $display("key 0 (C5 523 Hz): half period %0d ns averaged over %0d crossings", half_ns, cross_n - 1);

        // 4) contact bounce while held must not cut the note
        btn_n[0] = 1'b1;
        #1000000;
        btn_n[0] = 1'b0;
        max_abs = 0;
        #2000000;
        if (LED_KEY !== 1'b1) $fatal(1, "1 ms release glitch cut the note");
        if (max_abs < 20000) $fatal(1, "note not restored after bounce, peak %0d", max_abs);
        $display("bounce: 1 ms release glitch did not cut the held note");

        // 5) release -> silence and amplifier off within the fade plus debounce
        btn_n[0] = 1'b1;
        #12000000;
        nonzero_frames = 0;
        #1000000;
        if (nonzero_frames != 0)
            $fatal(1, "sound continued after release: %0d frames", nonzero_frames);
        if (PA_EN !== 1'b0) $fatal(1, "amplifier stayed on after release");
        if (LED_KEY !== 1'b0) $fatal(1, "key LED stayed on after release");
        $display("release: silent again, amplifier off");

        // 6) key 3 -> G5 = 783.9909 Hz, half period 637.8 us
        max_abs = 0;
        btn_n[3] = 1'b0;
        #2000000;
        if (max_abs < 20000) $fatal(1, "note too quiet for key 3, peak %0d", max_abs);
        measuring = 1; cross_n = 0; t_first = 0; t_last_cross = 0;
        #10000000;
        measuring = 0;
        if (cross_n < 12) $fatal(1, "too few zero crossings for key 3: %0d", cross_n);
        half_ns = (t_last_cross - t_first) / (cross_n - 1);
        if (half_ns < 618000 || half_ns > 658000)
            $fatal(1, "key 3 pitch wrong: half period %0d ns", half_ns);
        $display("key 3 (G5 784 Hz): half period %0d ns averaged over %0d crossings", half_ns, cross_n - 1);
        btn_n[3] = 1'b1;

        $display("PASS: four-key tone, immediate note-on, bounceless note-off, gated amplifier");
        $finish;
    end

    initial begin
        #120000000; // 120 ms of simulated time is plenty
        $fatal(1, "simulation timed out");
    end
endmodule
