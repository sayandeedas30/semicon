//=============================================================
// Module: axi_stream_top
// Description: Integration wrapper connecting axi_stream_ingress
//              directly to axi_stream_egress, standing in for the
//              interconnect layer (not yet implemented). Used to
//              prove ingress and egress compose correctly end-to-end.
//
//              External-facing ports are the ingress slave side
//              (true external input) and the egress master side
//              (true external output). The link between ingress's
//              master and egress's slave is entirely internal.
//=============================================================

module axi_stream_top (
    input  wire         aclk,
    input  wire         aresetn,

    // True external input (into ingress)
    input  wire [511:0] ext_s_tdata,
    input  wire [63:0]  ext_s_tkeep,
    input  wire         ext_s_tlast,
    input  wire         ext_s_tvalid,
    output wire         ext_s_tready,

    // True external output (out of egress)
    output wire [511:0] ext_m_tdata,
    output wire [63:0]  ext_m_tkeep,
    output wire         ext_m_tlast,
    output wire         ext_m_tvalid,
    input  wire         ext_m_tready
);

    // Internal wires connecting ingress's master side to egress's slave side
    wire [511:0] link_tdata;
    wire [63:0]  link_tkeep;
    wire         link_tlast;
    wire         link_tvalid;
    wire         link_tready;

    axi_stream_ingress u_ingress (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (ext_s_tdata),
        .s_tkeep  (ext_s_tkeep),
        .s_tlast  (ext_s_tlast),
        .s_tvalid (ext_s_tvalid),
        .s_tready (ext_s_tready),
        .m_tdata  (link_tdata),
        .m_tkeep  (link_tkeep),
        .m_tlast  (link_tlast),
        .m_tvalid (link_tvalid),
        .m_tready (link_tready)
    );

    axi_stream_egress u_egress (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (link_tdata),
        .s_tkeep  (link_tkeep),
        .s_tlast  (link_tlast),
        .s_tvalid (link_tvalid),
        .s_tready (link_tready),
        .m_tdata  (ext_m_tdata),
        .m_tkeep  (ext_m_tkeep),
        .m_tlast  (ext_m_tlast),
        .m_tvalid (ext_m_tvalid),
        .m_tready (ext_m_tready)
    );

endmodule
