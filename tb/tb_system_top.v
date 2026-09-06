`timescale 1ns/1ps

module tb_system_top;

    reg aclk, aresetn;

    reg  [511:0] ext_s0_tdata;
    reg  [63:0]  ext_s0_tkeep;
    reg          ext_s0_tlast, ext_s0_tvalid;
    wire         ext_s0_tready;

    reg  [511:0] ext_s1_tdata;
    reg  [63:0]  ext_s1_tkeep;
    reg          ext_s1_tlast, ext_s1_tvalid;
    wire         ext_s1_tready;

    wire [63:0] lane0_symbols;
    wire [63:0] lane1_symbols;
    wire [63:0] lane2_symbols;
    wire [63:0] lane3_symbols;

    integer pass_count, fail_count;

    system_top dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .ext_s0_tdata  (ext_s0_tdata),
        .ext_s0_tkeep  (ext_s0_tkeep),
        .ext_s0_tlast  (ext_s0_tlast),
        .ext_s0_tvalid (ext_s0_tvalid),
        .ext_s0_tready (ext_s0_tready),
        .ext_s1_tdata  (ext_s1_tdata),
        .ext_s1_tkeep  (ext_s1_tkeep),
        .ext_s1_tlast  (ext_s1_tlast),
        .ext_s1_tvalid (ext_s1_tvalid),
        .ext_s1_tready (ext_s1_tready),
        .lane0_symbols (lane0_symbols),
        .lane1_symbols (lane1_symbols),
        .lane2_symbols (lane2_symbols),
        .lane3_symbols (lane3_symbols)
    );

    initial aclk = 0;
    always #5 aclk = ~aclk;

    initial begin
        $dumpfile("sim/wave_system.vcd");
        $dumpvars(0, tb_system_top);
    end

    // Independent golden model of the Gray-coded PAM4 mapping,
    // reimplemented here (not borrowed from the RTL under test).
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

    task check_equal64;
        input [63:0] actual;
        input [63:0] expected;
        input [255:0] test_name;
        begin
            if (actual === expected) begin
                $display("[PASS] %0s", test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] %0s  (expected=%h actual=%h)", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Drives one 512-bit word into ext_s0_*, polling ext_s0_tready
    // rather than assuming a fixed number of cycles - robust to
    // however long the downstream chain (including the adapter's
    // own internal pacing) actually takes to accept it.
    task send_word;
        input [511:0] data;
        begin
            @(negedge aclk);
            ext_s0_tdata  = data;
            ext_s0_tkeep  = {64{1'b1}};
            ext_s0_tlast  = 1'b0;
            ext_s0_tvalid = 1'b1;

            @(posedge aclk);
            while (ext_s0_tready !== 1'b1) begin
                @(posedge aclk);
            end

            @(negedge aclk);
            ext_s0_tvalid = 1'b0;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // -------------------------------------------------
        // Reset
        // -------------------------------------------------
        aresetn = 0;
        ext_s0_tvalid = 0; ext_s0_tdata = 0; ext_s0_tkeep = 0; ext_s0_tlast = 0;
        ext_s1_tvalid = 0; ext_s1_tdata = 0; ext_s1_tkeep = 0; ext_s1_tlast = 0;

        @(posedge aclk);
        @(posedge aclk);
        if (lane0_symbols === 64'b0 && lane1_symbols === 64'b0 &&
            lane2_symbols === 64'b0 && lane3_symbols === 64'b0)
            $display("[PASS] Reset: all lanes held at 0");
        else
            $display("[FAIL] Reset: lanes not held at 0");

        @(negedge aclk);
        aresetn = 1;

        // -------------------------------------------------
        // Send 4 words -> 8 flits at the link layer -> one full
        // CRC cycle. Each 512-bit word = {high_flit, low_flit}.
        // Flit values chosen to match the known-good pattern:
        // flits 1..7 XOR to 0, so the CRC'd flit 8 collapses to
        // exactly flit 8's own value (0x8 nibble pattern).
        // -------------------------------------------------
        send_word({ {64{4'h1}}, {64{4'h2}} });  // flits 1,2
        send_word({ {64{4'h3}}, {64{4'h4}} });  // flits 3,4
        send_word({ {64{4'h5}}, {64{4'h6}} });  // flits 5,6
        send_word({ {64{4'h7}}, {64{4'h8}} });  // flits 7,8 -> triggers CRC

        // Generous settle time for the last flit to propagate through
        // the packetizer's register stage and the PHY layer's register
        // stage before checking the final result.
        repeat (10) @(posedge aclk);

        // Expected internal system bus value after CRC: {64{4'h8}}
        // (running_crc of flits 1-7 XORs to 0, so 0 ^ flit8 = flit8).
        // All four 64-bit lane chunks are identical since the pattern
        // is uniform across the full 256 bits.
        check_equal64(lane0_symbols, expected_symbols(64'h8888888888888888), "System: lane0 final symbols");
        check_equal64(lane1_symbols, expected_symbols(64'h8888888888888888), "System: lane1 final symbols");
        check_equal64(lane2_symbols, expected_symbols(64'h8888888888888888), "System: lane2 final symbols");
        check_equal64(lane3_symbols, expected_symbols(64'h8888888888888888), "System: lane3 final symbols");

        // -------------------------------------------------
        // Summary
        // -------------------------------------------------
        #20;
        $display("--------------------------------------------------");
        $display("TEST SUMMARY: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
