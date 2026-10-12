`timescale 1ns/1ps
// Event-driven slave model. It decodes bus edges, not controller internals.
module optical_sensor_model(input wire scl,inout wire sda,input wire enabled,
 input wire [7:0] sensor_status,output integer configs);
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
                        addressed=enabled && value[7:1]==7'h12;reading=value[0];
                        conversion={sensor_status,8'd0};
                    end else if(byte_index==1)begin ptr=value;if(ptr!==8'h30)$fatal(1,"Wrong optical pointer");end
                    byte_index=byte_index+1;state=ACK_SETUP;
                end else bits=bits+1;
            end
            ACK_HOLD: state=ACK_END;
            TX: if(tx_bit==0) state=TX_LAST; else tx_bit=tx_bit-1;
            MASTER_ACK: begin
                if(sda!==1)$fatal(1,"Master must NACK the only optical byte");configs=configs+1;
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
                    if(ptr!=8'h30)$fatal(1,"Read before optical pointer set");
                    tx_byte=0;tx_bit=7;drive_low=~conversion[15];state=TX;
                end else begin state=RX;shift=0;end
            end
            TX: drive_low=~conversion[(tx_byte==0?8:0)+tx_bit];
            TX_LAST: begin drive_low=0;state=MASTER_ACK;end
            MASTER_ACK_END: begin
                drive_low=0;state=WAIT_STOP;
            end
        endcase
    end
endmodule
