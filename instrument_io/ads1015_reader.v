`timescale 1ns/1ps
// ADS1015 single-shot A0/GND and A1/GND, +/-4.096 V range, 1600 SPS.
// 3.3 V gives about 1650 counts, center about 825. Publish complete X/Y pairs.
module ads1015_reader #(
    parameter integer I2C_HALF_TICKS=135,
    parameter integer CONVERSION_TICKS=27000,
    parameter integer RETRY_TICKS=270000,
    parameter integer BUS_TIMEOUT_TICKS=270000
)(input wire clk,reset_n,inout wire scl,sda,
  output reg [11:0] axis_x,axis_y,output reg valid,error);
    localparam CFG=0,CFG_WAIT=1,CONVERT=2,READ=3,READ_WAIT=4,RETRY=5;
    reg [2:0] state;
    reg axis,start,config_command;
    reg [31:0] timer;
    reg [11:0] pending_x;
    wire busy,done,ok;
    wire [15:0] result;
    wire [31:0] payload=config_command?{8'h01,(axis?8'hd3:8'hc3),8'h83,8'h00}:32'h00000000;
    wire [11:0] positive=result[15]?12'd0:result[15:4];
    wire [11:0] clamped=positive>1650?12'd1650:positive;
    i2c_register_bus #(.HALF_TICKS(I2C_HALF_TICKS),.TIMEOUT_TICKS(BUS_TIMEOUT_TICKS)) bus(
        clk,reset_n,start,payload,(config_command?3'd3:3'd1),(config_command?2'd0:2'd2),
        scl,sda,busy,done,ok,result);
    always @(posedge clk) begin
        if(!reset_n) begin
            state<=CFG;axis<=0;start<=0;config_command<=1;timer<=0;
            pending_x<=825;axis_x<=825;axis_y<=825;valid<=0;error<=0;
        end else begin
            start<=0;
            case(state)
                CFG: if(!busy) begin config_command<=1;start<=1;state<=CFG_WAIT;end
                CFG_WAIT: if(done) begin
                    timer<=0;
                    if(ok) state<=CONVERT;
                    else begin valid<=0;error<=1;state<=RETRY;end
                end
                CONVERT: if(timer==CONVERSION_TICKS-1) begin timer<=0;state<=READ;end
                    else timer<=timer+1'b1;
                READ: if(!busy) begin config_command<=0;start<=1;state<=READ_WAIT;end
                READ_WAIT: if(done) begin
                    if(!ok) begin valid<=0;error<=1;timer<=0;state<=RETRY;end
                    else begin
                        if(!axis) pending_x<=clamped;
                        else begin axis_x<=pending_x;axis_y<=clamped;valid<=1;error<=0;end
                        axis<=~axis;state<=CFG;
                    end
                end
                RETRY: if(timer==RETRY_TICKS-1) begin timer<=0;axis<=0;state<=CFG;end
                    else timer<=timer+1'b1;
                default: begin state<=CFG;axis<=0;valid<=0;error<=1;end
            endcase
        end
    end
endmodule
