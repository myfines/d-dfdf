`timescale 1ns/1ps
// Standard I2S: 16-bit stereo slots, MSB one BCLK after each WS edge.
// 27 MHz / (2*9*32) = 46,875 stereo frames/s. PCM5102A accepts 32fs BCLK.
module i2s_tx16 #(parameter integer HALF_PERIOD=9)(
    input wire clk,reset_n,
    input wire signed [15:0] sample_l,sample_r,
    output reg bck,ws,data,output wire frame_tick
);
    reg [15:0] divider;
    reg [4:0] position;
    reg [15:0] frame_l,frame_r;
    assign frame_tick=reset_n && divider==HALF_PERIOD-1 && bck && position==0;
    always @(posedge clk) begin
        if(!reset_n) begin
            divider<=0;position<=0;frame_l<=0;frame_r<=0;
            bck<=0;ws<=1;data<=0;
        end else if(divider==HALF_PERIOD-1) begin
            divider<=0;bck<=~bck;
            if(bck) begin
                ws<=position[4];position<=position+1'b1;
                if(position==0) begin
                    data<=frame_r[0]; // Previous right LSB is the left WS delay bit.
                    frame_l<=sample_l;frame_r<=sample_r;
                end else if(position<=16) data<=frame_l[16-position];
                else data<=frame_r[32-position];
            end
        end else divider<=divider+1'b1;
    end
endmodule
