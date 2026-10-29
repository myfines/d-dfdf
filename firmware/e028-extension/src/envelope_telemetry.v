module envelope_telemetry #(parameter integer PERIOD=270000)(
 input wire clk,reset_n,input wire [4:0] slot,input wire [15:0] level,
 input wire [2:0] estate,output wire tx);
 reg [18:0] count;reg [2:0] index;reg sending,start;
 reg [7:0] data,slot_q,hi_q,lo_q,state_q;
 wire busy;
 uart8n1 uart(.clk(clk),.reset_n(reset_n),.rx(1'b1),.tx_start(start),.tx_data(data),
 .tx(tx),.tx_busy(busy),.rx_valid(),.rx_data());
 always @(posedge clk)begin
 if(!reset_n)begin count<=0;index<=0;sending<=0;start<=0;data<=0;slot_q<=0;hi_q<=0;lo_q<=0;state_q<=0;end
 else begin
 start<=0;
 if(count==PERIOD-1)begin
 count<=0;
 if(!sending)begin slot_q<={3'b0,slot};hi_q<=level[15:8];lo_q<=level[7:0];state_q<={5'b0,estate};index<=0;sending<=1;end
 end else count<=count+1'b1;
 if(sending && !busy && !start)begin
 case(index)
 0:data<=8'hA5;1:data<=slot_q;2:data<=hi_q;3:data<=lo_q;4:data<=state_q;
 5:data<=8'hA5^slot_q^hi_q^lo_q^state_q;
 endcase
 start<=1;
 if(index==5)sending<=0;else index<=index+1'b1;
 end
 end
 end
endmodule
