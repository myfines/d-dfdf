`timescale 1ns/1ps
module tb_oled_practice;
 reg clk=0;always #5 clk=~clk;
 tri1 scl,sda;wire online;
 oled_ui dut(.clk(clk),.reset_n(1'b0),.frame_tick(1'b0),.sample_l(16'd0),.sample_r(16'd0),
  .bands(128'd0),.timbre(2'd0),.fx_enable(3'd0),.voices(6'd0),.latency_frames(16'd0),
  .screen(3'd3),.guide_note(5'd12),.guide_step(6'd10),.song_playing(1'b1),.keys_n(8'hff),
  .status(8'd0),.scl(scl),.sda(sda),.online(online),.key_page(2'd0),.key_mapping(160'd0),.guide_valid(1'b1));
 initial begin
  force dut.screen_hold=3;force dut.song_hold=1;force dut.guide_hold=12;force dut.step_hold=10;
  force dut.bank_hold=0;force dut.suggested_hold=1;force dut.guide_valid_hold=1;force dut.found_hold=1;
  force dut.target_hold=0;force dut.keys_hold=8'hff;#1;
  if(dut.text_char(0,5)!="1"||dut.text_char(0,6)!="2"||dut.text_char(0,13)!="1")$fatal(1,"note/current bank header");
  if(dut.text_char(1,0)!="B"||dut.text_char(1,5)!="2")$fatal(1,"bank change hint");
  force dut.target_hold=8'h10;force dut.bank_hold=1;
  force dut.pixel=10'd453;#1; // page3, key5 interior: expected target upper fill
  if(dut.pixels!=8'hff)$fatal(1,"upper expected-key fill");
  force dut.pixel=10'd709;#1; // page5, same key: only bottom outline, no press
  if(dut.pixels!=8'h40)$fatal(1,"target must not look like a held key");
  force dut.keys_hold=8'hef;#1;
  if(dut.pixels!=8'h7f)$fatal(1,"actual key lower fill");
  force dut.target_hold=0;force dut.guide_valid_hold=0;force dut.keys_hold=8'hff;
  force dut.pixel=10'd453;#1;
  if(dut.pixels!=0||dut.text_char(1,0)!="R")$fatal(1,"rest clears target and labels REST");
  force dut.guide_valid_hold=1;force dut.found_hold=0;#1;
  if(dut.text_char(1,0)!="U")$fatal(1,"unmapped note labels UNMAPPED");
  $display("PASS OLED practice renderer: bank/note text, target vs held, rest/unmapped");$finish;
 end
endmodule
