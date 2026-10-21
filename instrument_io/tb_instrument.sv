`timescale 1ns/1ps
module tb_instrument;
    reg clk=0;always #18.5185 clk=~clk;
    reg [3:0] keys=15;reg joy=1,enabled=1;
    tri1 scl,sda;
    tri1 optical_scl,optical_sda;wire bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart;
    integer configs,n,nonzero;
    reg [15:0] l,r;
    real last_bck=0;
    instrument_io #(.SAFE_STARTUP(0),.I2C_HALF_TICKS(4),.CONVERSION_TICKS(100),.RETRY_TICKS(200),
        .BUS_TIMEOUT_TICKS(500),.SWITCH_DEBOUNCE_TICKS(10)) dut(
        clk,keys,joy,scl,sda,bck,ws,data,pa,hb,hw,hd,alive,adc_led,uart,optical_scl,optical_sda,,,1'b1,);
    ads1015_model slave(scl,sda,enabled,12'd825,12'd0,configs);
    always @(posedge bck) if(dut.reset_n) begin
        if(last_bck!=0 && (($realtime-last_bck)<666.0 || ($realtime-last_bck)>667.0))
            $fatal(1,"Incorrect real BCLK period %f",$realtime-last_bck);
        last_bck=$realtime;
    end
    always @(posedge clk) if(pa!==0 || hb!==0 || hw!==0 || hd!==0)
        $fatal(1,"Onboard PT8211/headphone amplifier must stay inactive");
    task decode;
        integer i;
        begin
            @(negedge ws);@(posedge bck);l=0;r=0;
            for(i=0;i<16;i=i+1) begin @(posedge bck);l={l[14:0],data};end
            for(i=0;i<16;i=i+1) begin @(posedge bck);r={r[14:0],data};end
            if(l!==r)$fatal(1,"Stereo frame mismatch");
            if($signed(l)>8192 || $signed(l)<-8192)$fatal(1,"Line output level exceeds limit");
        end
    endtask
    initial begin
        wait(adc_led);keys=14;nonzero=0;
        for(n=0;n<50;n=n+1)begin decode();if(l!=0)nonzero=nonzero+1;end
        if(nonzero<20)$fatal(1,"Held note did not reach PCM output");
        enabled=0;wait(!adc_led);nonzero=0;
        for(n=0;n<10;n=n+1)begin decode();if(l!=0)nonzero=nonzero+1;end
        if(nonzero==0)$fatal(1,"Missing ADC incorrectly silenced keyboard");
        enabled=1;wait(adc_led);keys=15;
        repeat(1400) @(negedge ws);
        decode();if(l!==0 || r!==0)$fatal(1,"Idle PCM output not silent");
        $display("PASS integration: real BCLK rate, decoded stereo audio, ADC LED, missing-ADC fallback, release, amp disabled");$finish;
    end
    initial begin #60000000;$fatal(1,"Integration timeout");end
endmodule
