module axi_stream_interconnect (
    input  wire         aclk,
    input  wire         aresetn,     
 
    // Input port 0
    input  wire [511:0] s0_tdata,
    input  wire [63:0]  s0_tkeep,
    input  wire         s0_tlast,
    input  wire         s0_tvalid,
    output wire         s0_tready,
 
    // Input port 1
    input  wire [511:0] s1_tdata,
    input  wire [63:0]  s1_tkeep,
    input  wire         s1_tlast,
    input  wire         s1_tvalid,
    output wire         s1_tready,
 
    // Single output port (toward link layer)
    output wire [511:0] m_tdata,
    output wire [63:0]  m_tkeep,
    output wire         m_tlast,
    output wire         m_tvalid,
    input  wire         m_tready
);
 
    // Grant register: 0 = input 0 selected, 1 = input 1 selected
    reg grant;
 
    // -------------------------------------------------------
    // Data path: simple 2-to-1 mux based on current grant
    // -------------------------------------------------------
    assign m_tdata  = (grant == 1'b0) ? s0_tdata  : s1_tdata;
    assign m_tkeep  = (grant == 1'b0) ? s0_tkeep  : s1_tkeep;
    assign m_tlast  = (grant == 1'b0) ? s0_tlast  : s1_tlast;
    assign m_tvalid = (grant == 1'b0) ? s0_tvalid : s1_tvalid;
 
    // -------------------------------------------------------
    // Input handshake gating: only the granted input may transfer.
    // The non-granted input always sees tready = 0.
    // -------------------------------------------------------
    assign s0_tready = (grant == 1'b0) && m_tready;
    assign s1_tready = (grant == 1'b1) && m_tready;
 
    // -------------------------------------------------------
    // Arbitration: grant update
    // -------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            grant <= 1'b0;
        end
        else begin
            if (grant == 1'b0) begin
                // Currently serving input 0.
 
                // Case 2: input 0 is idle, input 1 wants a turn -> switch now.
                if (!s0_tvalid && s1_tvalid) begin
                    grant <= 1'b1;
                end
                // Case 1: input 0 just completed a packet, input 1 wants a turn.
                else if (s0_tvalid && s0_tready && s0_tlast && s1_tvalid) begin
                    grant <= 1'b1;
                end
                // else: hold grant on input 0 (mid-packet, or input 1 not requesting)
            end
            else begin
                // Currently serving input 1.
 
                // Case 2: input 1 is idle, input 0 wants a turn -> switch now.
                if (!s1_tvalid && s0_tvalid) begin
                    grant <= 1'b0;
                end
                // Case 1: input 1 just completed a packet, input 0 wants a turn.
                else if (s1_tvalid && s1_tready && s1_tlast && s0_tvalid) begin
                    grant <= 1'b0;
                end
                // else: hold grant on input 1 (mid-packet, or input 0 not requesting)
            end
        end
    end
 
endmodule