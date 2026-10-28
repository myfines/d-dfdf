`timescale 1ns/1ps
module tb_fx;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg signed [15:0] dry = 0;
    reg [2:0] enable = 3'b111;
    wire signed [15:0] sample_l, sample_r;
    integer cycle = 0, frame = 0, nz = 0, maxv = 0;
    integer i;
    reg saw_chorus = 0, saw_delay = 0, saw_reverb = 0;

    fx_engine dut(.clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
                  .dry(dry), .enable(enable), .sample_l(sample_l), .sample_r(sample_r));

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin cycle <= 0; frame_tick <= 1; frame <= frame + 1; end
        else frame_tick <= 0;
    end

    always @(posedge clk) begin
        if(frame_tick && frame > 3) begin
            #1;
            if(sample_l != 0 || sample_r != 0) nz = nz + 1;
            if(dut.chorus_q != 0) saw_chorus = 1;
            if(dut.delay_q != 0) saw_delay = 1;
            if(dut.rev1_q != 0) saw_reverb = 1;
            if(sample_l > maxv) maxv = sample_l;
            if(-sample_l > maxv) maxv = -sample_l;
            if(sample_l === 16'bx || sample_r === 16'bx) $fatal(1, "X on output");
            if(frame < 12 || (frame > 315 && frame < 330) || frame % 500 == 0)
                $display("frame %0d dry=%0d L=%0d R=%0d cw=%0d dw=%0d rw=%0d st=%0d cq=%0d dq=%0d rq=%0d",
                         frame, dry, sample_l, sample_r, dut.chorus_wr, dut.delay_wr,
                         dut.rev1_wr, dut.state, dut.chorus_q, dut.delay_q, dut.rev1_q);
        end
    end

    initial begin
        // Clear inferred block RAMs for deterministic simulation.
        for(i=0;i<1024;i=i+1) dut.chorus_ram[i] = 0;
        for(i=0;i<2048;i=i+1) begin dut.delay_ram[i] = 0; dut.rev1_ram[i] = 0; dut.rev2_ram[i] = 0; end
        for(i=0;i<256;i=i+1) dut.ap1_ram[i] = 0;
        for(i=0;i<512;i=i+1) dut.ap2_ram[i] = 0;
        repeat(4) @(posedge clk);
        reset_n = 1;
        repeat(576*2) @(posedge clk);
        dry = 16'sd20000;
        repeat(576*2) @(posedge clk);
        dry = 0;
        repeat(576*3500) @(posedge clk);
        if(!saw_chorus) $fatal(1, "chorus produced no output");
        if(!saw_delay)  $fatal(1, "delay produced no output");
        if(!saw_reverb) $fatal(1, "reverb produced no output");
        if(nz < 10) $fatal(1, "no effect tail");
        if(maxv > 32767) $fatal(1, "overflow");
        $display("PASS fx chorus=%0d delay=%0d reverb=%0d nonzero=%0d max=%0d",
                 saw_chorus, saw_delay, saw_reverb, nz, maxv);
        $finish;
    end

    initial begin
        #100000000;
        $fatal(1, "timeout");
    end
endmodule
