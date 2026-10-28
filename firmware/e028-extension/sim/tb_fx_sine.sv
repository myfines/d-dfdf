`timescale 1ns/1ps
module tb_fx_sine;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg signed [15:0] dry = 0;
    reg [2:0] enable = 3'b111;
    wire signed [15:0] sample_l, sample_r;
    integer cycle = 0, frame = 0;
    integer i;
    integer minv = 32767, maxv = -32768;
    integer sum = 0, n = 0;
    reg [31:0] phase = 0;
    wire signed [15:0] sine = $signed(phase[31:16]);

    fx_engine dut(.clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
                  .dry(dry), .enable(enable), .sample_l(sample_l), .sample_r(sample_r));

    always #18.5185 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin
            cycle <= 0; frame_tick <= 1; frame <= frame + 1;
            phase <= phase + 32'd40315426; // 440 Hz at 46.875 kHz
            dry <= $signed(phase[31:16]) >>> 1;
        end else frame_tick <= 0;
        if(frame > 2000 && frame < 12000) begin
            if(sample_l < minv) minv = sample_l;
            if(sample_l > maxv) maxv = sample_l;
            sum = sum + (sample_l < 0 ? -sample_l : sample_l);
            n = n + 1;
        end
    end

    initial begin
        for(i=0;i<1024;i=i+1) dut.chorus_ram[i] = 0;
        for(i=0;i<2048;i=i+1) begin dut.delay_ram[i]=0; dut.rev1_ram[i]=0; dut.rev2_ram[i]=0; end
        for(i=0;i<256;i=i+1) dut.ap1_ram[i]=0;
        for(i=0;i<512;i=i+1) dut.ap2_ram[i]=0;
        repeat(4) @(posedge clk); reset_n=1;
        repeat(576*13000) @(posedge clk);
        $display("FX sine min=%0d max=%0d avgabs=%0d n=%0d", minv, maxv, sum/n, n);
        if(maxv - minv < 2000) $fatal(1, "FX output too small/constant");
        $display("PASS fx sine");
        $finish;
    end
    initial begin #500000000; $fatal(1,"timeout"); end
endmodule
