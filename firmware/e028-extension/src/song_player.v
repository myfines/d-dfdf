`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Offline song player / performance guide.
//
// "Ode to Joy" theme, 64 eighth-note steps at 120 BPM (16 s loop), with a
// two-bar bass root.  The player runs entirely inside the FPGA, so pulling the
// phone/Wi-Fi cable does not stop the guide.  It drives:
//   * the 32-voice engine (melody + bass gate mask),
//   * the six on-board LEDs (next key group + beat),
//   * the OLED performance-guide screen.
// -----------------------------------------------------------------------------
module song_player #(
    parameter integer STEP_FRAMES = 11718,
    parameter integer DOWNLOAD_UNIT_FRAMES = 469
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        frame_tick,
    input  wire        enable,
    output reg  [31:0] gate_mask,
    output reg  [4:0]  guide_note,
    output reg  [5:0]  step,
    output reg         beat,
    output reg         playing,
    input wire cmd_valid,input wire [7:0] cmd_kind,input wire [31:0] cmd_value,
    output wire [6:0] loaded_length,output wire loaded_ready
);


    reg [23:0] timer;
    reg [15:0] downloaded[0:63];
    reg [63:0] written;
    reg download_selected,download_ready;
    reg [6:0] download_length;
    assign loaded_length=download_length;assign loaded_ready=download_ready;
    wire [7:0] upload_index=cmd_value[31:24];
    wire [7:0] upload_note=cmd_value[23:16];
    wire [7:0] upload_duration=cmd_value[15:8];
    wire upload_checksum=cmd_value[7:0]==(upload_index^upload_note^upload_duration);
    wire [63:0] required_entries=upload_duration==64?64'hffffffffffffffff:((64'h1<<upload_duration)-1);
    always @(posedge clk)begin
      if(!reset_n)begin written<=0;download_selected<=0;download_ready<=0;download_length<=0;end
      else if(cmd_valid && cmd_kind=="W" && upload_checksum)begin
       if(upload_index==255 && upload_note==0 && upload_duration==0)begin
        written<=0;download_selected<=0;download_ready<=0;
       end else if(upload_index==255 && upload_note==1 && upload_duration>0 && upload_duration<=64 && !enable)begin
        if((written&required_entries)==required_entries)begin download_length<=upload_duration;download_ready<=1;end
       end else if(upload_index<64 && (upload_note<32 || upload_note==255) && upload_duration!=0 && !enable)begin
        downloaded[upload_index[5:0]]<={upload_note,upload_duration};written[upload_index[5:0]]<=1;
        download_selected<=1;download_ready<=0;
       end
      end
    end
    wire [15:0] downloaded_event=downloaded[step];
    wire [23:0] step_frames=download_selected?downloaded_event[7:0]*DOWNLOAD_UNIT_FRAMES:STEP_FRAMES;
    wire effective_enable=enable && (!download_selected || download_ready);
    reg        retrigger;

    function [4:0] melody;
        input [3:0] n;
        begin
            case(n)
                4'd0 : melody = 5'd16; // E4
                4'd1 : melody = 5'd16; // E4
                4'd2 : melody = 5'd17; // F4
                4'd3 : melody = 5'd19; // G4
                4'd4 : melody = 5'd19; // G4
                4'd5 : melody = 5'd17; // F4
                4'd6 : melody = 5'd16; // E4
                4'd7 : melody = 5'd14; // D4
                4'd8 : melody = 5'd12; // C4
                4'd9 : melody = 5'd12; // C4
                4'd10: melody = 5'd14; // D4
                4'd11: melody = 5'd16; // E4
                4'd12: melody = 5'd16; // E4
                4'd13: melody = 5'd14; // D4
                4'd14: melody = 5'd14; // D4
                default: melody = 5'd12; // C4
            endcase
        end
    endfunction

    wire [4:0] current_note = download_selected?downloaded_event[12:8]:melody(step[3:0]);
    wire [4:0] bass_note = step[3] ? 5'd7 : 5'd0; // G3 / C3
    wire [31:0] current_mask = download_selected?(downloaded_event[15:8]==255?32'd0:(32'd1<<current_note)):((32'd1 << current_note) | (32'd1 << bass_note));

    always @(posedge clk) begin
        if(!reset_n) begin
            timer <= 0;
            step <= 0;
            gate_mask <= 0;
            guide_note <= 16;
            beat <= 0;
            playing <= 0;
            retrigger <= 0;
        end else begin
            beat <= 0;
            if(!effective_enable) begin
                timer <= 0;
                step <= 0;
                gate_mask <= 0;
                guide_note <= 16;
                playing <= 0;
                retrigger <= 0;
            end else begin
                playing <= 1;
                if(!playing) begin
                    timer <= 0;
                    step <= 0;
                    gate_mask <= 0;
                    retrigger <= 1;
                end else if(frame_tick) begin
                    if(timer == step_frames-1) begin
                        timer <= 0;
                        step <= download_selected && {1'b0,step}+1>=download_length ? 0 : step + 1'b1;
                        gate_mask <= 0;
                        retrigger <= 1;
                        beat <= (step[1:0] == 2'd3);
                    end else begin
                        timer <= timer + 1'b1;
                        if(retrigger) begin
                            gate_mask <= current_mask;
                            guide_note <= current_note;
                            retrigger <= 0;
                        end
                    end
                end
            end
        end
    end
endmodule
