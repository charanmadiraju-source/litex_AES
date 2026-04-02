// AES-128 Key Expansion
// Generates all 11 round keys from a 128-bit input key.
// Implemented combinatorially: all round keys are available in the same cycle.
// See FIPS-197 Section 5.2.
module aes_key_expand (
    input  wire [127:0] key,
    output wire [127:0] rk0,
    output wire [127:0] rk1,
    output wire [127:0] rk2,
    output wire [127:0] rk3,
    output wire [127:0] rk4,
    output wire [127:0] rk5,
    output wire [127:0] rk6,
    output wire [127:0] rk7,
    output wire [127:0] rk8,
    output wire [127:0] rk9,
    output wire [127:0] rk10
);

// AES S-Box as a function for SubWord in key schedule
function [7:0] sbox_f;
    input [7:0] x;
    begin
        case (x)
            8'h00: sbox_f = 8'h63; 8'h01: sbox_f = 8'h7c; 8'h02: sbox_f = 8'h77; 8'h03: sbox_f = 8'h7b;
            8'h04: sbox_f = 8'hf2; 8'h05: sbox_f = 8'h6b; 8'h06: sbox_f = 8'h6f; 8'h07: sbox_f = 8'hc5;
            8'h08: sbox_f = 8'h30; 8'h09: sbox_f = 8'h01; 8'h0a: sbox_f = 8'h67; 8'h0b: sbox_f = 8'h2b;
            8'h0c: sbox_f = 8'hfe; 8'h0d: sbox_f = 8'hd7; 8'h0e: sbox_f = 8'hab; 8'h0f: sbox_f = 8'h76;
            8'h10: sbox_f = 8'hca; 8'h11: sbox_f = 8'h82; 8'h12: sbox_f = 8'hc9; 8'h13: sbox_f = 8'h7d;
            8'h14: sbox_f = 8'hfa; 8'h15: sbox_f = 8'h59; 8'h16: sbox_f = 8'h47; 8'h17: sbox_f = 8'hf0;
            8'h18: sbox_f = 8'had; 8'h19: sbox_f = 8'hd4; 8'h1a: sbox_f = 8'ha2; 8'h1b: sbox_f = 8'haf;
            8'h1c: sbox_f = 8'h9c; 8'h1d: sbox_f = 8'ha4; 8'h1e: sbox_f = 8'h72; 8'h1f: sbox_f = 8'hc0;
            8'h20: sbox_f = 8'hb7; 8'h21: sbox_f = 8'hfd; 8'h22: sbox_f = 8'h93; 8'h23: sbox_f = 8'h26;
            8'h24: sbox_f = 8'h36; 8'h25: sbox_f = 8'h3f; 8'h26: sbox_f = 8'hf7; 8'h27: sbox_f = 8'hcc;
            8'h28: sbox_f = 8'h34; 8'h29: sbox_f = 8'ha5; 8'h2a: sbox_f = 8'he5; 8'h2b: sbox_f = 8'hf1;
            8'h2c: sbox_f = 8'h71; 8'h2d: sbox_f = 8'hd8; 8'h2e: sbox_f = 8'h31; 8'h2f: sbox_f = 8'h15;
            8'h30: sbox_f = 8'h04; 8'h31: sbox_f = 8'hc7; 8'h32: sbox_f = 8'h23; 8'h33: sbox_f = 8'hc3;
            8'h34: sbox_f = 8'h18; 8'h35: sbox_f = 8'h96; 8'h36: sbox_f = 8'h05; 8'h37: sbox_f = 8'h9a;
            8'h38: sbox_f = 8'h07; 8'h39: sbox_f = 8'h12; 8'h3a: sbox_f = 8'h80; 8'h3b: sbox_f = 8'he2;
            8'h3c: sbox_f = 8'heb; 8'h3d: sbox_f = 8'h27; 8'h3e: sbox_f = 8'hb2; 8'h3f: sbox_f = 8'h75;
            8'h40: sbox_f = 8'h09; 8'h41: sbox_f = 8'h83; 8'h42: sbox_f = 8'h2c; 8'h43: sbox_f = 8'h1a;
            8'h44: sbox_f = 8'h1b; 8'h45: sbox_f = 8'h6e; 8'h46: sbox_f = 8'h5a; 8'h47: sbox_f = 8'ha0;
            8'h48: sbox_f = 8'h52; 8'h49: sbox_f = 8'h3b; 8'h4a: sbox_f = 8'hd6; 8'h4b: sbox_f = 8'hb3;
            8'h4c: sbox_f = 8'h29; 8'h4d: sbox_f = 8'he3; 8'h4e: sbox_f = 8'h2f; 8'h4f: sbox_f = 8'h84;
            8'h50: sbox_f = 8'h53; 8'h51: sbox_f = 8'hd1; 8'h52: sbox_f = 8'h00; 8'h53: sbox_f = 8'hed;
            8'h54: sbox_f = 8'h20; 8'h55: sbox_f = 8'hfc; 8'h56: sbox_f = 8'hb1; 8'h57: sbox_f = 8'h5b;
            8'h58: sbox_f = 8'h6a; 8'h59: sbox_f = 8'hcb; 8'h5a: sbox_f = 8'hbe; 8'h5b: sbox_f = 8'h39;
            8'h5c: sbox_f = 8'h4a; 8'h5d: sbox_f = 8'h4c; 8'h5e: sbox_f = 8'h58; 8'h5f: sbox_f = 8'hcf;
            8'h60: sbox_f = 8'hd0; 8'h61: sbox_f = 8'hef; 8'h62: sbox_f = 8'haa; 8'h63: sbox_f = 8'hfb;
            8'h64: sbox_f = 8'h43; 8'h65: sbox_f = 8'h4d; 8'h66: sbox_f = 8'h33; 8'h67: sbox_f = 8'h85;
            8'h68: sbox_f = 8'h45; 8'h69: sbox_f = 8'hf9; 8'h6a: sbox_f = 8'h02; 8'h6b: sbox_f = 8'h7f;
            8'h6c: sbox_f = 8'h50; 8'h6d: sbox_f = 8'h3c; 8'h6e: sbox_f = 8'h9f; 8'h6f: sbox_f = 8'ha8;
            8'h70: sbox_f = 8'h51; 8'h71: sbox_f = 8'ha3; 8'h72: sbox_f = 8'h40; 8'h73: sbox_f = 8'h8f;
            8'h74: sbox_f = 8'h92; 8'h75: sbox_f = 8'h9d; 8'h76: sbox_f = 8'h38; 8'h77: sbox_f = 8'hf5;
            8'h78: sbox_f = 8'hbc; 8'h79: sbox_f = 8'hb6; 8'h7a: sbox_f = 8'hda; 8'h7b: sbox_f = 8'h21;
            8'h7c: sbox_f = 8'h10; 8'h7d: sbox_f = 8'hff; 8'h7e: sbox_f = 8'hf3; 8'h7f: sbox_f = 8'hd2;
            8'h80: sbox_f = 8'hcd; 8'h81: sbox_f = 8'h0c; 8'h82: sbox_f = 8'h13; 8'h83: sbox_f = 8'hec;
            8'h84: sbox_f = 8'h5f; 8'h85: sbox_f = 8'h97; 8'h86: sbox_f = 8'h44; 8'h87: sbox_f = 8'h17;
            8'h88: sbox_f = 8'hc4; 8'h89: sbox_f = 8'ha7; 8'h8a: sbox_f = 8'h7e; 8'h8b: sbox_f = 8'h3d;
            8'h8c: sbox_f = 8'h64; 8'h8d: sbox_f = 8'h5d; 8'h8e: sbox_f = 8'h19; 8'h8f: sbox_f = 8'h73;
            8'h90: sbox_f = 8'h60; 8'h91: sbox_f = 8'h81; 8'h92: sbox_f = 8'h4f; 8'h93: sbox_f = 8'hdc;
            8'h94: sbox_f = 8'h22; 8'h95: sbox_f = 8'h2a; 8'h96: sbox_f = 8'h90; 8'h97: sbox_f = 8'h88;
            8'h98: sbox_f = 8'h46; 8'h99: sbox_f = 8'hee; 8'h9a: sbox_f = 8'hb8; 8'h9b: sbox_f = 8'h14;
            8'h9c: sbox_f = 8'hde; 8'h9d: sbox_f = 8'h5e; 8'h9e: sbox_f = 8'h0b; 8'h9f: sbox_f = 8'hdb;
            8'ha0: sbox_f = 8'he0; 8'ha1: sbox_f = 8'h32; 8'ha2: sbox_f = 8'h3a; 8'ha3: sbox_f = 8'h0a;
            8'ha4: sbox_f = 8'h49; 8'ha5: sbox_f = 8'h06; 8'ha6: sbox_f = 8'h24; 8'ha7: sbox_f = 8'h5c;
            8'ha8: sbox_f = 8'hc2; 8'ha9: sbox_f = 8'hd3; 8'haa: sbox_f = 8'hac; 8'hab: sbox_f = 8'h62;
            8'hac: sbox_f = 8'h91; 8'had: sbox_f = 8'h95; 8'hae: sbox_f = 8'he4; 8'haf: sbox_f = 8'h79;
            8'hb0: sbox_f = 8'he7; 8'hb1: sbox_f = 8'hc8; 8'hb2: sbox_f = 8'h37; 8'hb3: sbox_f = 8'h6d;
            8'hb4: sbox_f = 8'h8d; 8'hb5: sbox_f = 8'hd5; 8'hb6: sbox_f = 8'h4e; 8'hb7: sbox_f = 8'ha9;
            8'hb8: sbox_f = 8'h6c; 8'hb9: sbox_f = 8'h56; 8'hba: sbox_f = 8'hf4; 8'hbb: sbox_f = 8'hea;
            8'hbc: sbox_f = 8'h65; 8'hbd: sbox_f = 8'h7a; 8'hbe: sbox_f = 8'hae; 8'hbf: sbox_f = 8'h08;
            8'hc0: sbox_f = 8'hba; 8'hc1: sbox_f = 8'h78; 8'hc2: sbox_f = 8'h25; 8'hc3: sbox_f = 8'h2e;
            8'hc4: sbox_f = 8'h1c; 8'hc5: sbox_f = 8'ha6; 8'hc6: sbox_f = 8'hb4; 8'hc7: sbox_f = 8'hc6;
            8'hc8: sbox_f = 8'he8; 8'hc9: sbox_f = 8'hdd; 8'hca: sbox_f = 8'h74; 8'hcb: sbox_f = 8'h1f;
            8'hcc: sbox_f = 8'h4b; 8'hcd: sbox_f = 8'hbd; 8'hce: sbox_f = 8'h8b; 8'hcf: sbox_f = 8'h8a;
            8'hd0: sbox_f = 8'h70; 8'hd1: sbox_f = 8'h3e; 8'hd2: sbox_f = 8'hb5; 8'hd3: sbox_f = 8'h66;
            8'hd4: sbox_f = 8'h48; 8'hd5: sbox_f = 8'h03; 8'hd6: sbox_f = 8'hf6; 8'hd7: sbox_f = 8'h0e;
            8'hd8: sbox_f = 8'h61; 8'hd9: sbox_f = 8'h35; 8'hda: sbox_f = 8'h57; 8'hdb: sbox_f = 8'hb9;
            8'hdc: sbox_f = 8'h86; 8'hdd: sbox_f = 8'hc1; 8'hde: sbox_f = 8'h1d; 8'hdf: sbox_f = 8'h9e;
            8'he0: sbox_f = 8'he1; 8'he1: sbox_f = 8'hf8; 8'he2: sbox_f = 8'h98; 8'he3: sbox_f = 8'h11;
            8'he4: sbox_f = 8'h69; 8'he5: sbox_f = 8'hd9; 8'he6: sbox_f = 8'h8e; 8'he7: sbox_f = 8'h94;
            8'he8: sbox_f = 8'h9b; 8'he9: sbox_f = 8'h1e; 8'hea: sbox_f = 8'h87; 8'heb: sbox_f = 8'he9;
            8'hec: sbox_f = 8'hce; 8'hed: sbox_f = 8'h55; 8'hee: sbox_f = 8'h28; 8'hef: sbox_f = 8'hdf;
            8'hf0: sbox_f = 8'h8c; 8'hf1: sbox_f = 8'ha1; 8'hf2: sbox_f = 8'h89; 8'hf3: sbox_f = 8'h0d;
            8'hf4: sbox_f = 8'hbf; 8'hf5: sbox_f = 8'he6; 8'hf6: sbox_f = 8'h42; 8'hf7: sbox_f = 8'h68;
            8'hf8: sbox_f = 8'h41; 8'hf9: sbox_f = 8'h99; 8'hfa: sbox_f = 8'h2d; 8'hfb: sbox_f = 8'h0f;
            8'hfc: sbox_f = 8'hb0; 8'hfd: sbox_f = 8'h54; 8'hfe: sbox_f = 8'hbb; 8'hff: sbox_f = 8'h16;
            default: sbox_f = 8'h00;
        endcase
    end
