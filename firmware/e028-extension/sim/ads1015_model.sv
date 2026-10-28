`timescale 1ns/1ps
// Event-driven slave model. It decodes bus edges, not controller internals.
module ads1015_model(input wire scl,inout wire sda,input wire enabled,
                     input wire [11:0] code_x,code_y, output integer configs);
    localparam RX=0, ACK_SETUP=1, ACK_HOLD=2, ACK_END=3,
               TX=4, TX_LAST=5, MASTER_ACK=6, MASTER_ACK_END=7, WAIT_STOP=8;
    integer state=WAIT_STOP, bits=0, byte_index=0, tx_bit=7, tx_byte=0;
    reg drive_low=0, addressed=0, reading=0, axis=0;
    reg [7:0] shift=0, ptr=0, cfg_hi=0, value;
    reg [15:0] conversion, config_word;
    assign sda=drive_low?1'b0:1'bz;
    initial configs=0;
    always @(negedge sda) if(scl===1'b1) begin
        state=RX;bits=0;byte_index=0;shift=0;drive_low=0;addressed=0;reading=0;
    end
    always @(posedge sda) if(scl===1'b1) begin state=WAIT_STOP;drive_low=0; end
    always @(posedge scl) begin
        case(state)
            RX: begin
                value={shift[6:0],sda};shift=value;
                if(bits==7) begin
                    bits=0;
                    if(byte_index==0) begin
                        addressed=enabled && value[7:1]==7'h48;reading=value[0];
                        conversion=(axis?code_y:code_x)<<4;
                    end else if(byte_index==1) ptr=value;
                    else if(ptr==1 && byte_index==2) cfg_hi=value;
                    else if(ptr==1 && byte_index==3 && addressed) begin
                        config_word={cfg_hi,value};
                        if(config_word!==16'hc383 && config_word!==16'hd383)
                            $fatal(1,"Wrong ADS config: %h",config_word);
                        axis=cfg_hi[4];configs=configs+1;
                    end
                    byte_index=byte_index+1;state=ACK_SETUP;
                end else bits=bits+1;
            end
            ACK_HOLD: state=ACK_END;
            TX: if(tx_bit==0) state=TX_LAST; else tx_bit=tx_bit-1;
            MASTER_ACK: begin
                if(tx_byte==0 && sda!==0) $fatal(1,"Master must ACK first ADC byte");
                if(tx_byte==1 && sda!==1) $fatal(1,"Master must NACK final ADC byte");
                state=MASTER_ACK_END;
            end
        endcase
    end
    always @(negedge scl) begin
        case(state)
            ACK_SETUP: begin drive_low=addressed;state=ACK_HOLD;end
            ACK_END: begin
                drive_low=0;
                if(!addressed) state=WAIT_STOP;
                else if(reading) begin
                    if(ptr!=0) $fatal(1,"Wrong conversion pointer");
                    tx_byte=0;tx_bit=7;drive_low=~conversion[15];state=TX;
                end else begin state=RX;shift=0;end
            end
            TX: drive_low=~conversion[(tx_byte==0?8:0)+tx_bit];
            TX_LAST: begin drive_low=0;state=MASTER_ACK;end
            MASTER_ACK_END: begin
                if(tx_byte==0) begin tx_byte=1;tx_bit=7;drive_low=~conversion[7];state=TX;end
                else begin drive_low=0;state=WAIT_STOP;end
            end
        endcase
    end
endmodule
