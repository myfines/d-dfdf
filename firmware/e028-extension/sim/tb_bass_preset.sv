`timescale 1ns/1ps
module tb_bass_preset;
reg clk=0;always #5 clk=~clk;reg rst=0,tick=0;reg[31:0]gates=0;
integer cycle=0,frames=0,peak=0,n=0,v;real squares=0,rms;
wire signed[15:0]sample;wire active,note_on;wire[5:0]count;wire[4:0]idx;wire[15:0]lat;
synth32 dut(.clk(clk),.reset_n(rst),.frame_tick(tick),.gate_mask(gates),.timbre(2'd3),.velocity(8'd159),.bend(14'sd0),.vibrato(8'd0),.brightness(8'd128),.expression(8'd255),.tremolo(8'd0),.sample(sample),.active(active),.voice_count(count),.note_on(note_on),.note_on_index(idx),.latency_frames(lat),.custom_adsr(1'b0),.adsr_config(20'd0));
always @(posedge clk)begin
 if(cycle==575)begin cycle<=0;tick<=1;frames<=frames+1;end else begin cycle<=cycle+1;tick<=0;end
 if(tick && frames>11000)begin v=sample;if(v<0)v=-v;if(v>peak)peak=v;squares=squares+v*v;n=n+1;end
end
initial begin repeat(4)@(negedge clk);rst=1;gates=32'h1000;
 wait(frames==12000);#1;rms=$sqrt(squares/n);
 if(dut.env_state[12]!=3 || dut.env_level[12]<32000)$fatal(1,"Bass hold not settled at useful level");
 if(rms<500||peak>=32000)$fatal(1,"Bass settled PCM too weak or clipping: rms=%f peak=%0d",rms,peak);
 if(count!=1||!active)$fatal(1,"Bass voice not active");
 $display("PASS Bass actual note-on to settled PCM: rms=%f peak=%0d level=%0d; default velocity159, dry C4; not acoustic measurement",rms,peak,dut.env_level[12]);$finish;
end
initial begin #100000000;$fatal(1,"Bass timeout");end
endmodule

