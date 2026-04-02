// AES InvMixColumns — operates on a single 4-byte column.
// Each column is treated as a polynomial over GF(2^8):
//   [s'0]   [14  11  13   9] [s0]
//   [s'1] = [ 9  14  11  13] [s1]
//   [s'2]   [13   9  14  11] [s2]
//   [s'3]   [11  13   9  14] [s3]
// Reduction polynomial: x^8 + x^4 + x^3 + x + 1 (0x11b).
// See FIPS-197 Section 5.3.3.
module aes_inv_mixcol (
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

// Multiply by {04}
function [7:0] xt4;
    input [7:0] x;
    begin
        xt4 = xtime(xtime(x));
    end
endfunction

// Multiply by {08}
function [7:0] xt8;
    input [7:0] x;
    begin
        xt8 = xtime(xtime(xtime(x)));
    end
endfunction

// Multiply by {09} = {08} ^ {01}
function [7:0] gf9;
    input [7:0] x;
    begin
        gf9 = xt8(x) ^ x;
    end
endfunction

// Multiply by {0b} = {08} ^ {02} ^ {01}
function [7:0] gf11;
    input [7:0] x;
    begin
        gf11 = xt8(x) ^ xtime(x) ^ x;
    end
endfunction

// Multiply by {0d} = {08} ^ {04} ^ {01}
function [7:0] gf13;
    input [7:0] x;
    begin
        gf13 = xt8(x) ^ xt4(x) ^ x;
    end
endfunction

// Multiply by {0e} = {08} ^ {04} ^ {02}
function [7:0] gf14;
    input [7:0] x;
    begin
        gf14 = xt8(x) ^ xt4(x) ^ xtime(x);
    end
endfunction

assign col_out[31:24] = gf14(s0) ^ gf11(s1) ^ gf13(s2) ^ gf9(s3);
assign col_out[23:16] = gf9(s0)  ^ gf14(s1) ^ gf11(s2) ^ gf13(s3);
assign col_out[15:8]  = gf13(s0) ^ gf9(s1)  ^ gf14(s2) ^ gf11(s3);
assign col_out[7:0]   = gf11(s0) ^ gf13(s1) ^ gf9(s2)  ^ gf14(s3);

endmodule
