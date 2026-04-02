// AES-128 Core
// Top-level AES datapath and FSM.  Supports both encryption and decryption.
// Latency: 11 clock cycles after start is sampled (1 initial AddRoundKey +
//          9 full rounds + 1 final round).
//
// Interface:
//   start  – pulse to begin a new operation (rising-edge detected externally)
//   mode   – 0 = encrypt, 1 = decrypt
//   done   – asserted one cycle after final round; stays high until next start
//   busy   – asserted from start until done
//   key    – 128-bit AES key (stable while busy)
//   din    – 128-bit plaintext (encrypt) or ciphertext (decrypt)
//   dout   – 128-bit result, valid when done is high
module aes_core (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire         mode,
    output reg          done,
    output reg          busy,
    input  wire [127:0] key,
    input  wire [127:0] din,
    output reg  [127:0] dout
);

// -----------------------------------------------------------------------
// Round key generation (combinatorial, all 11 keys available immediately)
// -----------------------------------------------------------------------
wire [127:0] rk0, rk1, rk2, rk3, rk4, rk5, rk6, rk7, rk8, rk9, rk10;

aes_key_expand key_exp (
    .key  (key),
    .rk0  (rk0),  .rk1  (rk1),  .rk2  (rk2),  .rk3  (rk3),
    .rk4  (rk4),  .rk5  (rk5),  .rk6  (rk6),  .rk7  (rk7),
    .rk8  (rk8),  .rk9  (rk9),  .rk10 (rk10)
);

// -----------------------------------------------------------------------
// Round key mux: select current round key based on round counter
// Encryption uses  rk[round],      decryption uses rk[10 - round]
// -----------------------------------------------------------------------
reg [3:0] round;    // 1..10 during WORK

reg [127:0] curr_rk_enc, curr_rk_dec;

always @(*) begin : RK_MUX_ENC
    case (round)
        4'd1:  curr_rk_enc = rk1;
        4'd2:  curr_rk_enc = rk2;
        4'd3:  curr_rk_enc = rk3;
        4'd4:  curr_rk_enc = rk4;
        4'd5:  curr_rk_enc = rk5;
        4'd6:  curr_rk_enc = rk6;
        4'd7:  curr_rk_enc = rk7;
        4'd8:  curr_rk_enc = rk8;
        4'd9:  curr_rk_enc = rk9;
        4'd10: curr_rk_enc = rk10;
        default: curr_rk_enc = rk0;
    endcase
end

always @(*) begin : RK_MUX_DEC
    // Decryption key order: rk10, rk9, ..., rk1, rk0
    // round=1 → rk9, round=2 → rk8, ..., round=9 → rk1, round=10 → rk0
    case (round)
        4'd1:  curr_rk_dec = rk9;
        4'd2:  curr_rk_dec = rk8;
        4'd3:  curr_rk_dec = rk7;
        4'd4:  curr_rk_dec = rk6;
        4'd5:  curr_rk_dec = rk5;
        4'd6:  curr_rk_dec = rk4;
        4'd7:  curr_rk_dec = rk3;
        4'd8:  curr_rk_dec = rk2;
        4'd9:  curr_rk_dec = rk1;
        4'd10: curr_rk_dec = rk0;
        default: curr_rk_dec = rk10;
    endcase
end

// -----------------------------------------------------------------------
// Combinatorial round computation
// -----------------------------------------------------------------------
reg  [127:0] state_reg;
wire         is_final = (round == 4'd10);

wire [127:0] enc_out;
wire [127:0] dec_out;

aes_enc_round enc_r (
    .state_in  (state_reg),
    .round_key (curr_rk_enc),
    .is_final  (is_final),
    .state_out (enc_out)
);

aes_dec_round dec_r (
    .state_in  (state_reg),
    .round_key (curr_rk_dec),
    .is_final  (is_final),
    .state_out (dec_out)
);

// -----------------------------------------------------------------------
// FSM
// -----------------------------------------------------------------------
localparam IDLE = 1'b0;
localparam WORK = 1'b1;

reg fsm_state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fsm_state <= IDLE;
        done      <= 1'b0;
        busy      <= 1'b0;
        round     <= 4'd0;
        state_reg <= 128'h0;
        dout      <= 128'h0;
    end else begin
        case (fsm_state)
            IDLE: begin
                if (start) begin
                    // Initial AddRoundKey: enc uses rk0, dec uses rk10
                    state_reg <= din ^ (mode ? rk10 : rk0);
                    round     <= 4'd1;
                    busy      <= 1'b1;
                    done      <= 1'b0;
                    fsm_state <= WORK;
                end
            end

            WORK: begin
                if (!mode) begin
                    state_reg <= enc_out;
                end else begin
                    state_reg <= dec_out;
                end

                if (round == 4'd10) begin
                    dout      <= mode ? dec_out : enc_out;
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    fsm_state <= IDLE;
                end else begin
                    round <= round + 4'd1;
                end
            end

            default: fsm_state <= IDLE;
        endcase
    end
end

endmodule
