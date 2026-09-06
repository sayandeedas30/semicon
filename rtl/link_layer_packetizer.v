module link_layer_packetizer (
    input wire clk,
    input wire rst_n,
    input wire [255:0] raw_bus_in,
    input wire valid_in,
    output reg [255:0] system_bus_out, // Connects directly to your PHY layer
    output reg valid_out
);

    reg [2:0] flit_counter;
    reg [255:0] running_crc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_counter <= 3'd0;
            running_crc <= 256'd0;
            system_bus_out <= 256'd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            valid_out <= 1'b1;
            
            if (flit_counter == 3'd7) begin
                // 8th Flit: End of FIU. Append Error Correction (XOR CRC)
                system_bus_out <= running_crc ^ raw_bus_in;
                flit_counter <= 3'd0;
                running_crc <= 256'd0; // Reset for next FIU packet
            end else begin
                // Flits 1-7: Pass payload, compute rolling CRC
                system_bus_out <= raw_bus_in;
                running_crc <= running_crc ^ raw_bus_in;
                flit_counter <= flit_counter + 1'b1;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule