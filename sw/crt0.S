# crt0.S — Minimal RISC-V startup code for the LiteX VexRiscv SoC
#
# Responsibilities:
#   1. Set up the stack pointer.
#   2. Copy initialised data from ROM to SRAM (.data section).
#   3. Zero the BSS section.
#   4. Call main().
#   5. Spin in an infinite loop if main() returns (should not happen).
#
# Symbols provided by linker.ld:
#   _stack_top   – top of SRAM (initial stack pointer)
#   _data_start  – start of .data in SRAM
#   _data_end    – end   of .data in SRAM
#   _data_load   – load address of .data in ROM
#   _bss_start   – start of .bss
#   _bss_end     – end   of .bss

    .section .text.start, "ax"
    .global  _start
    .type    _start, @function

_start:
    /* ----------------------------------------------------------------
     * 1. Initialise stack pointer
     * ---------------------------------------------------------------- */
    la   sp, _stack_top

    /* ----------------------------------------------------------------
     * 2. Copy .data from ROM (load address) to SRAM (VMA)
     * ---------------------------------------------------------------- */
    la   t0, _data_load   /* source: ROM load address */
    la   t1, _data_start  /* destination: SRAM VMA    */
    la   t2, _data_end

.copy_data_loop:
    bge  t1, t2, .copy_data_done
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j    .copy_data_loop

.copy_data_done:

    /* ----------------------------------------------------------------
     * 3. Zero .bss
     * ---------------------------------------------------------------- */
    la   t0, _bss_start
    la   t1, _bss_end

.zero_bss_loop:
    bge  t0, t1, .zero_bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    .zero_bss_loop

.zero_bss_done:

    /* ----------------------------------------------------------------
     * 4. Call main
     * ---------------------------------------------------------------- */
    call main

    /* ----------------------------------------------------------------
     * 5. Spin forever (main should not return)
     * ---------------------------------------------------------------- */
.hang:
    j .hang
