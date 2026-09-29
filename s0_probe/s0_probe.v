// SRAM-only probe: maps the SSPI dual-purpose pin T10 to an input.
// A press should light LED N14; N16 keeps blinking to show configuration alive.
module s0_probe(
    input wire clk,
    input wire s0_n,
    output wire LED_HEARTBEAT,
    output wire LED_S0
);
    reg [23:0] heartbeat = 24'd0;
    reg [1:0] s0_sync = 2'b11;

    always @(posedge clk) begin
        heartbeat <= heartbeat + 24'd1;
        s0_sync <= {s0_sync[0], s0_n};
    end

    // The Dock LEDs illuminate when driven low.
    assign LED_HEARTBEAT = heartbeat[23];
    assign LED_S0 = s0_sync[1];
endmodule
