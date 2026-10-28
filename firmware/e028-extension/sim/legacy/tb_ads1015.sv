`timescale 1ns/1ps
module tb_ads1015;
    reg clk=0,reset_n=0,enabled=1;
    always #5 clk=~clk;
    tri1 scl,sda;
    reg hold_scl=0,hold_sda=0;
    assign scl=hold_scl?1'b0:1'bz;
    assign sda=hold_sda?1'b0:1'bz;
    reg [11:0] x=825,y=1234;
    wire [11:0] got_x,got_y;
    wire valid,error;
    integer configs;
    ads1015_reader #(.I2C_HALF_TICKS(4),.CONVERSION_TICKS(100),.RETRY_TICKS(200),.BUS_TIMEOUT_TICKS(500))
        dut(clk,reset_n,scl,sda,got_x,got_y,valid,error);
    ads1015_model slave(scl,sda,enabled,x,y,configs);
    task wait_pair(input [11:0] a,input [11:0] b);
        integer count;
        begin
            count=0;
            while(!(valid && got_x==a && got_y==b) && count<20000) begin @(negedge clk);count=count+1;end
            if(count==20000) $fatal(1,"ADC pair timeout x=%d y=%d valid=%b err=%b",got_x,got_y,valid,error);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);reset_n=1;
        // Clock stretching must not be mistaken for an ACK or bit clock.
        @(negedge scl);hold_scl=1;repeat(30) @(negedge clk);hold_scl=0;
        wait_pair(825,1234);
        x=12'd1600;y=12'd100;wait_pair(1600,100);
        x=12'hfff;y=12'd2047;wait_pair(0,1650); // Negative and overrange inputs clamp.
        x=12'd1600;y=12'd100;wait_pair(1600,100);
        if(configs<4) $fatal(1,"Did not alternate both channels");
        enabled=0;wait(error);if(valid) $fatal(1,"NACK must invalidate stale controls");
        enabled=1;wait_pair(1600,100);
        hold_scl=1;wait(error);hold_scl=0;
        wait_pair(1600,100);
        // Stuck SDA must produce bounded recovery, never a busy loop.
        enabled=0;hold_sda=1;repeat(4000) @(negedge clk);
        if(!error || valid) $fatal(1,"Stuck SDA not reported valid=%b error=%b reader=%d bus=%d",valid,error,dut.state,dut.bus.state);
        hold_sda=0;enabled=1;wait_pair(1600,100);
        $display("PASS ADS1015: address/config, signed-byte framing, both axes, stretch, NACK, stuck bus recovery");$finish;
    end
    initial begin #2000000;$fatal(1,"ADC test timeout");end
endmodule
