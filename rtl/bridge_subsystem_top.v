module bridge_subsystem_top (
    input wire clk,
    input wire rst_n,
    input wire [255:0] raw_link_data_in,
    input wire link_valid_in,
    
    // Outputs directly to the physical analog PHY
    output wire [63:0] lane0_symbols,
    output wire [63:0] lane1_symbols,
    output wire [63:0] lane2_symbols,
    output wire [63:0] lane3_symbols
);

    // Internal wires connecting the modules
    wire [255:0] internal_system_bus;
    wire internal_valid;

    // 1. Instantiate the Link Layer (Packetizer & CRC)
    link_layer_packetizer link_inst (
        .clk(clk),
        .rst_n(rst_n),
        .raw_bus_in(raw_link_data_in),
        .valid_in(link_valid_in),
        .system_bus_out(internal_system_bus),
        .valid_out(internal_valid)
    );

    // 2. Instantiate the PCIe Protocol-to-PHY Layer (with valid gating)
    pcie_phy_layer phy_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(internal_valid),         // Connected properly now!
        .system_bus_in(internal_system_bus),
        .lane0_symbols(lane0_symbols),
        .lane1_symbols(lane1_symbols),
        .lane2_symbols(lane2_symbols),
        .lane3_symbols(lane3_symbols)
    );

endmodule