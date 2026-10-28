module tb;
reg signed [15:0] q;
wire signed [17:0] original = (({{2{q[15]}},q} * 18'sd3) >>> 3);
wire signed [17:0] signed_reference = (($signed({{2{q[15]}},q}) * 18'sd3) >>> 3);
initial begin
q=8000;#1;$display("positive original=%0d reference=%0d",original,signed_reference);
q=-8000;#1;$display("negative original=%0d reference=%0d",original,signed_reference);
if(original != signed_reference) $display("FAIL current delay feedback has unsigned shift on negative samples");
$finish;end
endmodule
