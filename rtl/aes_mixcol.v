// AES MixColumns — operates on a single 4-byte column.
// Each column is treated as a polynomial over GF(2^8):
//   [s'0]   [2 3 1 1] [s0]
//   [s'1] = [1 2 3 1] [s1]
//   [s'2]   [1 1 2 3] [s2]
//   [s'3]   [3 1 1 2] [s3]
// Reduction polynomial: x^8 + x^4 + x^3 + x + 1 (0x11b).
// See FIPS-197 Section 5.1.3.
module aes_mixcol (
    input  wire [31:0] col_in,    // {s0, s1, s2, s3} — s0 at MSB
    output wire [31:0] col_out
);

wire [7:0] s0, s1, s2, s3;
assign {s0, s1, s2, s3} = col_in;

// xtime: multiply by {02} in GF(2^8)
function [7:0] xtime;
    input [7:0] x;
    begin
        xtime = {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    end
endfunction

// Multiply by {03} = xtime(x) ^ x
function [7:0] xt3;
    input [7:0] x;
    begin
        xt3 = xtime(x) ^ x;
    end
endfunction

assign col_out[31:24] = xtime(s0) ^ xt3(s1)  ^ s2         ^ s3;
assign col_out[23:16] = s0         ^ xtime(s1) ^ xt3(s2)   ^ s3;
assign col_out[15:8]  = s0         ^ s1         ^ xtime(s2) ^ xt3(s3);
assign col_out[7:0]   = xt3(s0)   ^ s1         ^ s2         ^ xtime(s3);

endmodule
