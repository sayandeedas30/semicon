module pcie_phy_layer (
    input wire clk,
    input wire rst_n,
    input wire valid_in,                    // Added to gate incoming valid data from Link Layer
    input wire [255:0] system_bus_in,
    output reg [63:0] lane0_symbols,
    output reg [63:0] lane1_symbols,
    output reg [63:0] lane2_symbols,
    output reg [63:0] lane3_symbols
);

    // Internal wires for the processed lanes
    wire [63:0] l0_out, l1_out, l2_out, l3_out;

    // Instantiate Lane Processors (Multi-Lane Striping Hardware)[cite: 1, 10]
    lane_processor lane0 (.raw_chunk(system_bus_in[63:0]),   .processed_chunk(l0_out));
    lane_processor lane1 (.raw_chunk(system_bus_in[127:64]),  .processed_chunk(l1_out));
    lane_processor lane2 (.raw_chunk(system_bus_in[191:128]), .processed_chunk(l2_out));
    lane_processor lane3 (.raw_chunk(system_bus_in[255:192]), .processed_chunk(l3_out));

    // Register outputs on the clock edge with valid gating
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lane0_symbols <= 64'b0;
            lane1_symbols <= 64'b0;
            lane2_symbols <= 64'b0;
            lane3_symbols <= 64'b0;
        end else if (valid_in) begin
            lane0_symbols <= l0_out;
            lane1_symbols <= l1_out;
            lane2_symbols <= l2_out;
            lane3_symbols <= l3_out;
        end
        // If valid_in is low, hold current symbols stable
    end

endmodule