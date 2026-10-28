`timescale 1ns/1ps
module tb_command;
    reg clk = 0;
    reg reset_n = 0;
    reg valid = 0;
    reg [7:0] data = 0;
    wire cmd_valid;
    wire [7:0] cmd_kind;
    wire [31:0] cmd_value;
    wire [2:0] cmd_client;
    integer errors = 0;
    reg seen = 0;
    reg [7:0] seen_kind;
    reg [31:0] seen_value;

    always @(posedge clk) begin
        if(cmd_valid) begin
            seen <= 1;
            seen_kind <= cmd_kind;
            seen_value <= cmd_value;
        end
    end

    esp_command_parser dut(
        .clk(clk), .reset_n(reset_n), .valid(valid), .data(data),
        .cmd_valid(cmd_valid), .cmd_kind(cmd_kind),
        .cmd_value(cmd_value), .cmd_client(cmd_client));

    always #18.5185 clk = ~clk;

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk); valid = 1; data = b;
            @(posedge clk); valid = 0;
        end
    endtask

    task send_str;
        input [255:0] s;
        input integer n;
        integer i;
        begin
            for(i = 0; i < n; i = i + 1)
                send_byte(s[8*(n-1-i) +: 8]);
        end
    endtask

    task expect_cmd;
        input [7:0] kind;
        input [31:0] value;
        begin
            while(!seen) @(posedge clk);
            #1;
            if(seen_kind !== kind || seen_value !== value) begin
                $display("FAIL kind=%c value=%08x expected %c %08x",
                         seen_kind, seen_value, kind, value);
                errors = errors + 1;
            end else
                $display("ok %c %08x", seen_kind, seen_value);
            seen = 0;
        end
    endtask

    initial begin
        repeat(4) @(posedge clk);
        reset_n = 1;
        repeat(4) @(posedge clk);

        send_str("+IPD,0,4:V80\n", 13);
        expect_cmd("V", 32'h80);

        send_str("+IPD,0,10:MFFFFFFFF\n", 20);
        expect_cmd("M", 32'hffffffff);

        send_str("+IPD,0,6:B1FFF\n", 15);
        expect_cmd("B", 32'h1fff);

        send_str("+IPD,0,4:X7F\n", 13);
        expect_cmd("X", 32'h7f);

        send_str("+IPD,0,4:F07\n", 13);
        expect_cmd("F", 32'h07);

        send_str("+IPD,0,4:S04\n", 13);
        expect_cmd("S", 32'h04);

        if(errors != 0) $fatal(1, "%0d errors", errors);
        $display("PASS command parser");
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "timeout");
    end
endmodule
