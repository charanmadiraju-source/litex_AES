/*
 * uart.h — Bare-metal UART helpers for LiteX UART peripheral
 *
 * Provides putchar / puts / print_hex wrappers that poll the LiteX UART
 * txfull status bit before writing each character.
 *
 * The UART CSR base address is pulled from the LiteX-generated csr.h
 * (CSR_UART_BASE).  Define UART_BASE manually if csr.h is not available.
 *
 * LiteX UART register map (32-bit registers):
 *   +0x00  rxtx   – read: received byte; write: byte to transmit
 *   +0x04  txfull – [0]=1 when TX FIFO is full
 *   +0x08  rxempty– [0]=1 when RX FIFO is empty
 *   +0x0c  ev_status, +0x10 ev_pending, +0x14 ev_enable (interrupts, unused here)
 */

#ifndef UART_H
#define UART_H

#include <stdint.h>

/* -------------------------------------------------------------------------
 * Base address
 * ------------------------------------------------------------------------- */
#ifdef CSR_UART_BASE
#  define UART_BASE  CSR_UART_BASE
#endif

#ifndef UART_BASE
#  error "UART_BASE is not defined. Include the LiteX-generated csr.h or define UART_BASE manually."
#endif

/* -------------------------------------------------------------------------
 * Register access
 * ------------------------------------------------------------------------- */
#define _UART_REG(offset)  (*((volatile uint32_t *)(UART_BASE + (offset))))

#define UART_RXTX    _UART_REG(0x00)
#define UART_TXFULL  _UART_REG(0x04)
#define UART_RXEMPTY _UART_REG(0x08)

/* -------------------------------------------------------------------------
 * Primitives
 * ------------------------------------------------------------------------- */

/** uart_putchar() – send one character, blocking until TX FIFO has room. */
static inline void uart_putchar(char c)
{
    while (UART_TXFULL & 1u)
        ;
    UART_RXTX = (uint32_t)(unsigned char)c;
}

/** uart_puts() – send a null-terminated string followed by \r\n. */
static inline void uart_puts(const char *s)
{
    while (*s)
        uart_putchar(*s++);
    uart_putchar('\r');
    uart_putchar('\n');
}

/** uart_putstr() – send a null-terminated string without a line ending. */
static inline void uart_putstr(const char *s)
{
    while (*s)
        uart_putchar(*s++);
}

/**
 * uart_print_hex() – print @len bytes from @buf as uppercase hex,
 *                    two hex digits per byte, no separator.
 */
static inline void uart_print_hex(const uint8_t *buf, int len)
{
    static const char hex_chars[] = "0123456789ABCDEF";
    int i;
    for (i = 0; i < len; i++) {
        uart_putchar(hex_chars[(buf[i] >> 4) & 0xf]);
        uart_putchar(hex_chars[ buf[i]       & 0xf]);
    }
}

#endif /* UART_H */
