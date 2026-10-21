`timescale 1ns/1ps
module tb_pll_phase;
 reg clock=0,reset=1;
 always #8.3335 clock=~clock;
 wire base,phase,locked;
 rPLL #(.FCLKIN("60"),.IDIV_SEL(0),.FBDIV_SEL(0),.ODIV_SEL(16),
   .CLKFB_SEL("internal"),.PSDA_SEL("1110"),.DUTYDA_SEL("1000"),.DEVICE("GW2A-18C")) pll(
   .CLKIN(clock),.CLKFB(1'b0),.CLKOUT(base),.CLKOUTP(phase),.LOCK(locked),
   .RESET(reset),.RESET_P(1'b0),.FBDSEL(6'd0),.IDSEL(6'd0),.ODSEL(6'd0),
   .PSDA(4'd0),.DUTYDA(4'd0),.FDLY(4'd0));
 realtime base_edge,phase_edge,phase_fall,next_edge,delta;
 initial begin
  #100;reset=0;wait(locked);repeat(10)@(posedge base);
  base_edge=$realtime;@(posedge phase);phase_edge=$realtime;
  delta=phase_edge-base_edge;
  if(delta<14.4||delta>14.8)$fatal(1,"PLL phase mismatch %f ns",delta);
  @(negedge phase);phase_fall=$realtime;
  @(posedge phase);next_edge=$realtime;
   $display("MEASURE delta=%f high=%f period=%f",delta,phase_fall-phase_edge,next_edge-phase_edge);
  if(phase_fall-phase_edge<8.1||phase_fall-phase_edge>8.6)$fatal(1,"PLL duty");
  if(next_edge-phase_edge<16.4||next_edge-phase_edge>16.9)$fatal(1,"PLL frequency");
  $display("PASS vendor rPLL model: period=%f phase315=%f high=%f ns",next_edge-phase_edge,delta,phase_fall-phase_edge);$finish;
 end
 initial begin #1000000;$fatal(1,"PLL did not lock");end
endmodule
