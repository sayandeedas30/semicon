//2-bit of raw binary data to PAM4 Symbol using Gray encoding 
module gray_pam4_mapper (
    input wire [1:0] bin_in,
    output reg [1:0] symbol_out
);

    always @(*) begin
        case (bin_in)
            2'b00: symbol_out = 2'b00;
            2'b01: symbol_out = 2'b01;
            2'b10: symbol_out = 2'b11;
            2'b11: symbol_out = 2'b10;
            default: symbol_out = 2'b00;
        endcase
    end

endmodule