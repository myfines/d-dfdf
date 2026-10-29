`timescale 1ns/1ps
// Steady-preset calibration diagnostic. Start real notes, then seed only the
// envelopes to their production sustain to avoid simulating long decays.
// Not a complete note-on/ADSR or acoustic loudness acceptance test.
module tb_timbre_balance;
reg clk=0;always #5 clk=~clk;
reg rst=0,tick=0;reg[31:0]gates=0;
integer cycles=0,frames=0,i,n,v;real squares[0:3],rms[0:3];
wire signed[15:0]pcm[0:3];genvar t;
for(t=0;t<4;t=t+1)begin:tones
 synth32 dut(.clk(clk),.reset_n(rst),.frame_tick(tick),.gate_mask(gates),.timbre(t[1:0]),.velocity(8'd159),.bend(14'sd0),.vibrato(8'd0),.brightness(8'd128),.expression(8'd160),.tremolo(8'd0),.sample(pcm[t]),.custom_adsr(1'b0),.adsr_config(20'd0));
end
always @(posedge clk)begin
 if(cycles==575)begin cycles<=0;tick<=1;frames<=frames+1;end else begin cycles<=cycles+1;tick<=0;end
 if(rst&&tick&&frames>128)for(i=0;i<4;i=i+1)begin
  v=$signed(pcm[i]);if(v>=32000||v<=-32000)$fatal(1,"single-note clipping tone=%0d",i);
  squares[i]=squares[i]+v*v;
 end
end
initial begin
 for(i=0;i<4;i=i+1)squares[i]=0;
 repeat(5)@(negedge clk);rst=1;gates=1;
 wait(frames==64);@(negedge clk);
 tones[0].dut.env_level[0]=tones[0].dut.sustain_level(0);tones[0].dut.env_state[0]=3;
 tones[1].dut.env_level[0]=tones[1].dut.sustain_level(1);tones[1].dut.env_state[0]=3;
 tones[2].dut.env_level[0]=tones[2].dut.sustain_level(2);tones[2].dut.env_state[0]=3;
 tones[3].dut.env_level[0]=tones[3].dut.sustain_level(3);tones[3].dut.env_state[0]=3;
 wait(frames==1152);@(negedge clk);
 for(i=0;i<4;i=i+1)begin rms[i]=$sqrt(squares[i]/1024.0);$display("C3 tone=%0d sustain RMS=%f",i,rms[i]);end
 // Engineering balance policy: piano within4dB and Bass within1.5dB of organ.
 if(rms[0]<rms[1]*0.63)$fatal(1,"piano held sound too quiet relative to organ");
 if(rms[3]<rms[1]*0.84)$fatal(1,"Bass held sound too quiet relative to organ");
 $display("PASS steady preset balance C3, no single-note clipping; seeded sustain diagnostic only");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
