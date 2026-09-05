module axi_stream_interconnect (
    input  wire         aclk,
    input  wire         aresetn,     // active-low synchronous reset

    //Input 0
    input  wire [511:0] s0_tdata,
    input  wire [63:0]  s0_tkeep,
    input  wire         s0_tlast,
    input  wire         s0_tvalid,
    output wire         s0_tready,

    //Input 1
    input  wire [511:0] s1_tdata,
    input  wire [63:0]  s1_tkeep,
    input  wire         s1_tlast,
    input  wire         s1_tvalid,
    output wire         s1_tready,

    //output
    output wire [511:0] m_tdata,
    output wire [63:0]  m_tkeep,
    output wire         m_tlast,
    output wire         m_tvalid,
    input  wire         m_tready
);

    reg grant;
    //mux
    assign m_tdata  = grant ? s1_tdata  : s0_tdata;
    assign m_tkeep  = grant ? s1_tkeep  : s0_tkeep;
    assign m_tlast  = grant ? s1_tlast  : s0_tlast;
    assign m_tvalid = grant ? s1_tvalid : s0_tvalid;

    assign s0_tready = (grant == 1'b0) && m_tready;
    assign s1_tready = (grant == 1'b1) && m_tready;

    //round robin selection
    always @(posedge aclk) begin
        if (!aresetn) begin
            grant <= 1'b0;
        end
        else begin
            if (grant == 1'b0 && s0_tvalid && s0_tready && s0_tlast && s1_tvalid)
                grant <= 1'b1;
            else if (grant == 1'b1 && s1_tvalid && s1_tready && s1_tlast && s0_tvalid)
                grant <= 1'b0;
            // else: hold current grant
        end
    end
endmodule