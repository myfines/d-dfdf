`timescale 1ns/1ps
// Check that E027's parser accepts the full K00..KFF range (needed for eight
// phone keys) while still accepting the legacy K00..K0F values.
module tb_esp_kff;
    reg clk = 0;
    reg reset_n = 0;
    reg valid = 0;
    reg [7:0] data = 0;
    wire update;
    wire [7:0] volume;
    wire command_valid;
    wire [7:0] command_kind;
    wire [7:0] command_value;
    wire [2:0] command_client;

    esp_volume_parser dut(clk, reset_n, valid, data, update, volume,
        command_valid, command_kind, command_value, command_client);

    reg seen = 0;
    reg [7:0] seen_kind = 0;
    reg [7:0] seen_value = 0;

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (command_valid) begin
            seen <= 1;
            seen_kind <= command_kind;
            seen_value <= command_value;
        end
    end

    task send_byte(input [7:0] value);
        begin
            @(posedge clk);
            valid = 1;
            data = value;
            @(posedge clk);
            valid = 0;
            repeat (2) @(posedge clk);
        end
    endtask

    task send_command(input [8*32-1:0] payload);
        integer i;
        begin
            seen = 0;
            // AT+IPD,0,4: exactly four payload bytes (including LF).
            send_byte("A"); send_byte("T"); send_byte("+"); send_byte("I");
            send_byte("P"); send_byte("D"); send_byte(","); send_byte("0");
            send_byte(","); send_byte("4"); send_byte(":");
            for (i = 0; i < 32; i = i + 8)
                send_byte(payload[31-i -: 8]);
            repeat (8) @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        reset_n = 1;
        repeat (2) @(posedge clk);

        send_command("KFF\n");
        if (!seen || seen_kind != "K" || seen_value != 8'hFF) begin
            $display("FAIL KFF: seen=%0d kind=%0d value=%02X", seen, seen_kind, seen_value);
            $fatal;
        end

        send_command("K0F\n");
        if (!seen || seen_kind != "K" || seen_value != 8'h0F) begin
            $display("FAIL K0F: seen=%0d kind=%0d value=%02X", seen, seen_kind, seen_value);
            $fatal;
        end

        send_command("V80\n");
        if (!seen || seen_kind != "V" || seen_value != 8'h80) begin
            $display("FAIL V80: seen=%0d kind=%0d value=%02X", seen, seen_kind, seen_value);
            $fatal;
        end

        $display("tb_esp_kff: PASS");
        $finish;
    end
endmodule
