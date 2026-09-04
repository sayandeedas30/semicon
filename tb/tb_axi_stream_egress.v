// Description: Directed testbench for axi_stream_egress module.
//              Same 5 scenarios as ingress: reset, single transfer,
//              backpressure, back-to-back (swap), tlast propagation.
//              Here, s_* signals represent the INTERNAL bus side
//              (driven by testbench as if it were the interconnect),
//              and m_* signals represent the EXTERNAL output side
//              (testbench acts as the external receiver via m_tready).
`timescale 1ns/1ps

module tb_axi_stream_egress;

    reg aclk, aresetn;
    reg  [511:0] s_tdata;
    reg  [63:0]  s_tkeep;
    reg          s_tlast, s_tvalid;
    wire         s_tready;
    wire [511:0] m_tdata;
    wire [63:0]  m_tkeep;
    wire         m_tlast, m_tvalid;
    reg          m_tready;

    integer pass_count, fail_count;

    // Instantiate DUT
    axi_stream_egress dut (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (s_tdata),
        .s_tkeep  (s_tkeep),
        .s_tlast  (s_tlast),
        .s_tvalid (s_tvalid),
        .s_tready (s_tready),
        .m_tdata  (m_tdata),
        .m_tkeep  (m_tkeep),
        .m_tlast  (m_tlast),
        .m_tvalid (m_tvalid),
        .m_tready (m_tready)
    );

    // Clock generation: 10ns period (100MHz)
    initial aclk = 0;
    always #5 aclk = ~aclk;

    // Waveform dump
    initial begin
        $dumpfile("sim/wave_egress.vcd");
        $dumpvars(0, tb_axi_stream_egress);
    end

    // Task: check a value and log pass/fail
    task check_equal;
        input [511:0] actual;
        input [511:0] expected;
        input [255:0] test_name; // string label
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
        // TEST 1: Reset behavior
        // -------------------------------------------------
        aresetn  = 0;
        s_tvalid = 0;
        s_tdata  = 0;
        s_tkeep  = 0;
        s_tlast  = 0;
        m_tready = 0;

        @(posedge aclk);
        if (m_tvalid === 1'b0)
            $display("[PASS] Test1 reset: m_tvalid is 0 after reset");
        else
            $display("[FAIL] Test1 reset: m_tvalid expected 0, got %b", m_tvalid);

        @(negedge aclk);
        aresetn = 1;   // release reset

        // -------------------------------------------------
        // TEST 2: Simple single-word transfer (external m_tready always high)
        // Internal side (interconnect) hands us one word.
        // -------------------------------------------------
        m_tready = 1;

        @(negedge aclk);
        s_tdata  = 512'hAAAA_BBBB_CCCC_DDDD;
        s_tkeep  = {64{1'b1}};
        s_tlast  = 1'b0;
        s_tvalid = 1'b1;

        @(posedge aclk); // handshake happens here (s_tvalid & s_tready)
        @(negedge aclk);
        s_tvalid = 1'b0;

        @(posedge aclk); // data should now appear on external m_tdata
        check_equal(m_tdata, 512'hAAAA_BBBB_CCCC_DDDD, "Test2 simple transfer data");
        if (m_tvalid === 1'b1)
            $display("[PASS] Test2 m_tvalid asserted correctly");
        else
            $display("[FAIL] Test2 m_tvalid expected 1, got %b", m_tvalid);

        @(negedge aclk);

        // -------------------------------------------------
        // TEST 3: Backpressure — external m_tready held low while
        // internal side (s_tvalid) offers data. This simulates the
        // external link (e.g. PCIe PHY) not being ready yet.
        // -------------------------------------------------
        m_tready = 0;

        @(negedge aclk);
        s_tdata  = 512'h1111_2222_3333_4444;
        s_tkeep  = {64{1'b1}};
        s_tlast  = 1'b0;
        s_tvalid = 1'b1;

        @(posedge aclk); // buffer fills, m_tvalid should go high
        @(negedge aclk);
        s_tvalid = 1'b0; // interconnect stops offering (buffer is full anyway)

        if (s_tready === 1'b0)
            $display("[PASS] Test3 s_tready correctly low while buffer full and m_tready=0");
        else
            $display("[FAIL] Test3 s_tready expected 0, got %b", s_tready);

        repeat (3) @(posedge aclk);
        check_equal(m_tdata, 512'h1111_2222_3333_4444, "Test3 data held stable during stall");

        @(negedge aclk);
        m_tready = 1'b1; // external side finally ready
        @(posedge aclk); // data drains out to external port
        @(negedge aclk);
        if (m_tvalid === 1'b0)
            $display("[PASS] Test3 buffer drained after m_tready asserted");
        else
            $display("[FAIL] Test3 buffer expected empty, m_tvalid=%b", m_tvalid);

        // -------------------------------------------------
        // TEST 4: Back-to-back transfer (swap case)
        // Buffer full and draining to external side same cycle
        // new data arrives from internal side.
        // -------------------------------------------------
        m_tready = 1'b0;

        @(negedge aclk);
        s_tdata  = 512'h5555_6666_7777_8888;
        s_tkeep  = {64{1'b1}};
        s_tlast  = 1'b0;
        s_tvalid = 1'b1;

        @(posedge aclk); // first word loads into buffer
        @(negedge aclk);
        s_tdata  = 512'h9999_AAAA_BBBB_CCCC; // second word ready from interconnect
        m_tready = 1'b1;                     // external side ready to drain first word

        @(posedge aclk); // swap: first word leaves to external port, second word loads
        @(negedge aclk);
        s_tvalid = 1'b0;

        check_equal(m_tdata, 512'h9999_AAAA_BBBB_CCCC, "Test4 back-to-back swap data");
        if (m_tvalid === 1'b1)
            $display("[PASS] Test4 m_tvalid still high after swap (no bubble)");
        else
            $display("[FAIL] Test4 m_tvalid expected 1 after swap, got %b", m_tvalid);

        @(posedge aclk);
        @(negedge aclk);
        m_tready = 1'b0;

        // -------------------------------------------------
        // TEST 5: tlast propagation to external side
        // -------------------------------------------------
        @(negedge aclk);
        s_tdata  = 512'hDEAD_BEEF;
        s_tkeep  = {64{1'b1}};
        s_tlast  = 1'b1;
        s_tvalid = 1'b1;
        m_tready = 1'b1;

        @(posedge aclk);
        @(negedge aclk);
        s_tvalid = 1'b0;

        @(posedge aclk);
        if (m_tlast === 1'b1)
            $display("[PASS] Test5 tlast propagated correctly");
        else
            $display("[FAIL] Test5 tlast expected 1, got %b", m_tlast);

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
