module axi_stream_egress (
    input  wire         aclk,
    input  wire         aresetn,    

    input  wire [511:0] s_tdata,
    input  wire [63:0]  s_tkeep,
    input  wire         s_tlast,
    input  wire         s_tvalid,
    output wire         s_tready,

    output wire [511:0] m_tdata,
    output wire [63:0]  m_tkeep,
    output wire         m_tlast,
    output reg          m_tvalid,
    input  wire         m_tready
);

    // Internal storage registers (the "1-deep buffer")
    reg [511:0] data_reg;
    reg [63:0]  keep_reg;
    reg         last_reg;

    // We can accept new input if the buffer is empty (m_tvalid == 0),
    // or if the buffer is full but the downstream is draining it
    // this same cycle (m_tvalid & m_tready).
    assign s_tready = (!m_tvalid) || (m_tvalid && m_tready);

    always @(posedge aclk) begin
        if (!aresetn) begin
            m_tvalid <= 1'b0;
            data_reg <= 512'b0;
            keep_reg <= 64'b0;
            last_reg <= 1'b0;
        end
        else begin
            // Case 1: downstream takes current word this cycle
            if (m_tvalid && m_tready) begin
                if (s_tvalid && s_tready) begin
                    // new word arrives same cycle -> load it immediately
                    data_reg <= s_tdata;
                    keep_reg <= s_tkeep;
                    last_reg <= s_tlast;
                    m_tvalid <= 1'b1;
                end
                else begin
                    // nothing new -> buffer goes empty
                    m_tvalid <= 1'b0;
                end
            end
            // Case 2: buffer currently empty, new input accepted
            else if (!m_tvalid && s_tvalid && s_tready) begin
                data_reg <= s_tdata;
                keep_reg <= s_tkeep;
                last_reg <= s_tlast;
                m_tvalid <= 1'b1;
            end
            // Case 3: buffer full, downstream not ready -> hold state
            // (implicit: registers keep their values, no else needed)
        end
    end

    assign m_tdata = data_reg;
    assign m_tkeep = keep_reg;
    assign m_tlast = last_reg;

endmodule
