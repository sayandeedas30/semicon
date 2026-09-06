`timescale 1ns/1ps

module pcie_phy_layer_tb;
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [255:0] system_bus_in;
    wire [63:0] lane0_symbols;
    wire [63:0] lane1_symbols;
    wire [63:0] lane2_symbols;
    wire [63:0] lane3_symbols;

    integer errors = 0;

    pcie_phy_layer uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .system_bus_in(system_bus_in),
        .lane0_symbols(lane0_symbols),
        .lane1_symbols(lane1_symbols),
        .lane2_symbols(lane2_symbols),
        .lane3_symbols(lane3_symbols)
    );

    always #5 clk = ~clk;

    // Independent (golden) model of the Gray-coded PAM4 mapping, used to
    // self-check the RTL rather than just eyeballing waveforms.
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

    task check_lanes;
        input [255:0] bus_snapshot;
        input [127:0] tag; // short label for messages
        reg [63:0] exp0, exp1, exp2, exp3;
        begin
            exp0 = expected_symbols(bus_snapshot[63:0]);
            exp1 = expected_symbols(bus_snapshot[127:64]);
            exp2 = expected_symbols(bus_snapshot[191:128]);
            exp3 = expected_symbols(bus_snapshot[255:192]);

            if (lane0_symbols !== exp0) begin
                $display("[%0t] FAIL (%0s) lane0: got %h expected %h", $time, tag, lane0_symbols, exp0);
                errors = errors + 1;
            end
            if (lane1_symbols !== exp1) begin
                $display("[%0t] FAIL (%0s) lane1: got %h expected %h", $time, tag, lane1_symbols, exp1);
                errors = errors + 1;
            end
            if (lane2_symbols !== exp2) begin
                $display("[%0t] FAIL (%0s) lane2: got %h expected %h", $time, tag, lane2_symbols, exp2);
                errors = errors + 1;
            end
            if (lane3_symbols !== exp3) begin
                $display("[%0t] FAIL (%0s) lane3: got %h expected %h", $time, tag, lane3_symbols, exp3);
                errors = errors + 1;
            end
            if (lane0_symbols === exp0 && lane1_symbols === exp1 &&
                lane2_symbols === exp2 && lane3_symbols === exp3) begin
                $display("[%0t] PASS (%0s)", $time, tag);
            end
        end
    endtask

    initial begin
        $dumpfile("phy_layer_wave.vcd");
        $dumpvars(0, pcie_phy_layer_tb);

        clk = 0;
        rst_n = 0;
        valid_in = 0;
        system_bus_in = 256'b0;

        // --- Reset check: hold reset for two full cycles ---
        repeat (2) @(negedge clk);
        if (lane0_symbols !== 64'b0 || lane1_symbols !== 64'b0 ||
            lane2_symbols !== 64'b0 || lane3_symbols !== 64'b0) begin
            $display("[%0t] FAIL (reset) lanes not held at 0", $time);
            errors = errors + 1;
        end else begin
            $display("[%0t] PASS (reset) lanes held at 0", $time);
        end

        @(negedge clk);
        rst_n = 1;

        // --- valid_in = 0: bus changes but outputs must hold last value ---
        @(negedge clk);
        system_bus_in = 256'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
        @(posedge clk); #1;
        if (lane0_symbols !== 64'b0 || lane1_symbols !== 64'b0 ||
            lane2_symbols !== 64'b0 || lane3_symbols !== 64'b0) begin
            $display("[%0t] FAIL (valid_in=0 hold) lanes changed without valid_in", $time);
            errors = errors + 1;
        end else begin
            $display("[%0t] PASS (valid_in=0 hold) lanes correctly held", $time);
        end

        // --- Test pattern 1, valid_in asserted ---
        @(negedge clk);
        valid_in = 1;
        system_bus_in = 256'hAAAAAAAAAAAAAAAA55555555AAAAAAAAAAAAAAAA5555555555555555AAAAAAAA;
        @(posedge clk); #1;
        check_lanes(256'hAAAAAAAAAAAAAAAA55555555AAAAAAAAAAAAAAAA5555555555555555AAAAAAAA, "pattern1");

        // --- Test pattern 2 ---
        @(negedge clk);
        system_bus_in = 256'hFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210;
        @(posedge clk); #1;
        check_lanes(256'hFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210, "pattern2");

        // --- valid_in drops again: outputs must hold pattern2's mapped value ---
        @(negedge clk);
        valid_in = 0;
        system_bus_in = 256'h1111111111111111111111111111111111111111111111111111111111111111;
        @(posedge clk); #1;
        check_lanes(256'hFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210, "hold-after-pattern2");

        #20;
        if (errors == 0)
            $display("=== ALL TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule