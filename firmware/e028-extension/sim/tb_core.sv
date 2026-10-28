`timescale 1ns/1ps
module tb_core;
    reg clk = 0;
    reg [3:0] btn_n = 4'hf;
    reg joy_sw_n = 1;
    wire adc_scl, adc_sda;
    wire optical_scl, optical_sda;
    wire oled_scl, oled_sda;
    reg esp_rx = 1;
    reg k230_rx = 1;
    wire pcm_bck, pcm_lrck, pcm_data;
    wire pa_en, hp_bck, hp_ws, hp_din;
    wire [3:0] led;
    wire uart_tx, esp_tx;
    integer ads_configs;
    integer t_press = 0;
    integer t_first = 0;
    integer cycles;
    reg pcm_prev = 0;
    integer i;
    reg btn_seen = 0, gate_seen = 0;
    integer ft_count = 0;
    always @(posedge clk) begin
        if(t_press != 0) begin
            if(dut.frame_tick) ft_count = ft_count + 1;
            if(dut.router.btn_stable[0] == 0 && !btn_seen) begin
                btn_seen = 1;
                $display("btn stable at %0d ns (frames=%0d)", $time - t_press, ft_count);
            end
            if(dut.gate_from_router[28] && !gate_seen) begin
                gate_seen = 1;
                $display("gate bit28 at %0d ns (frames=%0d)", $time - t_press, ft_count);
            end
        end
    end

    pullup(adc_scl); pullup(adc_sda);
    pullup(optical_scl); pullup(optical_sda);
    pullup(oled_scl); pullup(oled_sda);

    ads1015_model adc_model(
        .scl(adc_scl), .sda(adc_sda), .enabled(1'b1),
        .code_x(12'd825), .code_y(12'd2000), .configs(ads_configs));

    instrument_core #(
        .SAFE_STARTUP(0), .ENABLE_OPTICAL(0), .ENABLE_UI(0),
        .ENABLE_GESTURE(0), .LINK_MODE(1)
    ) dut(
        .clk(clk), .btn_n(btn_n), .JOY_SW_N(joy_sw_n),
        .ADC_SCL(adc_scl), .ADC_SDA(adc_sda),
        .OPTICAL_SCL(optical_scl), .OPTICAL_SDA(optical_sda),
        .OLED_SCL(oled_scl), .OLED_SDA(oled_sda),
        .ESP_RX(esp_rx), .K230_RX(k230_rx),
        .PCM_BCK(pcm_bck), .PCM_LRCK(pcm_lrck), .PCM_DATA(pcm_data),
        .PA_EN(pa_en), .HP_BCK(hp_bck), .HP_WS(hp_ws), .HP_DIN(hp_din),
        .led(led), .UART_TX(uart_tx), .ESP_TX(esp_tx));

    always #18.5185 clk = ~clk;

    // Wait until the synthesised sample becomes non-zero after the key.
    always @(posedge clk) begin
        if(t_press != 0 && t_first == 0 && dut.synth_sample != 0)
            t_first = $time;
    end

    initial begin
        // Latency fixture bypasses only the one-second arm settling timer.
        // Production SAFE_STARTUP and its guard remain enabled in the top.
        force dut.arm_inhibit=0;
        repeat(100) @(posedge clk);
        // allow ADC/optical boot timers and the audio pipeline to settle
        repeat(200000) @(posedge clk);
        if(dut.armed !== 1'b1) $fatal(1, "core did not arm");
        if(ads_configs < 1) $fatal(1, "ADC model not configured");

        t_press = $time;
        btn_n = 4'b1110; // S1 pressed -> voice bit 28 (E5)
        repeat(400000) @(posedge clk); // 14.8 ms
        if(t_first == 0) $fatal(1, "no audio after key");
        cycles = (t_first - t_press) / 37.037;
        $display("key->audio: %0d ns (%0d cycles, %0.3f ms)",
                 t_first - t_press, cycles, (t_first - t_press) / 1000000.0);
        if((t_first - t_press) > 5000000)
            $fatal(1, "latency > 5 ms: %0d ns", t_first - t_press);
        if(dut.voice_count < 1) $fatal(1, "no active voice");

        btn_n = 4'hf;
        repeat(20000) @(posedge clk);

        // Stress test: all 32 voices gated simultaneously.
        force dut.app_mask = 32'hffffffff;
        force dut.app_override = 1'b1;
        repeat(20000) @(posedge clk);
        if(dut.voice_count !== 6'd32)
            $fatal(1, "32-voice test got %0d voices", dut.voice_count);
        if(dut.synth_sample === 16'bx)
            $fatal(1, "X on 32-voice output");
        $display("32-voice stress: voices=%0d sample=%0d", dut.voice_count, dut.synth_sample);
        release dut.app_mask;
        release dut.app_override;
        repeat(20000) @(posedge clk);

        $display("PASS core latency=%0d ns ads=%0d", t_first - t_press, ads_configs);
        $finish;
    end

    initial begin
        #40000000;
        $fatal(1, "timeout");
    end
endmodule
