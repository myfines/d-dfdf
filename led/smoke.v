module smoke(input clk, output reg led);
  reg [23:0] count = 0;
  always @(posedge clk) begin
    count <= count + 1'b1;
    led <= count[23];
  end
endmodule
