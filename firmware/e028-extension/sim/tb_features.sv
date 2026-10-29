`timescale 1ns/1ps
module tb_features;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg [31:0] gate_mask = 0;
    reg [1:0] timbre = 0;
    reg [7:0] velocity = 100;
    reg signed [13:0] bend = 0;
    reg [7:0] vibrato = 0;
    reg [7:0] brightness = 128;
    reg [7:0] expression = 255;
    reg [7:0] tremolo = 0;
    wire signed [15:0] sample;
    wire active;
    wire [5:0] voices;
    wire note_on;
    wire [4:0] note_idx;
    wire [15:0] latency;

    synth32 dut(.clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .gate_mask(gate_mask), .timbre(timbre), .velocity(velocity),
        .bend(bend), .vibrato(vibrato), .brightness(brightness),
        .expression(expression), .tremolo(tremolo), .sample(sample),
        .active(active), .voice_count(voices), .note_on(note_on),
        .note_on_index(note_idx), .latency_frames(latency));

    integer cycle = 0, frame = 0;
    integer sum_abs [0:3];
    integer peak [0:3];
    integer phase_edges = 0;
    integer i, full_expression_peak, expected_expression_peak;
    reg phase_msb = 0;
    reg [31:0] inc12 = 0;
    always @(posedge clk) if(dut.state == 3'd1 && dut.voice_index == 5'd12) inc12 <= dut.increment_final;

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin cycle <= 0; frame_tick <= 1; frame <= frame + 1; end
        else frame_tick <= 0;
        phase_msb <= dut.phase[12][31];
        if(phase_msb == 0 && dut.phase[12][31] == 1 && frame > 20) phase_edges = phase_edges + 1;
    end

    task run_note;
        input [1:0] t;
        input signed [13:0] b;
        input [7:0] expr;
        integer n;
        begin
            reset_n = 0; repeat(8) @(posedge clk);
            timbre = t; bend = b; expression = expr; gate_mask = 32'h00001000;
            reset_n = 1;
            repeat(576*20) @(posedge clk);
            for(n = 0; n < 500; n = n + 1) begin
                repeat(576) @(posedge clk);
                if(sample > 0) sum_abs[t] = sum_abs[t] + sample;
                else sum_abs[t] = sum_abs[t] - sample;
                if(sample > peak[t]) peak[t] = sample;
                if(-sample > peak[t]) peak[t] = -sample;
            end
        end
    endtask

    initial begin
        for(i = 0; i < 4; i = i + 1) begin sum_abs[i] = 0; peak[i] = 0; end
        run_note(0, 0, 255);
        run_note(1, 0, 255);
        run_note(2, 0, 255);
        run_note(3, 0, 255);
        for(i = 0; i < 4; i = i + 1) begin
            $display("timbre %0d sum=%0d peak=%0d", i, sum_abs[i], peak[i]);
            if(peak[i] < 500) $fatal(1, "timbre %0d too quiet", i);
        end
        if(sum_abs[0] == sum_abs[1] || sum_abs[1] == sum_abs[2] || sum_abs[2] == sum_abs[3])
            $fatal(1, "timbres are not distinct");

        // Expression dimension: output must scale with expression.
        full_expression_peak = peak[0];
        sum_abs[0] = 0; peak[0] = 0;
        run_note(0, 0, 64);
        expected_expression_peak = (full_expression_peak * 64 + 127) / 255;
        if(peak[0] > expected_expression_peak + 3 ||
           peak[0] < expected_expression_peak - 3 || peak[0] == 0)
            $fatal(1, "expression scaling wrong: %0d", peak[0]);
        $display("expression peak=%0d", peak[0]);

        // Pitch bend: +2 semitones must produce a clearly higher phase increment.
        begin : bend_check
            reg [31:0] inc_pos, inc_neg;
            run_note(0, 14'sd8191, 255);
            inc_pos = inc12;
            run_note(0, -14'sd8192, 255);
            inc_neg = inc12;
            $display("bend increment +/%0d = %0d/%0d", inc_pos, inc_pos, inc_neg);
            if(inc_pos * 100 < inc_neg * 115)
                $fatal(1, "bend ratio too small");
        end

        $display("PASS features timbres/expression/bend");
        $finish;
    end

    initial begin
        #200000000;
        $fatal(1, "timeout");
    end
endmodule
