//=============================================================
// Testbench: tb_axi_stream_top
// Description: End-to-end integration test. Drives data into the
//              external input of axi_stream_top (ingress side) and
//              checks it arrives correctly at the external output
//              (egress side), having passed through both modules.
//=============================================================
`timescale 1ns/1ps

module tb_axi_stream_top;

    reg aclk, aresetn;
    reg  [511:0] ext_s_tdata;
    reg  [63:0]  ext_s_tkeep;
    reg          ext_s_tlast, ext_s_tvalid;
    wire         ext_s_tready;
    wire [511:0] ext_m_tdata;
    wire [63:0]  ext_m_tkeep;
    wire         ext_m_tlast, ext_m_tvalid;
    reg          ext_m_tready;

    integer pass_count, fail_count;

    axi_stream_top dut (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .ext_s_tdata  (ext_s_tdata),
        .ext_s_tkeep  (ext_s_tkeep),
        .ext_s_tlast  (ext_s_tlast),
        .ext_s_tvalid (ext_s_tvalid),
        .ext_s_tready (ext_s_tready),
        .ext_m_tdata  (ext_m_tdata),
        .ext_m_tkeep  (ext_m_tkeep),
        .ext_m_tlast  (ext_m_tlast),
        .ext_m_tvalid (ext_m_tvalid),
        .ext_m_tready (ext_m_tready)
    );

    initial aclk = 0;
    always #5 aclk = ~aclk;

    initial begin
        $dumpfile("sim/wave_top.vcd");
        $dumpvars(0, tb_axi_stream_top);
    end

    task check_equal;
        input [511:0] actual;
        input [511:0] expected;
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

    initial begin
        pass_count = 0;
        fail_count = 0;

        // -------------------------------------------------
        // Reset
        // -------------------------------------------------
        aresetn      = 0;
        ext_s_tvalid = 0;
        ext_s_tdata  = 0;
        ext_s_tkeep  = 0;
        ext_s_tlast  = 0;
        ext_m_tready = 0;

        @(posedge aclk);
        @(posedge aclk);
        if (ext_m_tvalid === 1'b0)
            $display("[PASS] Reset: ext_m_tvalid is 0 after reset");
        else
            $display("[FAIL] Reset: ext_m_tvalid expected 0, got %b", ext_m_tvalid);

        @(negedge aclk);
        aresetn = 1;

        // -------------------------------------------------
        // TEST: End-to-end single word, egress always ready
        // -------------------------------------------------
        ext_m_tready = 1;

        @(negedge aclk);
        ext_s_tdata  = 512'hCAFE_BABE_1234_5678;
        ext_s_tkeep  = {64{1'b1}};
        ext_s_tlast  = 1'b0;
        ext_s_tvalid = 1'b1;

        @(posedge aclk); // ingress accepts the word
        @(negedge aclk);
        ext_s_tvalid = 1'b0;

        // word now needs one cycle to move ingress->egress internally,
        // then egress presents it on ext_m_tdata the cycle after that
        @(posedge aclk); // ingress presents on link_*, egress accepts it
        @(posedge aclk); // egress presents it on ext_m_tdata

        check_equal(ext_m_tdata, 512'hCAFE_BABE_1234_5678, "End-to-end data match");
        if (ext_m_tvalid === 1'b1)
            $display("[PASS] ext_m_tvalid asserted at final output");
        else
            $display("[FAIL] ext_m_tvalid expected 1, got %b", ext_m_tvalid);

        // -------------------------------------------------
        // TEST: End-to-end with tlast
        // -------------------------------------------------
        @(negedge aclk);
        ext_s_tdata  = 512'hDEAD_C0DE;
        ext_s_tkeep  = {64{1'b1}};
        ext_s_tlast  = 1'b1;
        ext_s_tvalid = 1'b1;

        @(posedge aclk);
        @(negedge aclk);
        ext_s_tvalid = 1'b0;

        @(posedge aclk);
        @(posedge aclk);

        check_equal(ext_m_tdata, 512'hDEAD_C0DE, "End-to-end tlast test data match");
        if (ext_m_tlast === 1'b1)
            $display("[PASS] ext_m_tlast propagated end-to-end");
        else
            $display("[FAIL] ext_m_tlast expected 1, got %b", ext_m_tlast);

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
