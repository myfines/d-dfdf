`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// ESP-01S / BLE-serial command parser.
//
// The transport is deliberately only "a 115200 8N1 serial stream".  It can be
// an ESP-01S running the existing AT/TCP firmware or a BLE-UART module
// (JDY-31/HC-05 class) wired to the same T12/R11 pins; the FPGA protocol is
// identical.
//
// Supported payload commands (ASCII, LF terminated):
//   Vxx Txx Exx Kxx Pxx Q00 L00       legacy E027 commands
//   Mxxxxxxxx                         direct 32-note mask (8 hex digits)
//   Bxxxx                             pitch bend, 0..16383, 8192 = centre
//   Xxx                               vibrato depth 0..255
//   Yxx                               brightness 0..255
//   Fxx                               effects {reverb,delay,chorus}
//   Sxx                               OLED screen 0..4
//   Rxx                               offline song 0/1
//   Hxx                               latch 0/1
//   Dxx                               32-voice demonstration chord 0/1
// -----------------------------------------------------------------------------
module esp_command_parser #(
    parameter RAW_MODE = 0
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       valid,
    input  wire [7:0] data,
    output reg        cmd_valid,
    output reg  [7:0] cmd_kind,
    output reg  [31:0] cmd_value,
    output reg  [2:0] cmd_client
);

    localparam S_IDLE   = 4'd0;
    localparam S_I      = 4'd1;
    localparam S_P      = 4'd2;
    localparam S_D      = 4'd3;
    localparam S_COMMA  = 4'd4;
    localparam S_CLIENT = 4'd5;
    localparam S_COMMA2 = 4'd6;
    localparam S_LEN    = 4'd7;
    localparam S_COLON  = 4'd8;
    localparam S_PAY    = 4'd9;

    reg [3:0]  state;
    reg [2:0]  client;
    reg [12:0] length, left;
    reg [7:0]  line [0:11];
    reg [3:0]  count;
    reg [3:0]  digits;
    reg [3:0]  expected;
    reg [31:0] value;
    reg        parsing;

    wire digit = data >= 8'd48 && data <= 8'd57;
    wire hex   = digit || (data >= 8'd65 && data <= 8'd70) ||
                        (data >= 8'd97 && data <= 8'd102);
    wire [3:0] nibble = digit ? data[3:0] : data[3:0] + 4'd9;
    wire [16:0] next_length = length * 17'd10 + {13'd0, data[3:0]};
    integer i;

    always @(posedge clk) begin
        if(!reset_n) begin
            state <= S_IDLE;
            client <= 0;
            length <= 0;
            left <= 0;
            count <= 0;
            digits <= 0;
            expected <= 0;
            value <= 0;
            parsing <= 0;
            cmd_valid <= 0;
            cmd_kind <= 0;
            cmd_value <= 0;
            cmd_client <= 0;
            for(i = 0; i < 12; i = i + 1) line[i] <= 0;
        end else begin
            cmd_valid <= 0;

            // Payload bytes are consumed only while inside +IPD, or directly
            // when the transport is a transparent BLE-UART module.
            if((RAW_MODE && valid) || (!RAW_MODE && state == S_PAY && valid)) begin
                left <= left - 1'b1;
                if(data == 8'd10) begin
                    // End of an ASCII command line.
                    if(count != 0 && expected != 0 && digits == expected) begin
                        cmd_kind <= line[0];
                        cmd_client <= client;
                        cmd_value <= value;
                        cmd_valid <= 1;
                    end
                    count <= 0;
                    digits <= 0;
                    value <= 0;
                end else if(data != 8'd13) begin
                    if(count < 12) begin
                        line[count] <= data;
                        if(count == 0) begin
                            case(data)
                                "V","T","E","K","P","Q","L": expected <= 4'd2;
                                "M","G","U": expected <= 4'd8;
                                "B": expected <= 4'd4;
                                "X","Y","F","S","R","H","D": expected <= 4'd2;
                                default: expected <= 4'd0;
                            endcase
                            digits <= 0;
                            value <= 0;
                        end else if(hex && digits < expected) begin
                            value <= {value[27:0], nibble};
                            digits <= digits + 1'b1;
                        end else begin
                            expected <= 0;
                        end
                    end
                    count <= count + 1'b1;
                end
                if(!RAW_MODE && left == 1) state <= S_IDLE;
            end else if(valid && !RAW_MODE) begin
                case(state)
                    S_IDLE:   if(data == "+") begin
                                  length <= 0;
                                  state <= S_I;
                              end
                    S_I:      state <= (data == "I") ? S_P : (data == "+" ? S_I : S_IDLE);
                    S_P:      state <= (data == "P") ? S_D : S_IDLE;
                    S_D:      state <= (data == "D") ? S_COMMA : S_IDLE;
                    S_COMMA:  state <= (data == ",") ? S_CLIENT : S_IDLE;
                    S_CLIENT: if(data >= 8'd48 && data <= 8'd52) begin
                                  client <= data[2:0];
                                  state <= S_COMMA2;
                              end else state <= S_IDLE;
                    S_COMMA2: state <= (data == ",") ? S_LEN : S_IDLE;
                    S_LEN:    if(digit) length <= next_length[12:0];
                              else if(data == ":" && length != 0) begin
                                  left <= length;
                                  state <= S_PAY;
                              end else begin
                                  state <= S_IDLE;
                                  length <= 0;
                              end
                    default:  state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
