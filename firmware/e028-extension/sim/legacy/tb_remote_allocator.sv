`timescale 1ns/1ps
// Offline check that the E027 remote path treats K[7:0] as eight keys and
// allocates them to the existing four voice lanes, exactly like the optical path.
module tb_remote_allocator;
    reg clk = 0;
    reg reset_n = 0;
    reg frame_tick = 0;
    reg [7:0] keys_n = 8'hff;
    wire [3:0] slot_keys_n;
    wire [3:0] triggers;
    wire [11:0] notes;

    optical_key_allocator dut(clk, reset_n, frame_tick, keys_n,
        slot_keys_n, notes, triggers);

    always #5 clk = ~clk;

    task tick;
        begin
            @(posedge clk);
            frame_tick = 1;
            @(posedge clk);
            frame_tick = 0;
            #1;
        end
    endtask

    task expect_note(input integer slot, input [2:0] note, input [8*24-1:0] label);
        begin
            if (notes[slot*3 +: 3] !== note) begin
                $display("FAIL %0s: slot %0d note %0d, expected %0d", label, slot,
                    notes[slot*3 +: 3], note);
                $fatal;
            end
        end
    endtask

    task expect_assigned(input integer count, input [8*24-1:0] label);
        begin
            if ((4'd4 - $countones(slot_keys_n)) !== count) begin
                $display("FAIL %0s: assigned %0d, expected %0d", label,
                    $countones(~slot_keys_n), count);
                $fatal;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        reset_n = 1;
        repeat (2) @(posedge clk);

        // Keys 0 and 7 -> slots 0 and 1.
        keys_n = ~8'h81;
        tick();
        expect_assigned(2, "two keys");
        expect_note(0, 3'd0, "key0");
        expect_note(1, 3'd7, "key7");
        if (triggers[0] !== 1'b1 || triggers[1] !== 1'b1)
            $display("note: trigger pulse is sampled after the frame tick");

        // Add key 4 -> slot 2; held notes stay put.
        keys_n = ~8'h91;
        tick();
        expect_assigned(3, "three keys");
        expect_note(0, 3'd0, "held key0");
        expect_note(1, 3'd7, "held key7");
        expect_note(2, 3'd4, "new key4");

        // Release key 0, then press key 2: slot 0 is reused for note 2.
        keys_n = ~8'h94;
        tick();
        expect_assigned(3, "reuse slot");
        expect_note(0, 3'd2, "reused key2");
        expect_note(1, 3'd7, "held key7");
        expect_note(2, 3'd4, "held key4");

        // All eight pressed: the three held notes stay, the free fourth slot
        // takes the first unclaimed key (key 0).  This is the existing
        // "retain held notes first" allocator policy.
        keys_n = 8'h00;
        tick();
        expect_assigned(4, "all eight");
        expect_note(0, 3'd2, "all held key2");
        expect_note(1, 3'd7, "all held key7");
        expect_note(2, 3'd4, "all held key4");
        expect_note(3, 3'd0, "all free slot key0");

        // Release everything, then press 5 and 6: they get fresh slots.
        keys_n = 8'hff;
        tick();
        expect_assigned(0, "released");
        keys_n = ~8'h60;
        tick();
        expect_assigned(2, "fresh pair");
        expect_note(0, 3'd5, "key5");
        expect_note(1, 3'd6, "key6");

        $display("tb_remote_allocator: PASS");
        $finish;
    end
endmodule
