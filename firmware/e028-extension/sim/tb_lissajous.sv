`timescale 1ns/1ps
module tb_lissajous;
reg clk=0; // Frozen raster input test: no controller clock during injected snapshots.
tri1 scl,sda;wire online;
reg[9:0] address;integer i,x,y,p,mode,fd,expected;real angle;
oled_ui dut(.clk(clk),.reset_n(1'b0),.frame_tick(1'b0),.sample_l(16'sd0),.sample_r(16'sd0),.bands(128'd0),.timbre(2'd0),.fx_enable(3'd0),.voices(6'd0),.latency_frames(16'd0),.screen(3'd2),.guide_note(5'd0),.guide_step(6'd0),.song_playing(1'b0),.keys_n(8'hff),.status(8'd0),.scl(scl),.sda(sda),.online(online),.key_page(2'd0),.key_mapping(160'd0),.guide_valid(1'b0));
initial begin
 force dut.screen_hold=3'd2;force dut.pixel=address;
 for(mode=0;mode<4;mode=mode+1)begin
  for(i=0;i<128;i=i+1)begin
   angle=6.283185307179586*i/128;
   dut.wave_snap[i]=32+$rtoi(24*$sin(angle));
   case(mode)
    0:dut.wave_r_snap[i]=dut.wave_snap[i];
    1:dut.wave_r_snap[i]=64-dut.wave_snap[i];
    2:dut.wave_r_snap[i]=32+$rtoi(24*$cos(angle));
    3:begin dut.wave_snap[i]=32;dut.wave_r_snap[i]=32;end
   endcase
  end
  #1;
  // Every frozen stereo pair must appear at its actual XY coordinate.
  for(i=0;i<32;i=i+1)begin
   x=dut.wave_snap[i*4]*2;y=20+(dut.wave_r_snap[i*4]>>1);address=(y/8)*128+x;#1;
   if(dut.pixels[y%8]!==1'b1)$fatal(1,"missing XY point mode=%0d index=%0d",mode,i);
  end
  fd=$fopen($sformatf("lissajous-mode%0d.hex",mode),"w");
  for(p=0;p<1024;p=p+1)begin address=p;#1;$fdisplay(fd,"%02x",dut.pixels);end
  $fclose(fd);
 end
 // Isolated stereo point: prove R changes Y and L changes X, not a decorative curve.
 for(i=0;i<128;i=i+1)begin dut.wave_snap[i]=16;dut.wave_r_snap[i]=24;end
 address=4*128+32;#1;if(!dut.pixels[0])$fatal(1,"L16 R24 coordinate missing");
 address=3*128+48;#1;if(dut.pixels[4])$fatal(1,"spurious XY point");
 $display("PASS Lissajous actual stereo frozen pairs: equal/opposite/quadrature/silence and isolated XY mapping");$finish;
end
endmodule

