`timescale 1ns/1ps
// Normalize known joystick/gesture range0..1650 without truncation wrap.
// Velocity uses the engine's unsigned8 range, independent of MIDI conventions.
module performance_controls(input wire[11:0] axis_y,gesture_color,
 input wire controls_valid,gesture_active,output wire[7:0] velocity,brightness);
 wire[11:0] y=axis_y>1650?12'd1650:axis_y;
 wire[11:0] color=gesture_color>1650?12'd1650:gesture_color;
 wire[19:0] velocity_product=y*8'd119;
 wire[19:0] color_product=color*8'd159;
 wire[9:0] velocity_scaled=10'd64+{2'd0,velocity_product[19:10]};
 wire[9:0] color_scaled=color_product[19:10];
 assign velocity=!controls_valid?8'd192:velocity_scaled>255?8'd255:velocity_scaled[7:0];
 assign brightness=!gesture_active?8'd128:color_scaled>255?8'd255:color_scaled[7:0];
endmodule
