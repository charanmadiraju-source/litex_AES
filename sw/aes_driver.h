/*
 * aes_driver.h — AES-128 Accelerator CSR Driver
 *
 * Provides register-access macros and a high-level aes_run() helper for the
 * LiteX CSR peripheral defined in soc_litex.py / aes_litex_wrapper.v.
 *
 * CSR base address AES_BASE is pulled from the LiteX-generated csr.h when
 * available; otherwise it must be defined before including this header.
 *
 * Register map (each register is 32-bit, byte-addressable):
 *   Offset  Name     Access  Description
 *   0x00    ctrl     W       [0]=start trigger, [1]=mode (0=enc, 1=dec)
 *   0x04    status   R       [0]=done, [1]=busy
 *   0x08    key0     W       Key bits [127:96]
 *   0x0c    key1     W       Key bits [95:64]
 *   0x10    key2     W       Key bits [63:32]
 *   0x14    key3     W       Key bits [31:0]
 *   0x18    din0     W       Data-in bits [127:96]
 *   0x1c    din1     W       Data-in bits [95:64]
 *   0x20    din2     W       Data-in bits [63:32]
 *   0x24    din3     W       Data-in bits [31:0]
 *   0x28    dout0    R       Data-out bits [127:96]
 *   0x2c    dout1    R       Data-out bits [95:64]
 *   0x30    dout2    R       Data-out bits [63:32]
 *   0x34    dout3    R       Data-out bits [31:0]
 *
 * Note: exact offsets depend on LiteX CSR allocation; update AES_BASE and
 * the offsets below from the generated build/csr.csv / csr.h after synthesis.
 */

#ifndef AES_DRIVER_H
#define AES_DRIVER_H

#include <stdint.h>

/* -------------------------------------------------------------------------
 * Base address
 * Override by defining AES_BASE before including this header, or rely on
 * the LiteX-generated csr.h which defines CSR_AES_BASE.
 * ------------------------------------------------------------------------- */
#ifdef CSR_AES_BASE
#  define AES_BASE  CSR_AES_BASE
#endif

#ifndef AES_BASE
#  error "AES_BASE is not defined. Include the LiteX-generated csr.h or define AES_BASE manually."
#endif

/* -------------------------------------------------------------------------
 * Register access helpers
 * ------------------------------------------------------------------------- */
#define _REG32(base, offset)  (*((volatile uint32_t *)((base) + (offset))))

/* -------------------------------------------------------------------------
 * Register definitions
 * ------------------------------------------------------------------------- */
#define AES_CTRL    _REG32(AES_BASE, 0x00)
#define AES_STATUS  _REG32(AES_BASE, 0x04)
#define AES_KEY0    _REG32(AES_BASE, 0x08)
#define AES_KEY1    _REG32(AES_BASE, 0x0c)
#define AES_KEY2    _REG32(AES_BASE, 0x10)
#define AES_KEY3    _REG32(AES_BASE, 0x14)
#define AES_DIN0    _REG32(AES_BASE, 0x18)
#define AES_DIN1    _REG32(AES_BASE, 0x1c)
#define AES_DIN2    _REG32(AES_BASE, 0x20)
#define AES_DIN3    _REG32(AES_BASE, 0x24)
#define AES_DOUT0   _REG32(AES_BASE, 0x28)
#define AES_DOUT1   _REG32(AES_BASE, 0x2c)
#define AES_DOUT2   _REG32(AES_BASE, 0x30)
#define AES_DOUT3   _REG32(AES_BASE, 0x34)

/* -------------------------------------------------------------------------
 * Bit-field constants
 * ------------------------------------------------------------------------- */
#define AES_CTRL_START  (1u << 0)
#define AES_CTRL_MODE   (1u << 1)   /* 0 = encrypt, 1 = decrypt */

#define AES_STATUS_DONE (1u << 0)
#define AES_STATUS_BUSY (1u << 1)

#define AES_MODE_ENCRYPT  0u
#define AES_MODE_DECRYPT  1u

