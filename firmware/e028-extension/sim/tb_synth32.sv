`timescale 1ns/1ps
module tb_synth32;
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
    wire [5:0] voice_count;
    wire note_on;
    wire [4:0] note_on_index;
    wire [15:0] latency_frames;

    integer cycle = 0;
    integer frame = 0;
    integer nonzero_frames = 0;
    integer max_abs = 0;
    integer i;

    synth32 dut(
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .gate_mask(gate_mask), .timbre(timbre), .velocity(velocity),
        .bend(bend), .vibrato(vibrato), .brightness(brightness),
        .expression(expression), .tremolo(tremolo), .sample(sample),
        .active(active), .voice_count(voice_count), .note_on(note_on),
        .note_on_index(note_on_index), .latency_frames(latency_frames)
    );

    always #18.5185 clk = ~clk; // 27 MHz

    // 576 clocks per 46.875 kHz frame
    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin
            cycle <= 0;
            frame_tick <= 1;
            frame <= frame + 1;
        end else frame_tick <= 0;
    end

    always @(posedge clk) begin
        if(frame_tick && frame > 2) begin
            #1;
            if(sample != 0) nonzero_frames = nonzero_frames + 1;
            if(sample > max_abs) max_abs = sample;
            if(-sample > max_abs) max_abs = -sample;
            if(frame<6) $display("frame %0d mask=%08x voices=%0d active=%0d sample=%0d lat=%0d note_on=%0d idx=%0d",
                     frame, gate_mask, voice_count, active, sample, latency_frames, note_on, note_on_index);
        end
    end

    initial begin
        repeat(4) @(posedge clk);
        reset_n = 1;
        repeat(576*2) @(posedge clk);
        gate_mask = 32'hffffffff;
        velocity = 100;
        repeat(576*160) @(posedge clk);
        if(voice_count !== 6'd32) $fatal(1, "voice_count != 32: %0d", voice_count);
        for(i=0;i<32;i=i+1) begin
            if(dut.env_level[i]==0 || dut.env_state[i]==0) $fatal(1,"inactive envelope %0d",i);
            if(i>0 && dut.phase[i]===dut.phase[i-1]) $fatal(1,"shared phase state %0d",i);
        end
        if(nonzero_frames < 8) $fatal(1, "no sustained output");
        if(max_abs < 1000) $fatal(1, "output too small: %0d", max_abs);
        if(latency_frames > 3) $fatal(1, "latency too high: %0d", latency_frames);
        $display("PASS synth32 voices=%0d nonzero=%0d max=%0d latency=%0d",
                 voice_count, nonzero_frames, max_abs, latency_frames);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "timeout");
    end
endmodule
