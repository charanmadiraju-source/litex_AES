/*
 * main.c — AES-128 Accelerator Firmware for PYNQ-Z2 LiteX SoC
 *
 * Demonstrates the AES-128 hardware accelerator by:
 *   1. Loading the FIPS-197 Appendix B key.
 *   2. Encrypting the 16-byte string "Hello, PYNQ-Z2!\0".
 *   3. Decrypting the ciphertext back to plaintext.
 *   4. Printing all three values over UART at 115200 baud.
 *
 * Expected UART output:
 *   Plaintext  : Hello, PYNQ-Z2!
 *   Ciphertext : <16-byte hex>
 *   Decrypted  : Hello, PYNQ-Z2!
 *
 * Build with the LiteX bare-metal toolchain (see Makefile).
 * The LiteX-generated csr.h supplies CSR_AES_BASE and CSR_UART_BASE.
 */

#include <stdint.h>
#include <string.h>

/*
 * Include the LiteX-generated CSR header for base addresses.
 * This file is produced by the SoC builder and placed in build/software/include.
 */
#include <generated/csr.h>

#include "uart.h"
#include "aes_driver.h"

/* -------------------------------------------------------------------------
 * Constants
 * ------------------------------------------------------------------------- */

/* FIPS-197 Appendix B test key: 2b7e151628aed2a6abf7158809cf4f3c */
static const uint8_t aes_key[16] = {
    0x2b, 0x7e, 0x15, 0x16,
    0x28, 0xae, 0xd2, 0xa6,
    0xab, 0xf7, 0x15, 0x88,
    0x09, 0xcf, 0x4f, 0x3c,
};

/* Plaintext: "Hello, PYNQ-Z2!" + NUL terminator = 16 bytes */
static const uint8_t plaintext[16] = {
    'H', 'e', 'l', 'l', 'o', ',', ' ', 'P',
    'Y', 'N', 'Q', '-', 'Z', '2', '!', '\0'
};

/* -------------------------------------------------------------------------
 * Helpers
 * ------------------------------------------------------------------------- */

/**
 * print_bytes_as_str() – print 16 bytes as a printable ASCII string.
 * Non-printable bytes are replaced with '.'.
 */
static void print_bytes_as_str(const uint8_t *buf)
{
    int i;
    for (i = 0; i < 16; i++) {
        char c = (char)buf[i];
        if (c >= 0x20 && c <= 0x7e)
            uart_putchar(c);
        else if (c == '\0')
            break;              /* stop at null terminator */
        else
            uart_putchar('.');
    }
    uart_putchar('\r');
    uart_putchar('\n');
}

/* -------------------------------------------------------------------------
 * Main
 * ------------------------------------------------------------------------- */
int main(void)
{
    uint8_t cipher[16];
    uint8_t decrypted[16];

    /* Welcome banner */
    uart_puts("=== AES-128 Accelerator (LiteX / PYNQ-Z2) ===");

    /* Load the AES key once — it stays stable for all operations */
    aes_load_key(aes_key);

    /* ------------------------------------------------------------------ */
    /* ENCRYPT                                                              */
    /* ------------------------------------------------------------------ */
    aes_load_data(plaintext);
    aes_run(AES_MODE_ENCRYPT);
    aes_read_data(cipher);

    /* ------------------------------------------------------------------ */
    /* DECRYPT                                                              */
    /* ------------------------------------------------------------------ */
    aes_load_data(cipher);
    aes_run(AES_MODE_DECRYPT);
    aes_read_data(decrypted);

    /* ------------------------------------------------------------------ */
    /* Print results                                                        */
    /* ------------------------------------------------------------------ */
    uart_putstr("Plaintext  : ");
    print_bytes_as_str(plaintext);

    uart_putstr("Ciphertext : ");
    uart_print_hex(cipher, 16);
    uart_putchar('\r');
    uart_putchar('\n');

    uart_putstr("Decrypted  : ");
    print_bytes_as_str(decrypted);

    /* Verify round-trip */
    if (memcmp(plaintext, decrypted, 16) == 0)
        uart_puts("PASS: Decrypted output matches original plaintext.");
    else
        uart_puts("FAIL: Mismatch between plaintext and decrypted output!");

    /* Idle loop */
    while (1)
        ;

    return 0;
}