/* -------------------------------------------------------------------------
 * High-level driver
 * ------------------------------------------------------------------------- */

/**
 * aes_load_key() – write the 128-bit key into the key CSRs.
 * @key: pointer to 16-byte array, key[0] = most-significant byte ([127:120]).
 */
static inline void aes_load_key(const uint8_t *key)
{
    AES_KEY0 = ((uint32_t)key[0]  << 24) | ((uint32_t)key[1]  << 16) |
               ((uint32_t)key[2]  <<  8) |  (uint32_t)key[3];
    AES_KEY1 = ((uint32_t)key[4]  << 24) | ((uint32_t)key[5]  << 16) |
               ((uint32_t)key[6]  <<  8) |  (uint32_t)key[7];
    AES_KEY2 = ((uint32_t)key[8]  << 24) | ((uint32_t)key[9]  << 16) |
               ((uint32_t)key[10] <<  8) |  (uint32_t)key[11];
    AES_KEY3 = ((uint32_t)key[12] << 24) | ((uint32_t)key[13] << 16) |
               ((uint32_t)key[14] <<  8) |  (uint32_t)key[15];
}

/**
 * aes_load_data() – write 16-byte input block into the din CSRs.
 * @data: pointer to 16-byte array, data[0] = most-significant byte.
 */
static inline void aes_load_data(const uint8_t *data)
{
    AES_DIN0 = ((uint32_t)data[0]  << 24) | ((uint32_t)data[1]  << 16) |
               ((uint32_t)data[2]  <<  8) |  (uint32_t)data[3];
    AES_DIN1 = ((uint32_t)data[4]  << 24) | ((uint32_t)data[5]  << 16) |
               ((uint32_t)data[6]  <<  8) |  (uint32_t)data[7];
    AES_DIN2 = ((uint32_t)data[8]  << 24) | ((uint32_t)data[9]  << 16) |
               ((uint32_t)data[10] <<  8) |  (uint32_t)data[11];
    AES_DIN3 = ((uint32_t)data[12] << 24) | ((uint32_t)data[13] << 16) |
               ((uint32_t)data[14] <<  8) |  (uint32_t)data[15];
}

/**
 * aes_read_data() – read 16-byte output block from the dout CSRs.
 * @data: pointer to 16-byte destination buffer.
 */
static inline void aes_read_data(uint8_t *data)
{
    uint32_t w;

    w = AES_DOUT0;
    data[0] = (w >> 24) & 0xff; data[1] = (w >> 16) & 0xff;
    data[2] = (w >>  8) & 0xff; data[3] =  w        & 0xff;

    w = AES_DOUT1;
    data[4] = (w >> 24) & 0xff; data[5] = (w >> 16) & 0xff;
    data[6] = (w >>  8) & 0xff; data[7] =  w        & 0xff;

    w = AES_DOUT2;
    data[8]  = (w >> 24) & 0xff; data[9]  = (w >> 16) & 0xff;
    data[10] = (w >>  8) & 0xff; data[11] =  w        & 0xff;

    w = AES_DOUT3;
    data[12] = (w >> 24) & 0xff; data[13] = (w >> 16) & 0xff;
    data[14] = (w >>  8) & 0xff; data[15] =  w        & 0xff;
}

/**
 * aes_run() – trigger the AES core and wait for completion.
 *
 * Writes start=1 with the requested mode, polls the done bit, then
 * de-asserts start.  On return the result is readable via aes_read_data().
 *
 * @mode: AES_MODE_ENCRYPT or AES_MODE_DECRYPT
 */
static inline void aes_run(uint32_t mode)
{
    /* Trigger: set start=1 (edge-detected inside the RTL wrapper) */
    AES_CTRL = AES_CTRL_START | (mode ? AES_CTRL_MODE : 0u);

    /* Poll until done */
    while (!(AES_STATUS & AES_STATUS_DONE))
        ;

    /* De-assert start so the wrapper can accept the next rising edge */
    AES_CTRL = 0u;
}

#endif /* AES_DRIVER_H */
