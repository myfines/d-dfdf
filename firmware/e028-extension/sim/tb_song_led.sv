`timescale 1ns/1ps
module tb_song_led;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg enable = 0;
    wire [31:0] gate;
    wire [4:0] note;
    wire [5:0] step;
    wire beat, playing;
    integer cycle = 0, frames = 0;
    integer i;
    wire [3:0] led;
    reg [23:0] heartbeat = 0;

    song_player #(.STEP_FRAMES(64)) song(
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick), .enable(enable),
        .gate_mask(gate), .guide_note(note), .step(step), .beat(beat), .playing(playing));

    led_guide lamps(
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick), .playing(playing),
        .guide_note(note), .beat(beat), .active_voices(6'd1),
        .heartbeat(heartbeat), .led(led));

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        heartbeat <= heartbeat + 1'b1;
        if(cycle == 575) begin
            cycle <= 0; frame_tick <= 1; frames <= frames + 1;
        end else frame_tick <= 0;
    end

    initial begin
        repeat(4) @(posedge clk);
        reset_n = 1;
        repeat(576*4) @(posedge clk);
        enable = 1;
        repeat(576*8) @(posedge clk);
        if(!playing) $fatal(1, "song not playing");
        if(note !== 5'd16) $fatal(1, "wrong first note: %0d", note);
        if(gate[16] !== 1'b1 || gate[0] !== 1'b1)
            $fatal(1, "first chord bits missing: %08x", gate);

        repeat(576*70) @(posedge clk); // slightly more than one step
        if(step !== 6'd1) $fatal(1, "step did not advance: %0d", step);
        if(gate[16] !== 1'b1) $fatal(1, "second step note missing");

        // LED guide: key 5 -> group 2, PWM must eventually light led[2].
        begin : led_wait
            integer n;
            for(n = 0; n < 2000; n = n + 1) begin
                @(posedge clk);
                if(led[0]) begin
                    $display("LED group 0 lit at cycle %0d", n);
                    disable led_wait;
                end
                if(n == 1999) $fatal(1, "LED guide did not light");
            end
        end

        enable = 0;
        repeat(576*4) @(posedge clk);
        if(playing) $fatal(1, "song did not stop");
        $display("PASS song/led note=%0d step=%0d gate=%08x", note, step, gate);
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "timeout");
    end
endmodule
