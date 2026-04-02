/* linker.ld — Bare-metal linker script for RISC-V VexRiscv on LiteX
 *
 * Memory layout mirrors the LiteX default for a SoC with:
 *   ROM  at 0x00000000 (integrated ROM, firmware boot)
 *   SRAM at 0x01000000 (integrated SRAM, data + stack)
 *
 * Verify these addresses against the generated build/csr.json after synthesis;
 * update ORIGIN values if LiteX placed ROM/SRAM at different addresses.
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    rom  (rx)  : ORIGIN = 0x00000000, LENGTH = 0x8000   /* 32 KB ROM  */
    sram (rwx) : ORIGIN = 0x01000000, LENGTH = 0x4000   /* 16 KB SRAM */
}

SECTIONS {
    /* ------------------------------------------------------------------
     * Text segment — placed in ROM
     * ------------------------------------------------------------------ */
    .text : {
        *(.text.start)      /* crt0 entry point first */
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > rom

    /* ------------------------------------------------------------------
     * Initialised data — loaded from ROM, copied to SRAM by crt0
     * ------------------------------------------------------------------ */
    .data : AT(ADDR(.text) + SIZEOF(.text)) {
        _data_start = .;
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > sram

    /* Load address of .data (in ROM) */
    _data_load = LOADADDR(.data);

    /* ------------------------------------------------------------------
     * BSS — zeroed by crt0
     * ------------------------------------------------------------------ */
    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > sram

    /* ------------------------------------------------------------------
     * Stack — grows downward from top of SRAM
     * ------------------------------------------------------------------ */
    _stack_top = ORIGIN(sram) + LENGTH(sram);
}
