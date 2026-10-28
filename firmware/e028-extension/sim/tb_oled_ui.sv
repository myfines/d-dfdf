`timescale 1ns/1ps
module tb_oled_ui;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg signed [15:0] sample_l = 0, sample_r = 0;
    reg [127:0] bands = 0;
    reg [1:0] timbre = 0;
    reg [2:0] fx_enable = 3'b001;
    reg [5:0] voices = 32;
    reg [15:0] latency = 1;
    reg [2:0] screen = 3'd1;
    reg [4:0] guide_note = 5;
    reg [5:0] guide_step = 10;
    reg song_playing = 0;
    reg [7:0] keys_n = 8'hff;
    reg [7:0] status = 8'h55;
    wire online;
    tri1 scl, sda;
    reg ack_low = 0;
    reg transfer = 0;
    integer bit_count = 0, word_index = 0, data_count = 0;
    reg [7:0] shift = 0, control = 0;
    reg [7:0] frame [0:4095];
    integer cycle = 0;
    integer errors = 0;

    assign sda = ack_low ? 1'b0 : 1'bz;

    oled_ui #(.HALF_TICKS(2), .BOOT_TICKS(20), .RETRY_TICKS(40), .REFRESH_TICKS(100)) dut(
        .clk(clk), .reset_n(reset_n), .frame_tick(frame_tick),
        .sample_l(sample_l), .sample_r(sample_r), .bands(bands),
        .timbre(timbre), .fx_enable(fx_enable), .voices(voices),
        .latency_frames(latency), .screen(screen), .guide_note(guide_note),
        .guide_step(guide_step), .song_playing(song_playing), .keys_n(keys_n),
        .status(status), .scl(scl), .sda(sda), .online(online));

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if(cycle == 575) begin cycle <= 0; frame_tick <= 1; end
        else frame_tick <= 0;
    end

    // Minimal SSD1306 sink: ACK every byte and capture the 0x40 stream.
    always @(negedge sda) if(scl === 1'b1) begin
        transfer = 1; bit_count = 0; word_index = 0;
    end
    always @(posedge sda) if(scl === 1'b1) transfer = 0;
    always @(negedge scl) if(transfer) begin
        if(bit_count == 8) ack_low = 1'b1;
        else ack_low = 1'b0;
    end
    always @(posedge scl) if(transfer) begin
        if(bit_count == 8) begin
            bit_count = 0;
            word_index = word_index + 1;
        end else begin
            shift = {shift[6:0], sda};
            if(bit_count == 7) begin
                if(word_index == 0 && shift !== 8'h78) begin
                    $display("bad address %02x", shift);
                    errors = errors + 1;
                end
                if(word_index == 1) control = shift;
                if(word_index >= 2 && control == 8'h40) begin
                    if(data_count < 4096) frame[data_count] = shift;
                    data_count = data_count + 1;
                end
            end
            bit_count = bit_count + 1;
        end
    end

    initial begin
        repeat(10) @(posedge clk);
        reset_n = 1;
        wait(online);
        $display("OLED online");
        bands[7:0] = 8'd120;
        bands[31:24] = 8'd180;
        bands[63:56] = 8'd255;
        bands[79:72] = 8'd200;
        bands[103:96] = 8'd80;
        // Second frame: spectrum, band 0 full scale -> column 0 byte 0xff.
        wait(data_count >= 2048);
        #1;
        if(frame[1024] !== 8'hff) begin
            $display("spectrum pixel %02x", frame[1024]);
            errors = errors + 1;
        end
        // Third frame: guide, key 5 highlighted at column 80 (page 0).
        screen = 3;
        wait(data_count >= 3072);
        #1;
        if(frame[2048 + 80] !== 8'h7e) begin
            $display("guide pixel %02x", frame[2048 + 80]);
            errors = errors + 1;
        end
        if(errors != 0) $fatal(1, "%0d OLED errors", errors);
        begin : dump_frames
            integer fd, j;
            fd = $fopen("oled_spectrum.hex", "w");
            for(j = 1024; j < 2048; j = j + 1) $fdisplay(fd, "%02x", frame[j]);
            $fclose(fd);
            fd = $fopen("oled_guide.hex", "w");
            for(j = 2048; j < 3072; j = j + 1) $fdisplay(fd, "%02x", frame[j]);
            $fclose(fd);
        end
        $display("PASS OLED UI bytes=%0d", data_count);
        $finish;
    end

    initial begin
        #50000000;
        $fatal(1, "OLED timeout");
    end
endmodule
