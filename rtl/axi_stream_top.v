module axi_stream_top (
    input  wire         aclk,
    input  wire         aresetn,
 
    //input ingress0
    input  wire [511:0] ext_s0_tdata,
    input  wire [63:0]  ext_s0_tkeep,
    input  wire         ext_s0_tlast,
    input  wire         ext_s0_tvalid,
    output wire         ext_s0_tready,
 
    //input ingress1
    input  wire [511:0] ext_s1_tdata,
    input  wire [63:0]  ext_s1_tkeep,
    input  wire         ext_s1_tlast,
    input  wire         ext_s1_tvalid,
    output wire         ext_s1_tready,
 
    //output(egress)
    output wire [511:0] ext_m_tdata,
    output wire [63:0]  ext_m_tkeep,
    output wire         ext_m_tlast,
    output wire         ext_m_tvalid,
    input  wire         ext_m_tready
);
 
    //ingress to interconnect
    wire [511:0] link0_tdata;
    wire [63:0]  link0_tkeep;
    wire         link0_tlast;
    wire         link0_tvalid;
    wire         link0_tready;
 
    wire [511:0] link1_tdata;
    wire [63:0]  link1_tkeep;
    wire         link1_tlast;
    wire         link1_tvalid;
    wire         link1_tready;
 
    //interconnect to egress
    wire [511:0] linkm_tdata;
    wire [63:0]  linkm_tkeep;
    wire         linkm_tlast;
    wire         linkm_tvalid;
    wire         linkm_tready;
 
    axi_stream_ingress u_ingress0 (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (ext_s0_tdata),
        .s_tkeep  (ext_s0_tkeep),
        .s_tlast  (ext_s0_tlast),
        .s_tvalid (ext_s0_tvalid),
        .s_tready (ext_s0_tready),
        .m_tdata  (link0_tdata),
        .m_tkeep  (link0_tkeep),
        .m_tlast  (link0_tlast),
        .m_tvalid (link0_tvalid),
        .m_tready (link0_tready)
    );
 
    axi_stream_ingress u_ingress1 (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (ext_s1_tdata),
        .s_tkeep  (ext_s1_tkeep),
        .s_tlast  (ext_s1_tlast),
        .s_tvalid (ext_s1_tvalid),
        .s_tready (ext_s1_tready),
        .m_tdata  (link1_tdata),
        .m_tkeep  (link1_tkeep),
        .m_tlast  (link1_tlast),
        .m_tvalid (link1_tvalid),
        .m_tready (link1_tready)
    );
 
    axi_stream_interconnect u_interconnect (
        .aclk      (aclk),
        .aresetn   (aresetn),
        .s0_tdata  (link0_tdata),
        .s0_tkeep  (link0_tkeep),
        .s0_tlast  (link0_tlast),
        .s0_tvalid (link0_tvalid),
        .s0_tready (link0_tready),
        .s1_tdata  (link1_tdata),
        .s1_tkeep  (link1_tkeep),
        .s1_tlast  (link1_tlast),
        .s1_tvalid (link1_tvalid),
        .s1_tready (link1_tready),
        .m_tdata   (linkm_tdata),
        .m_tkeep   (linkm_tkeep),
        .m_tlast   (linkm_tlast),
        .m_tvalid  (linkm_tvalid),
        .m_tready  (linkm_tready)
    );
 
    axi_stream_egress u_egress (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_tdata  (linkm_tdata),
        .s_tkeep  (linkm_tkeep),
        .s_tlast  (linkm_tlast),
        .s_tvalid (linkm_tvalid),
        .s_tready (linkm_tready),
        .m_tdata  (ext_m_tdata),
        .m_tkeep  (ext_m_tkeep),
        .m_tlast  (ext_m_tlast),
        .m_tvalid (ext_m_tvalid),
        .m_tready (ext_m_tready)
    );
 
endmodule