endfunction

// SubWord: apply S-Box to each byte of a 32-bit word
function [31:0] subword;
    input [31:0] w;
    begin
        subword = {sbox_f(w[31:24]), sbox_f(w[23:16]), sbox_f(w[15:8]), sbox_f(w[7:0])};
    end
endfunction

// RotWord: rotate word left by one byte: {a0,a1,a2,a3} -> {a1,a2,a3,a0}
function [31:0] rotword;
    input [31:0] w;
    begin
        rotword = {w[23:0], w[31:24]};
    end
endfunction

// Round constants (Rcon[i] for i=1..10), only the MSB matters
// Rcon[i] = {rc_i, 0x00, 0x00, 0x00}
// rc: 01 02 04 08 10 20 40 80 1b 36
localparam [7:0] RCON1  = 8'h01, RCON2  = 8'h02, RCON3  = 8'h04, RCON4  = 8'h08,
                 RCON5  = 8'h10, RCON6  = 8'h20, RCON7  = 8'h40, RCON8  = 8'h80,
                 RCON9  = 8'h1b, RCON10 = 8'h36;

// Key words W[0..43]
wire [31:0] w0, w1, w2, w3;
wire [31:0] w4, w5, w6, w7;
wire [31:0] w8, w9, w10, w11;
wire [31:0] w12, w13, w14, w15;
wire [31:0] w16, w17, w18, w19;
wire [31:0] w20, w21, w22, w23;
wire [31:0] w24, w25, w26, w27;
wire [31:0] w28, w29, w30, w31;
wire [31:0] w32, w33, w34, w35;
wire [31:0] w36, w37, w38, w39;
wire [31:0] w40, w41, w42, w43;

