module system_top (
    input  wire         aclk,
    input  wire         aresetn, 

    // External input 0 (into ingress 0)
    input  wire [511:0] ext_s0_tdata,
    input  wire [63:0]  ext_s0_tkeep,
    input  wire         ext_s0_tlast,
    input  wire         ext_s0_tvalid,
    output wire         ext_s0_tready,

    // External input 1 (into ingress 1)
    input  wire [511:0] ext_s1_tdata,
    input  wire [63:0]  ext_s1_tkeep,
    input  wire         ext_s1_tlast,
    input  wire         ext_s1_tvalid,
    output wire         ext_s1_tready,

    // Final external outputs: PHY-facing symbol lanes
    output wire [63:0]  lane0_symbols,
    output wire [63:0]  lane1_symbols,
    output wire [63:0]  lane2_symbols,
    output wire [63:0]  lane3_symbols
);

    // -------------------------------------------------------
    // AXI4-Stream domain output (egress side) -> adapter input
    // -------------------------------------------------------
    wire [511:0] axi_out_tdata;
    wire [63:0]  axi_out_tkeep;
    wire         axi_out_tlast;
    wire         axi_out_tvalid;
    wire         axi_out_tready;   // driven by axi_to_link_bridge, feeds egress's m_tready

    // -------------------------------------------------------
    // Adapter output -> link layer input (256-bit, valid-only)
    // -------------------------------------------------------
    wire [255:0] link_raw_bus;
    wire         link_valid;

    // -------------------------------------------------------
    // AXI4-Stream domain: 2x ingress -> interconnect -> egress
    // (aclk/aresetn naming, full tvalid/tready handshake throughout)
    // -------------------------------------------------------
    axi_stream_top u_axi_stream_top (
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
        .ext_m_tdata   (axi_out_tdata),
        .ext_m_tkeep   (axi_out_tkeep),
        .ext_m_tlast   (axi_out_tlast),
        .ext_m_tvalid  (axi_out_tvalid),
        .ext_m_tready  (axi_out_tready)   // backpressure now correctly driven by the adapter
    );

    // -------------------------------------------------------
    // Adapter: reconciles width (512->256) and handshake style
    // (tvalid/tready -> valid-only) between the two domains.
    // -------------------------------------------------------
    axi_to_link_bridge u_axi_to_link_bridge (
        .aclk        (aclk),
        .aresetn     (aresetn),
        .s_tdata     (axi_out_tdata),
        .s_tvalid    (axi_out_tvalid),
        .s_tready    (axi_out_tready),
        .raw_bus_out (link_raw_bus),
        .valid_out   (link_valid)
    );

    // -------------------------------------------------------
    // Link layer + PCIe-PHY domain (clk/rst_n naming, valid-only
    // handshake, no backpressure). Same physical clock/reset as
    // the AXI side, just mapped to this family's port names.
    // -------------------------------------------------------
    bridge_subsystem_top u_bridge_subsystem_top (
        .clk              (aclk),
        .rst_n            (aresetn),
        .raw_link_data_in (link_raw_bus),
        .link_valid_in    (link_valid),
        .lane0_symbols    (lane0_symbols),
        .lane1_symbols    (lane1_symbols),
        .lane2_symbols    (lane2_symbols),
        .lane3_symbols    (lane3_symbols)
    );

endmodule
