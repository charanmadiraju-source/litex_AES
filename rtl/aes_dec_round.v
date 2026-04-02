// AES Decryption Round
// Performs one AES decryption round combinatorially:
//   InvShiftRows -> InvSubBytes -> AddRoundKey -> (InvMixColumns if not final)
// State byte ordering mirrors aes_enc_round (column-major, MSB first).
// See FIPS-197 Sections 5.3.1–5.3.4.
module aes_dec_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         is_final,   // 1 = skip InvMixColumns (last round)
    output wire [127:0] state_out
);

// --- InvShiftRows ---
// Inverse of ShiftRows: shift rows right.
// Row 0: no shift    — byte indices (col-major): 0,4,8,12
// Row 1: shift right 1 — becomes 13,1,5,9
// Row 2: shift right 2 — becomes 10,14,2,6
// Row 3: shift right 3 — becomes 7,11,15,3
//
// Extract input bytes
wire [7:0] b [0:15];
genvar gi;
generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : BYTE_EXTRACT
        assign b[gi] = state_in[127 - gi*8 -: 8];
    end
endgenerate

// After InvShiftRows (column-major):
//   col0: {b[0], b[13], b[10], b[7]}
//   col1: {b[4], b[1],  b[14], b[11]}
//   col2: {b[8], b[5],  b[2],  b[15]}
//   col3: {b[12],b[9],  b[6],  b[3]}
wire [7:0] isr_byte [0:15];
assign isr_byte[0]  = b[0];  assign isr_byte[1]  = b[13]; assign isr_byte[2]  = b[10]; assign isr_byte[3]  = b[7];
assign isr_byte[4]  = b[4];  assign isr_byte[5]  = b[1];  assign isr_byte[6]  = b[14]; assign isr_byte[7]  = b[11];
assign isr_byte[8]  = b[8];  assign isr_byte[9]  = b[5];  assign isr_byte[10] = b[2];  assign isr_byte[11] = b[15];
assign isr_byte[12] = b[12]; assign isr_byte[13] = b[9];  assign isr_byte[14] = b[6];  assign isr_byte[15] = b[3];

// --- InvSubBytes: 16 inverse S-box lookups ---
wire [7:0] isb [0:15];

generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : INV_SBOX_INST
        aes_inv_sbox inv_sbox_u (
            .in  (isr_byte[gi]),
            .out (isb[gi])
        );
    end
endgenerate

// --- AddRoundKey ---
wire [127:0] after_ark;
assign after_ark = {isb[0],  isb[1],  isb[2],  isb[3],
                    isb[4],  isb[5],  isb[6],  isb[7],
                    isb[8],  isb[9],  isb[10], isb[11],
                    isb[12], isb[13], isb[14], isb[15]} ^ round_key;

// --- InvMixColumns: per-column ---
wire [31:0] imc_col0, imc_col1, imc_col2, imc_col3;

aes_inv_mixcol imc0 (.col_in(after_ark[127:96]), .col_out(imc_col0));
aes_inv_mixcol imc1 (.col_in(after_ark[95:64]),  .col_out(imc_col1));
aes_inv_mixcol imc2 (.col_in(after_ark[63:32]),  .col_out(imc_col2));
aes_inv_mixcol imc3 (.col_in(after_ark[31:0]),   .col_out(imc_col3));

// Final round skips InvMixColumns
assign state_out = is_final
    ? after_ark
    : {imc_col0, imc_col1, imc_col2, imc_col3};

endmodule
