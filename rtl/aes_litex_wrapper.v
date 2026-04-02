// AES LiteX Peripheral Wrapper
// Bridges the flat AES core interface to LiteX CSR-visible signals.
// The Python LiteX module (soc_litex.py) instantiates this via Instance()
// and wires the ports to CSRStorage/CSRStatus registers.
//
// Rising-edge detection on the `start` input prevents the core from
// re-triggering if the firmware leaves the start CSR bit asserted.
//
// CSR map (managed by the Python LiteX module):
//   ctrl  [0]   – start trigger (write 1 to start)
//   ctrl  [1]   – mode: 0 = encrypt, 1 = decrypt
//   status[0]   – done
//   status[1]   – busy
//   key3..key0  – 128-bit key (key0 = [127:96])
//   din3..din0  – 128-bit data in
//   dout3..dout0– 128-bit data out (valid when done=1)
module aes_litex_wrapper (
    input  wire         clk,
    input  wire         rst,
    // Control / status
    input  wire         start,     // level from ctrl[0] CSR
    input  wire         mode,      // from ctrl[1] CSR
    output wire         done,
    output wire         busy,
    // Data
    input  wire [127:0] key,
    input  wire [127:0] din,
    output wire [127:0] dout
);

// Rising-edge detection on start so that holding start=1 only triggers once
reg start_r;
always @(posedge clk or posedge rst) begin
    if (rst) start_r <= 1'b0;
    else     start_r <= start;
end
wire start_pulse = start & ~start_r;

aes_core core (
    .clk   (clk),
    .rst   (rst),
    .start (start_pulse),
    .mode  (mode),
    .done  (done),
    .busy  (busy),
    .key   (key),
    .din   (din),
    .dout  (dout)
);

endmodule
