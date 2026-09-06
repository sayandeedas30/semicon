`timescale 1ns/1ps

module bridge_subsystem_top_tb;
    reg clk;
    reg rst_n;
    reg [255:0] raw_link_data_in;
    reg link_valid_in;

    wire [63:0] lane0_symbols;
    wire [63:0] lane1_symbols;
    wire [63:0] lane2_symbols;
    wire [63:0] lane3_symbols;

    integer errors = 0;

    // Instantiate the Top-Level Integrated Subsystem
    bridge_subsystem_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .raw_link_data_in(raw_link_data_in),
        .link_valid_in(link_valid_in),
        .lane0_symbols(lane0_symbols),
        .lane1_symbols(lane1_symbols),
        .lane2_symbols(lane2_symbols),
        .lane3_symbols(lane3_symbols)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Independent golden model of the Gray-coded PAM4 mapping (same table
    // as gray_pam4_mapper, reimplemented here so the check doesn't just
    // trust the RTL it's verifying).
    function [63:0] expected_symbols;
        input [63:0] chunk;
        integer i;
        reg [1:0] pair;
        begin
            for (i = 0; i < 64; i = i + 2) begin
                pair = chunk[i +: 2];
                case (pair)
                    2'b00: expected_symbols[i +: 2] = 2'b00;
                    2'b01: expected_symbols[i +: 2] = 2'b01;
                    2'b10: expected_symbols[i +: 2] = 2'b11;
                    2'b11: expected_symbols[i +: 2] = 2'b10;
                endcase
            end
        end
    endfunction

    task check_lanes_all;
        input [255:0] bus_snapshot;
        input [319:0] tag;
        reg [63:0] exp0, exp1, exp2, exp3;
        begin
            exp0 = expected_symbols(bus_snapshot[63:0]);
            exp1 = expected_symbols(bus_snapshot[127:64]);
            exp2 = expected_symbols(bus_snapshot[191:128]);
            exp3 = expected_symbols(bus_snapshot[255:192]);

            if (lane0_symbols !== exp0 || lane1_symbols !== exp1 ||
                lane2_symbols !== exp2 || lane3_symbols !== exp3) begin
                $display("[%0t] FAIL (%0s)", $time, tag);
                $display("        lane0: got %h expected %h", lane0_symbols, exp0);
                $display("        lane1: got %h expected %h", lane1_symbols, exp1);
                $display("        lane2: got %h expected %h", lane2_symbols, exp2);
                $display("        lane3: got %h expected %h", lane3_symbols, exp3);
                errors = errors + 1;
            end else begin
                $display("[%0t] PASS (%0s)", $time, tag);
            end
        end
    endtask

    // Debug visibility into the internal link<->PHY handoff
    always @(posedge clk) begin
        if (rst_n)
            $display("[%0t] internal_valid=%b internal_system_bus=%h",
                      $time, uut.internal_valid, uut.internal_system_bus);
    end

    initial begin
        // Setup VCD waveform generation for the subsystem
        $dumpfile("subsystem_wave.vcd");
        $dumpvars(0, bridge_subsystem_top_tb);

        clk = 0;
        rst_n = 0;
        raw_link_data_in = 256'b0;
        link_valid_in = 0;

        // --- Reset check ---
        repeat (2) @(negedge clk);
        if (lane0_symbols !== 64'b0 || lane1_symbols !== 64'b0 ||
            lane2_symbols !== 64'b0 || lane3_symbols !== 64'b0) begin
            $display("[%0t] FAIL (reset) lanes not held at 0", $time);
            errors = errors + 1;
        end else begin
            $display("[%0t] PASS (reset) lanes held at 0", $time);
        end
        rst_n = 1;

        // --- Feed an 8-flit stream to exercise the Link Layer packetizer
        //     and CRC generation, then flow through to the PHY layer. ---
        @(negedge clk);
        link_valid_in = 1;
        raw_link_data_in = {64{4'h1}}; // flit 1

        @(negedge clk); raw_link_data_in = {64{4'h2}}; // flit 2
        @(negedge clk); raw_link_data_in = {64{4'h3}}; // flit 3
        @(negedge clk); raw_link_data_in = {64{4'h4}}; // flit 4
        @(negedge clk); raw_link_data_in = {64{4'h5}}; // flit 5
        @(negedge clk); raw_link_data_in = {64{4'h6}}; // flit 6
        @(negedge clk); raw_link_data_in = {64{4'h7}}; // flit 7
        @(negedge clk); raw_link_data_in = {64{4'h8}}; // flit 8: triggers CRC append

        // Two extra cycles: 1 for the packetizer to register the CRC'd
        // flit, 1 more for the PHY layer to register the mapped symbols.
        @(negedge clk);
        @(negedge clk);

        // XOR of nibbles 1..7 is 0 (XOR of a complete 3-bit range is 0),
        // so the CRC'd 8th flit collapses to 0x88...8 exactly.
        check_lanes_all({64{4'h8}}, "post-8-flit-burst (CRC applied)");

        // --- Stop transmission: lanes must hold their last value ---
        @(negedge clk);
        link_valid_in = 0;
        raw_link_data_in = {64{4'h9}}; // should never reach the lanes

        @(negedge clk);
        @(negedge clk);
        check_lanes_all({64{4'h8}}, "hold-after-valid-deasserted");

        #20;
        if (errors == 0)
            $display("=== ALL TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule