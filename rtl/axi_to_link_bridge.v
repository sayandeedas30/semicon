//=============================================================
// Module: axi_to_link_bridge
// Description: Adapter sitting between axi_stream_egress (512-bit
//              AXI4-Stream, tvalid/tready handshake) and
//              link_layer_packetizer (256-bit, valid_in only, no
//              backpressure). Splits each 512-bit AXI-Stream word
//              into two sequential 256-bit halves for the link layer.
//
//              Since the link layer provides no tready/backpressure
//              signal at all (it always accepts whatever is on
//              raw_bus_in when valid_in is high), this adapter must
//              hold s_tready LOW while it is still draining out the
//              second half of the previous word, so the AXI side
//              never overwrites data mid-send.
//
//              Timing: 1 cycle to accept + send high half, 1 cycle
//              to send low half, 1 idle "bubble" cycle before the
//              next word can be accepted. This trades a small amount
//              of throughput for simplicity/correctness — acceptable
//              for Stage 1 scope. Could be optimized later to overlap
//              the bubble cycle with accepting the next word, the
//              same way the ingress/egress buffers overlap a drain
//              and a fill on the same cycle.
//=============================================================

module axi_to_link_bridge (
    input  wire         aclk,
    input  wire         aresetn,     // active-low synchronous reset

    // AXI4-Stream slave side (connects to axi_stream_egress's master output)
    input  wire [511:0] s_tdata,
    input  wire         s_tvalid,
    output wire         s_tready,
    // s_tkeep / s_tlast are not consumed here since the link layer has
    // no concept of byte-level keep or packet boundaries in this scope.
    // Left unconnected at the instantiation site if not needed.

    // Link layer master side (connects to link_layer_packetizer's input)
    output reg  [255:0] raw_bus_out,
    output reg           valid_out
);

    localparam IDLE      = 2'd0;  // ready to accept a new 512-bit word
    localparam SEND_LOW  = 2'd1;  // high half already sent, sending low half now
    localparam BUBBLE    = 2'd2;  // one idle cycle before accepting the next word

    reg [1:0]   state;
    reg [255:0] low_half_latch;

    // Only accept a new word while idle
    assign s_tready = (state == IDLE);

    always @(posedge aclk) begin
        if (!aresetn) begin
            state          <= IDLE;
            raw_bus_out    <= 256'b0;
            valid_out      <= 1'b0;
            low_half_latch <= 256'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (s_tvalid && s_tready) begin
                        // Accept the word: send the high half this cycle,
                        // latch the low half for the next cycle.
                        raw_bus_out    <= s_tdata[511:256];
                        low_half_latch <= s_tdata[255:0];
                        valid_out      <= 1'b1;
                        state          <= SEND_LOW;
                    end
                    else begin
                        valid_out <= 1'b0;
                    end
                end

                SEND_LOW: begin
                    raw_bus_out <= low_half_latch;
                    valid_out   <= 1'b1;
                    state       <= BUBBLE;
                end

                BUBBLE: begin
                    valid_out <= 1'b0;
                    state     <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
