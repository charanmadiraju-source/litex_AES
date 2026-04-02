# Makefile — AES-128 LiteX SoC build automation for PYNQ-Z2
#
# Targets:
#   make gateware   — synthesise & implement the LiteX SoC (requires Vivado)
#   make firmware   — compile the bare-metal C firmware
#   make all        — gateware + firmware
#   make load       — program the FPGA via Vivado JTAG
#   make clean      — remove build artefacts

# ---------------------------------------------------------------------------
# Tool paths — adjust to match your installation
# ---------------------------------------------------------------------------
RISCV_PREFIX  ?= riscv32-unknown-elf-
CC             = $(RISCV_PREFIX)gcc
OBJCOPY        = $(RISCV_PREFIX)objcopy
OBJDUMP        = $(RISCV_PREFIX)objdump
SIZE           = $(RISCV_PREFIX)size

PYTHON         ?= python3

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------
SOC_SCRIPT     = soc_litex.py
BUILD_DIR      = build
SW_DIR         = sw
FW_BUILD_DIR   = $(BUILD_DIR)/firmware

# LiteX-generated include path (produced after running the SoC builder)
LITEX_INCLUDE  = $(BUILD_DIR)/software/include

# ---------------------------------------------------------------------------
# Firmware sources
# ---------------------------------------------------------------------------
FW_SRCS        = $(SW_DIR)/crt0.S \
                 $(SW_DIR)/main.c

FW_INCS        = -I$(SW_DIR) -I$(LITEX_INCLUDE)

# RISC-V rv32i with compressed instructions (matches VexRiscv 'standard' variant)
FW_ARCH        = -march=rv32i -mabi=ilp32

FW_CFLAGS      = $(FW_ARCH) -O2 -Wall -Wextra \
                 -ffreestanding -nostdlib -nostartfiles \
                 $(FW_INCS)

FW_LDFLAGS     = $(FW_ARCH) -ffreestanding -nostdlib -nostartfiles \
                 -T $(SW_DIR)/linker.ld \
                 -Wl,--gc-sections

FW_ELF         = $(FW_BUILD_DIR)/firmware.elf
FW_BIN         = $(FW_BUILD_DIR)/firmware.bin
FW_HEX         = $(FW_BUILD_DIR)/firmware.hex

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
.PHONY: all gateware firmware load clean help

all: gateware firmware

## gateware — run LiteX SoC builder (Vivado synthesis + implementation)
gateware:
	$(PYTHON) $(SOC_SCRIPT) --build

## firmware — compile bare-metal RISC-V firmware
firmware: $(FW_BIN)

$(FW_BUILD_DIR):
	mkdir -p $(FW_BUILD_DIR)

$(FW_ELF): $(FW_SRCS) $(SW_DIR)/linker.ld | $(FW_BUILD_DIR)
	$(CC) $(FW_CFLAGS) $(FW_LDFLAGS) -o $@ $(FW_SRCS)
	$(SIZE) $@

$(FW_BIN): $(FW_ELF)
	$(OBJCOPY) -O binary $< $@

$(FW_HEX): $(FW_ELF)
	$(OBJCOPY) -O ihex $< $@

## load — program the FPGA via Vivado JTAG
load:
	$(PYTHON) $(SOC_SCRIPT) --load

## clean — remove all build artefacts
clean:
	rm -rf $(BUILD_DIR)

## help — show this message
help:
	@echo "Targets: all  gateware  firmware  load  clean"
	@echo ""
	@echo "Variables:"
	@echo "  RISCV_PREFIX  RISC-V toolchain prefix (default: riscv32-unknown-elf-)"
	@echo "  PYTHON        Python interpreter      (default: python3)"
