`timescale 1ns/1ps
// Standalone diagnostic candidate. Does not synthesize instrument audio.
module host_probe_top(input wire clk,input wire ulpi_clk,ulpi_dir,ulpi_nxt,
 inout wire [7:0] ulpi_data,output wire ulpi_stp,ulpi_rst,
 output wire LED_ALIVE,LED_ADC,PA_EN,PCM_BCK,PCM_LRCK,PCM_DATA,
 output wire HP_BCK,HP_WS,HP_DIN,UART_TX);
 reg [19:0] power_count=0;
 always @(posedge clk)if(!power_count[19])power_count<=power_count+1'b1;
 // USB3317 RESETB is active-low (DS00002366A, pin table).
 assign ulpi_rst=power_count[19];
 // USB3317 ULPI protocol uses the rising edge.
 wire usb_core_clk,usb_pll_locked; wire pll_base;
`ifdef PROBE_SIM
 assign usb_core_clk=ulpi_clk;
 assign usb_pll_locked=ulpi_rst;
`else
 // CLKOUTP is advanced 45 degrees (315 degrees modulo one period).
 rPLL #(.FCLKIN("60"),.IDIV_SEL(0),.FBDIV_SEL(0),.ODIV_SEL(16),
   .CLKFB_SEL("internal"),.PSDA_SEL("1110"),.DUTYDA_SEL("1000"),.DEVICE("GW2A-18C")) usb_pll(
   .CLKIN(ulpi_clk),.CLKFB(1'b0),.CLKOUT(pll_base),.CLKOUTP(usb_core_clk),.LOCK(usb_pll_locked),
   .RESET(~ulpi_rst),.RESET_P(1'b0),.FBDSEL(6'd0),.IDSEL(6'd0),.ODSEL(6'd0),
   .PSDA(4'd0),.DUTYDA(4'd0),.FDLY(4'd0));
`endif
 reg [1:0] usb_reset=2'b11;
 always @(posedge usb_core_clk or negedge usb_pll_locked)
  if(!usb_pll_locked)usb_reset<=2'b11;
  else usb_reset<={usb_reset[0],~ulpi_rst};
 wire [7:0] data_o,data;wire oe,valid,ready,active,update;
 reg ready_q=0,valid_q=0;reg [7:0] data_q=0;
 always @(posedge usb_core_clk)begin
  if(usb_reset[1])begin ready_q<=0;valid_q<=0;data_q<=0;end
  else begin ready_q<=ready;valid_q<=valid;data_q<=data;end
 end
 wire [7:0] seq,confidence;wire [9:0] pinch,y;
 assign ulpi_data=(ulpi_rst && !usb_reset[1] && oe)?data_o:8'bz;
 k230_usb_host_generated host(.usb_clk(usb_core_clk),.usb_rst(usb_reset[1]),
  .ulpi_data_i(ulpi_data),.ulpi_data_o(data_o),.ulpi_data_oe(oe),
  .ulpi_dir(ulpi_dir),.ulpi_nxt(ulpi_nxt),.ulpi_stp(ulpi_stp),
  .data__valid(valid),.data__payload(data),.data__ready(1'b1),.ready(ready));
 gesture_packet_rx #(.LEASE_TICKS(15000000),.GAP_TICKS(1200000)) parser(
  usb_core_clk,~usb_reset[1] && ready_q,valid_q,data_q,active,update,seq,pinch,y,confidence);
 reg [25:0] heartbeat=0;
 always @(posedge usb_core_clk)heartbeat<=heartbeat+1'b1;
 assign LED_ALIVE=heartbeat[25];assign LED_ADC=active | (ready && heartbeat[23]);
 // Nine-byte diagnostic: A6 seq flags confidence pinchBE yBE XOR(bytes0..7).
 // flags bit0=gesture active, bit1=CDC configured/ready.
 reg [63:0] report;reg [7:0] check;reg [3:0] report_index=0;
 reg tx_start=0;wire tx_busy;wire [7:0] tx_data=report_index==9?check:report[63:56];
 wire [63:0] next_report={8'ha6,seq,{6'd0,ready,active},confidence,{6'd0,pinch[9:8]},pinch[7:0],{6'd0,y[9:8]},y[7:0]};
 uart8n1 #(.BIT_TICKS(521)) diagnostic(.clk(usb_core_clk),.reset_n(~usb_reset[1]),.rx(1'b1),.tx_start(tx_start),.tx_data(tx_data),.tx(UART_TX),.tx_busy(tx_busy));
 always @(posedge usb_core_clk)begin
  if(usb_reset[1])begin report_index<=0;tx_start<=0;report<=0;check<=0;end
  else begin
   tx_start<=0;
   // Periodic reports permit a read-only clock/aliveness check without K230.
   if((update || heartbeat[23:0]==0) && report_index==0)begin
    report<=next_report;check<=next_report[63:56]^next_report[55:48]^next_report[47:40]^next_report[39:32]^next_report[31:24]^next_report[23:16]^next_report[15:8]^next_report[7:0];report_index<=1;
   end else if(report_index!=0 && !tx_busy && !tx_start)tx_start<=1;
   // uart samples tx_start on the following edge; advance only after that edge.
   if(tx_start)begin
    if(report_index==9)report_index<=0;
    else begin report_index<=report_index+1'b1;report<={report[55:0],8'd0};end
   end
  end
 end
 // Explicitly hold existing external/Dock audio outputs inactive.
 assign PA_EN=0;assign PCM_BCK=0;assign PCM_LRCK=0;assign PCM_DATA=0;
 assign HP_BCK=0;assign HP_WS=0;assign HP_DIN=0;
endmodule
