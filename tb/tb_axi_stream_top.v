`timescale 1ns/1ps
 
module tb_axi_stream_top;
 
    reg aclk, aresetn;
 
    reg  [511:0] ext_s0_tdata;
    reg  [63:0]  ext_s0_tkeep;
    reg          ext_s0_tlast, ext_s0_tvalid;
    wire         ext_s0_tready;
 
    reg  [511:0] ext_s1_tdata;
    reg  [63:0]  ext_s1_tkeep;
    reg          ext_s1_tlast, ext_s1_tvalid;
    wire         ext_s1_tready;
 
    wire [511:0] ext_m_tdata;
    wire [63:0]  ext_m_tkeep;
    wire         ext_m_tlast, ext_m_tvalid;
    reg          ext_m_tready;
 
    integer pass_count, fail_count;
 
    axi_stream_top dut (
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
        .ext_m_tdata   (ext_m_tdata),
        .ext_m_tkeep   (ext_m_tkeep),
        .ext_m_tlast   (ext_m_tlast),
        .ext_m_tvalid  (ext_m_tvalid),
        .ext_m_tready  (ext_m_tready)
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
        aresetn = 0;
        ext_s0_tvalid = 0; ext_s0_tdata = 0; ext_s0_tkeep = 0; ext_s0_tlast = 0;
        ext_s1_tvalid = 0; ext_s1_tdata = 0; ext_s1_tkeep = 0; ext_s1_tlast = 0;
        ext_m_tready  = 0;
 
        @(posedge aclk);
        @(posedge aclk);
        @(negedge aclk);
        aresetn = 1;
 
        // -------------------------------------------------
        // TEST 1: Input0 only, end-to-end through ingress0 ->
        // interconnect (default grant=0) -> egress -> external output
        // -------------------------------------------------
        ext_m_tready = 1;
 
        @(negedge aclk);
        ext_s0_tdata  = 512'hAAAA_1111;
        ext_s0_tkeep  = {64{1'b1}};
        ext_s0_tlast  = 1'b1;
        ext_s0_tvalid = 1'b1;
 
        @(posedge aclk); // ingress0 accepts
        @(negedge aclk);
        ext_s0_tvalid = 1'b0;
        ext_s0_tlast  = 1'b0;
 
        // allow a few cycles for the word to propagate through the
        // full chain (ingress buffer -> interconnect mux -> egress buffer)
        repeat (4) @(posedge aclk);
 
        check_equal(ext_m_tdata, 512'hAAAA_1111, "Test1 input0 end-to-end through full chain");
 
        // -------------------------------------------------
        // TEST 2: Switch grant to input1 via a tlast handshake on
        // input0 while input1 is simultaneously requesting, then
        // confirm input1's data flows end-to-end.
        // -------------------------------------------------
        @(negedge aclk);
        ext_s0_tdata  = 512'hCCCC_2222;
        ext_s0_tkeep  = {64{1'b1}};
        ext_s0_tlast  = 1'b1;   // last word on input0 -> triggers switch check
        ext_s0_tvalid = 1'b1;
 
        ext_s1_tdata  = 512'hBBBB_3333;
        ext_s1_tkeep  = {64{1'b1}};
        ext_s1_tlast  = 1'b1;
        ext_s1_tvalid = 1'b1;  // input1 requesting at the same time
 
        // let this cycle's handshake happen (ingress0 accepts, and the
        // interconnect grant-switch condition evaluates against it)
        @(posedge aclk);
        @(negedge aclk);
        ext_s0_tvalid = 1'b0;
        ext_s0_tlast  = 1'b0;
 
        // give the chain time to: drain ingress0's word through the
        // (still grant=0) interconnect and egress, THEN switch grant,
        // THEN drain ingress1's word through as well.
        repeat (8) @(posedge aclk);
 
        ext_s1_tvalid = 1'b0;
        ext_s1_tlast  = 1'b0;
 
        check_equal(ext_m_tdata, 512'hBBBB_3333, "Test2 input1 end-to-end after grant switch");
 
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