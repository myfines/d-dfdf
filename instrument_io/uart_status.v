`timescale 1ns/1ps
// Readable 115200-8-N-1 telemetry. Each line is a coherent snapshot.
module uart_status #(parameter integer BAUD_TICKS=234,PERIOD_TICKS=6750000)(
    input wire clk,reset_n,valid,error,input wire [11:0] axis_x,axis_y,
    input wire [3:0] keys,input wire scl_level,sda_level,output reg tx);
    localparam IDLE=0,NEW_BYTE=1,SEND_BITS=2;
    reg [1:0] state;
    reg [31:0] period_count;
    reg [15:0] baud_count;
    reg [4:0] character;
    reg [3:0] bit_number,snapshot_keys;
    reg [9:0] shift;
    reg [11:0] snapshot_x,snapshot_y;
    reg [3:0] flags;
    function [7:0] hex_digit;
        input [3:0] value;
        begin hex_digit=value<10?8'h30+{4'd0,value}:8'h41+({4'd0,value}-8'd10);end
    endfunction
    function [7:0] message_byte;
        input [4:0] index;
        begin
            case(index)
                0:message_byte="I";1:message_byte="O";3:message_byte="V";
                4:message_byte=8'h30+{7'd0,flags[0]};
                6:message_byte="E";7:message_byte=8'h30+{7'd0,flags[1]};
                9:message_byte="X";10:message_byte=hex_digit(snapshot_x[11:8]);
                11:message_byte=hex_digit(snapshot_x[7:4]);12:message_byte=hex_digit(snapshot_x[3:0]);
                14:message_byte="Y";15:message_byte=hex_digit(snapshot_y[11:8]);
                16:message_byte=hex_digit(snapshot_y[7:4]);17:message_byte=hex_digit(snapshot_y[3:0]);
                19:message_byte="K";20:message_byte=hex_digit(snapshot_keys);
                22:message_byte="S";23:message_byte=8'h30+{7'd0,flags[2]};
                24:message_byte=8'h30+{7'd0,flags[3]};
                25:message_byte=8'h0d;26:message_byte=8'h0a;
                default:message_byte=8'h20;
            endcase
        end
    endfunction
    always @(posedge clk) begin
        if(!reset_n) begin
            state<=IDLE;period_count<=0;baud_count<=0;character<=0;bit_number<=0;
            snapshot_keys<=15;snapshot_x<=0;snapshot_y<=0;flags<=0;shift<=10'h3ff;tx<=1;
        end else case(state)
            IDLE: begin
                tx<=1;
                if(period_count==PERIOD_TICKS-1) begin
                    period_count<=0;character<=0;state<=NEW_BYTE;
                    snapshot_x<=axis_x;snapshot_y<=axis_y;snapshot_keys<=keys;
                    flags<={sda_level,scl_level,error,valid};
                end else period_count<=period_count+1'b1;
            end
            NEW_BYTE: begin
                shift<={1'b1,message_byte(character),1'b0};tx<=0;
                bit_number<=0;baud_count<=0;state<=SEND_BITS;
            end
            SEND_BITS: if(baud_count==BAUD_TICKS-1) begin
                baud_count<=0;
                if(bit_number==9) begin
                    tx<=1;
                    if(character==26) state<=IDLE;
                    else begin character<=character+1'b1;state<=NEW_BYTE;end
                end else begin tx<=shift[1];shift<={1'b1,shift[9:1]};bit_number<=bit_number+1'b1;end
            end else baud_count<=baud_count+1'b1;
            default:begin state<=IDLE;tx<=1;period_count<=0;end
        endcase
    end
endmodule
