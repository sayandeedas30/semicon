//handles the 64 bit data lane by creating 32 instances of 2 bit mapper module
module lane_processor (
    input wire [63:0] raw_chunk,
    output wire [63:0] processed_chunk
);

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 2) begin : map_gen
            gray_pam4_mapper mapper_inst (
                .bin_in(raw_chunk[i+:2]),
                .symbol_out(processed_chunk[i+:2])
            );
        end
    endgenerate

endmodule