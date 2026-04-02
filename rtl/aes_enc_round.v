// AES Encryption Round
// Performs one AES encryption round combinatorially:
//   SubBytes -> ShiftRows -> (MixColumns if not final) -> AddRoundKey
// State byte ordering (column-major, MSB first):
//   [127:120]=row0,col0  [119:112]=row1,col0  [111:104]=row2,col0  [103:96]=row3,col0
//   [95:88]=row0,col1   [87:80]=row1,col1   [79:72]=row2,col1   [71:64]=row3,col1
//   [63:56]=row0,col2   [55:48]=row1,col2   [47:40]=row2,col2   [39:32]=row3,col2
//   [31:24]=row0,col3   [23:16]=row1,col3   [15:8]=row2,col3    [7:0]=row3,col3
// See FIPS-197 Sections 5.1.1–5.1.4.
module aes_enc_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         is_final,   // 1 = skip MixColumns (last round)
    output wire [127:0] state_out
);

// --- S-Box instantiation: 16 bytes ---
wire [7:0] sb [0:15];

genvar gi;
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : SBOX_INST
        aes_sbox sbox_u (
            .in  (state_in[127 - gi*8 -: 8]),
            .out (sb[gi])
        );
    end
endgenerate

// --- SubBytes output (same column-major layout) ---
// sb[0..15] = SubBytes of each byte

// --- ShiftRows ---
// Row 0 (bytes at col positions 0,1,2,3 with row=0): indices 0,4,8,12 — no shift
// Row 1 (row=1): indices 1,5,9,13 — shift left by 1: 5,9,13,1
// Row 2 (row=2): indices 2,6,10,14 — shift left by 2: 10,14,2,6
// Row 3 (row=3): indices 3,7,11,15 — shift left by 3: 15,3,7,11
//
// After ShiftRows in column-major layout:
//   col0: {sb[0], sb[5], sb[10], sb[15]}
//   col1: {sb[4], sb[9], sb[14], sb[3]}
//   col2: {sb[8], sb[13], sb[2], sb[7]}
//   col3: {sb[12], sb[1], sb[6], sb[11]}

wire [31:0] sr_col0 = {sb[0],  sb[5],  sb[10], sb[15]};
wire [31:0] sr_col1 = {sb[4],  sb[9],  sb[14], sb[3]};
wire [31:0] sr_col2 = {sb[8],  sb[13], sb[2],  sb[7]};
wire [31:0] sr_col3 = {sb[12], sb[1],  sb[6],  sb[11]};

// --- MixColumns ---
wire [31:0] mc_col0, mc_col1, mc_col2, mc_col3;

aes_mixcol mc0 (.col_in(sr_col0), .col_out(mc_col0));
aes_mixcol mc1 (.col_in(sr_col1), .col_out(mc_col1));
aes_mixcol mc2 (.col_in(sr_col2), .col_out(mc_col2));
aes_mixcol mc3 (.col_in(sr_col3), .col_out(mc_col3));

// Select mixed or straight (final round skips MixColumns)
wire [127:0] after_mix = is_final
    ? {sr_col0, sr_col1, sr_col2, sr_col3}
    : {mc_col0, mc_col1, mc_col2, mc_col3};

// --- AddRoundKey ---
assign state_out = after_mix ^ round_key;

endmodule