// W[0..3]: original key
assign w0 = key[127:96];
assign w1 = key[95:64];
assign w2 = key[63:32];
assign w3 = key[31:0];

// W[4..7]: round 1
assign w4  = w0 ^ subword(rotword(w3)) ^ {RCON1, 24'h0};
assign w5  = w1 ^ w4;
assign w6  = w2 ^ w5;
assign w7  = w3 ^ w6;

// W[8..11]: round 2
assign w8  = w4 ^ subword(rotword(w7)) ^ {RCON2, 24'h0};
assign w9  = w5 ^ w8;
assign w10 = w6 ^ w9;
assign w11 = w7 ^ w10;

// W[12..15]: round 3
assign w12 = w8  ^ subword(rotword(w11)) ^ {RCON3, 24'h0};
assign w13 = w9  ^ w12;
assign w14 = w10 ^ w13;
assign w15 = w11 ^ w14;

// W[16..19]: round 4
assign w16 = w12 ^ subword(rotword(w15)) ^ {RCON4, 24'h0};
assign w17 = w13 ^ w16;
assign w18 = w14 ^ w17;
assign w19 = w15 ^ w18;

// W[20..23]: round 5
assign w20 = w16 ^ subword(rotword(w19)) ^ {RCON5, 24'h0};
assign w21 = w17 ^ w20;
assign w22 = w18 ^ w21;
assign w23 = w19 ^ w22;

// W[24..27]: round 6
assign w24 = w20 ^ subword(rotword(w23)) ^ {RCON6, 24'h0};
assign w25 = w21 ^ w24;
assign w26 = w22 ^ w25;
assign w27 = w23 ^ w26;

// W[28..31]: round 7
assign w28 = w24 ^ subword(rotword(w27)) ^ {RCON7, 24'h0};
assign w29 = w25 ^ w28;
assign w30 = w26 ^ w29;
assign w31 = w27 ^ w30;

// W[32..35]: round 8
assign w32 = w28 ^ subword(rotword(w31)) ^ {RCON8, 24'h0};
assign w33 = w29 ^ w32;
assign w34 = w30 ^ w33;
assign w35 = w31 ^ w34;

// W[36..39]: round 9
assign w36 = w32 ^ subword(rotword(w35)) ^ {RCON9, 24'h0};
assign w37 = w33 ^ w36;
assign w38 = w34 ^ w37;
assign w39 = w35 ^ w38;

// W[40..43]: round 10
assign w40 = w36 ^ subword(rotword(w39)) ^ {RCON10, 24'h0};
assign w41 = w37 ^ w40;
assign w42 = w38 ^ w41;
assign w43 = w39 ^ w42;

// Pack round keys (each is 4 consecutive words)
assign rk0  = {w0,  w1,  w2,  w3};
assign rk1  = {w4,  w5,  w6,  w7};
assign rk2  = {w8,  w9,  w10, w11};
assign rk3  = {w12, w13, w14, w15};
assign rk4  = {w16, w17, w18, w19};
assign rk5  = {w20, w21, w22, w23};
assign rk6  = {w24, w25, w26, w27};
assign rk7  = {w28, w29, w30, w31};
assign rk8  = {w32, w33, w34, w35};
assign rk9  = {w36, w37, w38, w39};
assign rk10 = {w40, w41, w42, w43};

endmodule
