`timescale 1ns/1ps
// One bounded open-drain transaction: address-W + payload, optional repeated
// START + address-R + up to two bytes. Only low or high-impedance is driven.
module i2c_register_bus #(
    parameter integer HALF_TICKS=135,
    parameter integer TIMEOUT_TICKS=270000,
    parameter [6:0] ADDRESS=7'h48
)(
    input wire clk,reset_n,start,
    input wire [31:0] payload,
    input wire [2:0] payload_count,
    input wire [1:0] read_count,
    inout wire scl,sda,
    output reg busy,done,ok,
    output reg [15:0] read_data
);
    localparam IDLE=0,BUS_WAIT=1,START_HOLD=2,BIT_LOW=3,BIT_HIGH=4,
        ACK_LOW=5,ACK_HIGH=6,REP_LOW=7,REP_HIGH=8,REP_START=9,
        READ_LOW=10,READ_HIGH=11,MACK_LOW=12,MACK_HIGH=13,
        STOP_LOW=14,STOP_HIGH=15,STOP_RELEASE=16,REC_LOW=17,REC_HIGH=18;
    reg [4:0] state;
    reg scl_low,sda_low,scl_meta,scl_sync,sda_meta,sda_sync;
    reg [31:0] hold_count,watchdog,tx_payload;
    reg [7:0] tx_byte,rx_byte;
    reg [2:0] bits_left,bytes_left;
    reg [3:0] recovery_count;
    reg [1:0] kind,reads_total,read_index;
    reg transaction_ok;
    assign scl=scl_low?1'b0:1'bz;
    assign sda=sda_low?1'b0:1'bz;
    wire wait_high=(state==BUS_WAIT || state==START_HOLD || state==BIT_HIGH ||
        state==ACK_HIGH || state==REP_HIGH || state==REP_START || state==READ_HIGH ||
        state==MACK_HIGH || state==STOP_HIGH || state==STOP_RELEASE || state==REC_HIGH);
    always @(posedge clk) begin
        if(!reset_n) begin
            state<=IDLE;busy<=0;done<=0;ok<=0;read_data<=0;
            scl_low<=0;sda_low<=0;hold_count<=0;watchdog<=0;
            scl_meta<=1;scl_sync<=1;sda_meta<=1;sda_sync<=1;
            tx_payload<=0;tx_byte<=0;rx_byte<=0;bits_left<=7;
            bytes_left<=0;kind<=0;reads_total<=0;read_index<=0;
            recovery_count<=0;transaction_ok<=0;
        end else begin
            scl_meta<=scl;scl_sync<=scl_meta;sda_meta<=sda;sda_sync<=sda_meta;
            done<=0;
            if(!busy) begin
                scl_low<=0;sda_low<=0;hold_count<=0;watchdog<=0;
                if(start) begin
                    if(payload_count>4 || read_count>2) begin done<=1;ok<=0;end
                    else begin
                        busy<=1;ok<=0;read_data<=0;transaction_ok<=1;
                        tx_payload<=payload;bytes_left<=payload_count;reads_total<=read_count;
                        kind<=0;read_index<=0;rx_byte<=0;bits_left<=7;
                        tx_byte<={ADDRESS,1'b0};state<=BUS_WAIT;
                    end
                end
            end else if(wait_high && !scl_sync) begin
                // A stretched clock must first rise, then stay high for HALF_TICKS.
                hold_count<=0;
                if(watchdog==TIMEOUT_TICKS-1) begin
                    busy<=0;done<=1;ok<=0;state<=IDLE;scl_low<=0;sda_low<=0;
                end else watchdog<=watchdog+1'b1;
            end else begin
                watchdog<=0;
                if(hold_count!=HALF_TICKS-1) hold_count<=hold_count+1'b1;
                else begin
                    hold_count<=0;
                    case(state)
                        BUS_WAIT: if(sda_sync) begin sda_low<=1;state<=START_HOLD;end
                            else begin // Nine recovery clocks and a STOP; retry is the caller's job.
                                transaction_ok<=0;recovery_count<=0;scl_low<=1;state<=REC_LOW;
                            end
                        START_HOLD,REP_START: begin
                            scl_low<=1;sda_low<=~tx_byte[7];bits_left<=7;state<=BIT_LOW;
                        end
                        BIT_LOW: begin scl_low<=0;state<=BIT_HIGH;end
                        BIT_HIGH: begin
                            scl_low<=1;
                            if(bits_left==0) begin sda_low<=0;state<=ACK_LOW;end
                            else begin bits_left<=bits_left-1'b1;sda_low<=~tx_byte[bits_left-1'b1];state<=BIT_LOW;end
                        end
                        ACK_LOW: begin scl_low<=0;state<=ACK_HIGH;end
                        ACK_HIGH: begin
                            scl_low<=1;
                            if(sda_sync) begin transaction_ok<=0;sda_low<=1;state<=STOP_LOW;end
                            else if(kind==2) begin
                                sda_low<=0;bits_left<=7;rx_byte<=0;state<=READ_LOW;
                            end else if(bytes_left!=0) begin
                                kind<=1;tx_byte<=tx_payload[31:24];tx_payload<=tx_payload<<8;
                                bytes_left<=bytes_left-1'b1;bits_left<=7;
                                sda_low<=~tx_payload[31];state<=BIT_LOW;
                            end else if(reads_total!=0) begin
                                kind<=2;tx_byte<={ADDRESS,1'b1};sda_low<=0;state<=REP_LOW;
                            end else begin sda_low<=1;state<=STOP_LOW;end
                        end
                        REP_LOW: begin scl_low<=0;state<=REP_HIGH;end
                        REP_HIGH: begin sda_low<=1;state<=REP_START;end
                        READ_LOW: begin scl_low<=0;state<=READ_HIGH;end
                        READ_HIGH: begin
                            scl_low<=1;rx_byte<={rx_byte[6:0],sda_sync};
                            if(bits_left==0) begin
                                if(read_index==0) read_data[15:8]<={rx_byte[6:0],sda_sync};
                                else read_data[7:0]<={rx_byte[6:0],sda_sync};
                                sda_low<=(read_index+1'b1<reads_total);state<=MACK_LOW;
                            end else begin bits_left<=bits_left-1'b1;state<=READ_LOW;end
                        end
                        MACK_LOW: begin scl_low<=0;state<=MACK_HIGH;end
                        MACK_HIGH: begin
                            scl_low<=1;
                            if(read_index+1'b1<reads_total) begin
                                read_index<=read_index+1'b1;sda_low<=0;bits_left<=7;rx_byte<=0;state<=READ_LOW;
                            end else begin sda_low<=1;state<=STOP_LOW;end
                        end
                        STOP_LOW: begin scl_low<=0;state<=STOP_HIGH;end
                        STOP_HIGH: begin sda_low<=0;state<=STOP_RELEASE;end
                        STOP_RELEASE: begin busy<=0;done<=1;ok<=transaction_ok;state<=IDLE;end
                        REC_LOW: begin scl_low<=0;state<=REC_HIGH;end
                        REC_HIGH: begin
                            scl_low<=1;
                            if(recovery_count==8) begin sda_low<=1;state<=STOP_LOW;end
                            else begin recovery_count<=recovery_count+1'b1;state<=REC_LOW;end
                        end
                        default: begin busy<=0;done<=1;ok<=0;state<=IDLE;scl_low<=0;sda_low<=0;end
                    endcase
                end
            end
        end
    end
endmodule
