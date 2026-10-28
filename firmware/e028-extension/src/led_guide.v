`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Four on-board user LEDs (L16 L14 N14 N16) as an offline performance guide.
//
// A13/C13 are dedicated READY/DONE pins on the GW2A-18 package, so only four
// LEDs are usable.  The eight optical keys are therefore grouped in pairs:
//
//   song mode : LED0 = keys 0/1, LED1 = 2/3, LED2 = 4/5, LED3 = 6/7
//               the target pair is bright; on a beat all four flash
//   free play : LEDs 0..3 are a voice-activity bar; LED3 is the heartbeat
//
// The OLED guide screen still shows the exact key within the pair, so the LED
// bar is a coarse "where to go next" indicator, not the only feedback.
// -----------------------------------------------------------------------------
module led_guide(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       frame_tick,
    input  wire       playing,
    input  wire [4:0] guide_note,
    input  wire       beat,
    input  wire [5:0] active_voices,
    input  wire [23:0] heartbeat,
    output reg  [3:0] led
);

    reg [7:0] pwm;
    reg [7:0] bright [0:3];
    reg [1:0] group;
    reg [2:0] bar;
    integer i;

    always @* begin
        group = guide_note[2:1];
        bar = active_voices[5:3];
        if(bar > 3'd3) bar = 3'd3;
        if(active_voices != 0 && bar == 0) bar = 3'd1;
    end

    always @(posedge clk) begin
        if(!reset_n) begin
            pwm <= 0;
            for(i = 0; i < 4; i = i + 1) bright[i] <= 0;
        end else begin
            pwm <= pwm + 1'b1;
            if(frame_tick) begin
                if(playing) begin
                    for(i = 0; i < 4; i = i + 1)
                        bright[i] <= beat ? 8'd230 :
                                     (i[1:0] == group ? 8'd220 : 8'd10);
                end else begin
                    for(i = 0; i < 4; i = i + 1)
                        bright[i] <= (i < bar) ? 8'd190 : 8'd0;
                    if(bar == 0) bright[3] <= heartbeat[22] ? 8'd70 : 8'd0;
                end
            end
        end
    end

    always @* begin
        for(i = 0; i < 4; i = i + 1)
            led[i] = (pwm < bright[i]);
    end
endmodule
