`timescale 1ns/1ps
module tb_voice;
    reg clk=0,reset_n=0,tick=0;
    always #5 clk=~clk;
    reg [3:0] keys=15;
    reg valid=0,octave=0;
    reg [11:0] x=825,y=0;
    wire signed [15:0] sample;
    wire active;
    integer crossings,largest_step;
    voice_engine #(.RELEASE_FRAMES(3),.ATTACK_STEP(128)) dut(clk,reset_n,tick,keys,valid,x,y,octave,sample,active,1'b0,2'd0,9'd6,16'd16,9'd160,16'd4,2'd0,1'b0,4'd15,12'd0,4'd0);
    task frame;
        begin @(negedge clk);tick=1;@(negedge clk);tick=0;end
    endtask
    task observe(input integer lo,input integer hi);
        integer i,c,step;reg signed [15:0] last;
        begin
            repeat(150) frame();c=0;last=sample;largest_step=0;
            for(i=0;i<5000;i=i+1) begin
                frame();
                if(sample>8192 || sample< -8192) $fatal(1,"Audio exceeds quarter-scale limit");
                if(last<0 && sample>=0)c=c+1;
                step=sample-last;if(step<0)step=-step;if(step>largest_step)largest_step=step;
                last=sample;
            end
            if(c<lo || c>hi)$fatal(1,"Frequency crossings %d outside %d..%d",c,lo,hi);
            crossings=c;
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);reset_n=1;
        repeat(20)frame();if(sample!==0 || active)$fatal(1,"Idle must be silent");
        keys=4'b1110;observe(54,57); // C5 ~56 periods / 5000 frames.
        if(largest_step>1000)$fatal(1,"Default triangle has unexpected discontinuity");
        valid=1;x=1650;observe(60,63); // ~+10% bend.
        x=0;observe(49,52);
        x=825;y=1650;observe(54,57);if(largest_step<1200)$fatal(1,"Y did not change waveform");
        // Missing ADC must restore neutral pitch and gentle default waveform.
        valid=0;observe(54,57);if(largest_step>1000)$fatal(1,"Invalid ADC kept stale timbre");
        octave=1;observe(27,29);octave=0;
        keys=4'b0111;observe(82,85); // G5.
        // Chords and selective release are verified separately in tb_poly.
        keys=15;repeat(1200)frame();if(sample!==0 || active)$fatal(1,"Release failed to become silent");
        $display("PASS voice: single note frequency, bend, timbre, octave, level limit, neutral failover, silence");$finish;
    end
    initial begin #2000000;$fatal(1,"voice test timeout");end
endmodule
