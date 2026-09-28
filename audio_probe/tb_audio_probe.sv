`timescale 1ns/1ps

module tb_audio_probe;
    reg clk = 0;
    reg rst_n = 0;
    wire HP_BCK, HP_WS, HP_DIN, PA_EN;

    always #18.519 clk = ~clk; // 27 MHz input clock

    audio_probe #(
        .ENABLE_DELAY_FRAMES(4),
        .GATE_HALF_FRAMES(200)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .HP_BCK(HP_BCK), .HP_WS(HP_WS), .HP_DIN(HP_DIN), .PA_EN(PA_EN)
    );

    integer bit_number = 0;
    integer frames = 0;
    integer sounding = 0;
    integer silent = 0;
    integer sign_changes = 0;
    integer previous_sign = -1;
    reg started = 0;
    reg [15:0] right_word = 0;
    reg [15:0] left_word = 0;
    reg [15:0] next_right;
    reg [15:0] next_left;
    realtime previous_frame = 0.0;

    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    always @(negedge HP_BCK) begin
        if (rst_n) started = 1;
    end

    always @(posedge HP_BCK) begin
        if (started && rst_n) begin
            if (HP_WS !== (bit_number >= 16))
                $fatal(1, "WS does not match the PT8211 half-frame at bit %0d", bit_number);
            if (bit_number < 16)
                right_word = {right_word[14:0], HP_DIN};
            else
                left_word = {left_word[14:0], HP_DIN};

            if (bit_number == 31) begin
                next_right = right_word;
                next_left = left_word;
                if (next_right !== next_left)
                    $fatal(1, "Right and left samples differ: %h %h", next_right, next_left);
                if ($signed(next_left) > 512 || $signed(next_left) < -512)
                    $fatal(1, "Test tone exceeds its low-volume bound: %0d", $signed(next_left));
                if (frames < 4 && PA_EN !== 0)
                    $fatal(1, "Headphone amp enabled before silent startup");
                if (frames > 5 && PA_EN !== 1)
                    $fatal(1, "Headphone amp did not enable");
                if (frames >= 10 && frames < 200) begin
                    if (next_left != 0) sounding = sounding + 1;
                    if (previous_sign >= 0 && previous_sign != (next_left[15] ? 1 : 0))
                        sign_changes = sign_changes + 1;
                    previous_sign = next_left[15] ? 1 : 0;
                end
                if (frames >= 202 && next_left == 0) silent = silent + 1;
                if (previous_frame != 0.0 &&
                    (($realtime - previous_frame) < 21000.0 ||
                     ($realtime - previous_frame) > 22000.0))
                    $fatal(1, "Unexpected audio frame period");
                previous_frame = $realtime;
                frames = frames + 1;
                right_word = 0;
                left_word = 0;
                if (frames == 300) begin
                    if (sounding < 150 || silent < 90 || sign_changes < 2)
                        $fatal(1, "Tone or silence not observed: %0d %0d %0d", sounding, silent, sign_changes);
                    $display("PASS: 300 stereo frames, 46.875 kHz, bounded tone, startup mute, gated silence");
                    $finish;
                end
            end
            bit_number = (bit_number == 31) ? 0 : bit_number + 1;
        end
    end

    initial begin
        #10000000;
        $fatal(1, "Timed out waiting for 300 audio frames");
    end
endmodule
