`timescale 1ns/1ps
module tb_i2s;
    reg clk=0, reset_n=0;
    always #5 clk=~clk;
    reg signed [15:0] left=16'h1234, right=16'hfedc;
    wire bck, ws, data, tick;
    i2s_tx16 #(.HALF_PERIOD(3)) dut(clk,reset_n,left,right,bck,ws,data,tick);
    integer rises=0, last_change=-1, frames=0;
    reg prev_ws;
    always @(posedge bck) if(reset_n) begin
        if (rises>0 && ws!==prev_ws) begin
            if(last_change>=0 && rises-last_change!=16) $fatal(1,"WS slot is not 16 BCLKs");
            last_change=rises;
        end
        prev_ws=ws; rises=rises+1;
    end
    task check_frame(input [15:0] l, input [15:0] r);
        reg [15:0] got_l,got_r;
        integer i;
        begin
            @(negedge ws); @(posedge bck); // I2S delay bit, not the new MSB.
            got_l=0;got_r=0;
            for(i=0;i<16;i=i+1) begin @(posedge bck); got_l={got_l[14:0],data}; end
            for(i=0;i<16;i=i+1) begin @(posedge bck); got_r={got_r[14:0],data}; end
            if(got_l!==l || got_r!==r) $fatal(1,"I2S decode %h/%h expected %h/%h",got_l,got_r,l,r);
            frames=frames+1;
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);reset_n=1;
        check_frame(16'h1234,16'hfedc);
        // Change samples mid-frame. No half-frame mixing is allowed.
        @(negedge bck);left=16'h8000;right=16'h7fff;
        check_frame(16'h8000,16'h7fff);
        check_frame(16'h8000,16'h7fff);
        $display("PASS I2S: delay, signed stereo words, 16-bit slots, coherent frames");$finish;
    end
    initial begin #100000; $fatal(1,"I2S timeout"); end
endmodule
