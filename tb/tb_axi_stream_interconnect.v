`timescale 1ns/1ps

module tb_axi_stream_interconnect;
    reg aclk, aresetn;

    reg  [511:0] s0_tdata;
    reg  [63:0]  s0_tkeep;
    reg          s0_tlast, s0_tvalid;
    wire         s0_tready;

    reg  [511:0] s1_tdata;
    reg  [63:0]  s1_tkeep;
    reg          s1_tlast, s1_tvalid;
    wire         s1_tready;

    wire [511:0] m_tdata;
    wire [63:0]  m_tkeep;
    wire         m_tlast, m_tvalid;
    reg          m_tready;

    integer pass_count, fail_count;

    axi_stream_interconnect dut (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .s0_tdata  (s0_tdata),
        .s0_tkeep  (s0_tkeep),
        .s0_tlast  (s0_tlast),
        .s0_tvalid (s0_tvalid),
        .s0_tready (s0_tready),
        .s1_tdata  (s1_tdata),
        .s1_tkeep  (s1_tkeep),
        .s1_tlast  (s1_tlast),
        .s1_tvalid (s1_tvalid),
        .s1_tready (s1_tready),
        .m_tdata   (m_tdata),
        .m_tkeep   (m_tkeep),
        .m_tlast   (m_tlast),
        .m_tvalid  (m_tvalid),
        .m_tready  (m_tready)
    );

    initial aclk = 0;
    always #5 aclk = ~aclk;

    initial begin
        $dumpfile("sim/wave_interconnect.vcd");
        $dumpvars(0, tb_axi_stream_interconnect);
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

    task check_bit;
        input actual;
        input expected;
        input [255:0] test_name;
        begin
            if (actual === expected) begin
                $display("[PASS] %0s", test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] %0s  (expected=%b actual=%b)", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        aresetn  = 0;
        s0_tvalid = 0; s0_tdata = 0; s0_tkeep = 0; s0_tlast = 0;
        s1_tvalid = 0; s1_tdata = 0; s1_tkeep = 0; s1_tlast = 0;
        m_tready  = 0;

        @(posedge aclk);
        @(posedge aclk);
        @(negedge aclk);
        aresetn = 1;

        // TEST 1: Only input 0 active -> passes straight through

        m_tready = 1;

        @(negedge aclk);
        s0_tdata  = 512'hAAAA_0000;
        s0_tkeep  = {64{1'b1}};
        s0_tlast  = 1'b1;
        s0_tvalid = 1'b1;

        @(posedge aclk);
        check_equal(m_tdata, 512'hAAAA_0000, "Test1 input0-only passthrough data");

        @(negedge aclk);
        s0_tvalid = 1'b0;
        s0_tlast  = 1'b0;

        // -------------------------------------------------
        // TEST 2: Only input 1 active -> passes straight through
        // -------------------------------------------------
        @(negedge aclk);
        s1_tdata  = 512'hBBBB_1111;
        s1_tkeep  = {64{1'b1}};
        s1_tlast  = 1'b1;
        s1_tvalid = 1'b1;

        // input1 is not yet granted (grant is still 0 from reset,
        // and no switch condition has occurred), so its tready
        // should be low, and m_tdata should NOT reflect s1_tdata yet.
        @(posedge aclk);
        check_bit(s1_tready, 1'b0, "Test2a s1_tready low while grant still 0 and no prior tlast switch");

        // Since grant never left 0 in this fresh scenario, force it
        // via a quick input0 tlast handshake so grant moves to 1,
        // proving the switch mechanism, then confirm input1 flows.
        s1_tvalid = 1'b0;

        @(negedge aclk);
        s0_tdata  = 512'hCCCC_2222;
        s0_tvalid = 1'b1;
        s0_tlast  = 1'b1;
        s1_tvalid = 1'b1;   // input1 requesting at the same time
        s1_tdata  = 512'hBBBB_1111;
        s1_tlast  = 1'b1;
        s1_tkeep  = {64{1'b1}};

        @(posedge aclk); // grant should switch to 1 after this tlast
        @(negedge aclk);
        s0_tvalid = 1'b0;
        s0_tlast  = 1'b0;

        @(posedge aclk);
        check_equal(m_tdata, 512'hBBBB_1111, "Test2b input1 now granted and passing through");

        @(negedge aclk);
        s1_tvalid = 1'b0;
        s1_tlast  = 1'b0;

        // -------------------------------------------------
        // TEST 3: Contention — both request, non-granted tready stays low
        // (grant is currently 1 from Test 2b)
        // -------------------------------------------------
        @(negedge aclk);
        s0_tvalid = 1'b1;
        s0_tdata  = 512'hDDDD_3333;
        s0_tlast  = 1'b0;   // not last word yet - mid packet
        s0_tkeep  = {64{1'b1}};
        s1_tvalid = 1'b1;
        s1_tdata  = 512'hEEEE_4444;
        s1_tlast  = 1'b0;
        s1_tkeep  = {64{1'b1}};

        @(posedge aclk);
        check_bit(s0_tready, 1'b0, "Test3 s0_tready low while grant=1 and both requesting");
        check_bit(s1_tready, 1'b1, "Test3 s1_tready high since grant=1");

        // -------------------------------------------------
        // TEST 4: Mid-packet hold — grant must NOT switch even though
        // input0 is requesting, because current packet on input1
        // hasn't hit tlast yet.
        // -------------------------------------------------
        @(negedge aclk);
        s1_tdata = 512'hEEEE_5555; // second word of input1's packet, still not last
        s1_tlast = 1'b0;

        @(posedge aclk);
        check_equal(m_tdata, 512'hEEEE_5555, "Test4 grant still on input1 mid-packet");
        check_bit(s0_tready, 1'b0, "Test4 input0 still gated out mid-packet on input1");

        // -------------------------------------------------
        // TEST 5: Grant switches after tlast, since input0 is requesting
        // -------------------------------------------------
        @(negedge aclk);
        s1_tdata = 512'hEEEE_6666; // final word of input1's packet
        s1_tlast = 1'b1;

        @(posedge aclk); // this transfer completes with tlast -> grant should flip to 0
        @(negedge aclk);
        s1_tvalid = 1'b0;
        s1_tlast  = 1'b0;

        @(posedge aclk);
        check_equal(m_tdata, 512'hDDDD_3333, "Test5 grant switched to input0 after tlast");
        check_bit(s0_tready, 1'b1, "Test5 s0_tready now high after switch");

        @(negedge aclk);
        s0_tvalid = 1'b0;
        s0_tlast  = 1'b0;

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
