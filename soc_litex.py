#!/usr/bin/env python3
"""
LiteX-based AES-128 Accelerator SoC for PYNQ-Z2
=================================================
Builds a complete SoC containing:
  - VexRiscv soft CPU
  - Integrated ROM (firmware) and SRAM
  - LiteX UART peripheral (PMOD JA1/JA2)
  - Custom AES-128 CSR peripheral backed by aes_litex_wrapper.v
  - 125 MHz PL oscillator clock input

Usage:
    python3 soc_litex.py --build          # generate bitstream
    python3 soc_litex.py --load           # program FPGA via JTAG
    python3 soc_litex.py --build --load   # build then program
"""

import os
import sys
import argparse

from migen import *
from litex.gen import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.interconnect.csr import *
from litex.build.generic_platform import *
from litex.build.xilinx import XilinxPlatform, VivadoProgrammer

# ---------------------------------------------------------------------------
# Platform definition – PYNQ-Z2 (Xilinx XC7Z020-CLG400)
# ---------------------------------------------------------------------------
_io = [
    # 125 MHz onboard PL oscillator
    ("sys_clk", 0, Pins("H16"), IOStandard("LVCMOS33")),

    # Active-low board reset (BTNC on PYNQ-Z2)
    ("cpu_reset_n", 0, Pins("D19"), IOStandard("LVCMOS33")),

    # UART via PMOD JA (J1 header)
    #   JA1 = V12 → TX (FPGA drives)
    #   JA2 = W12 → RX (FPGA receives)
    ("serial", 0,
        Subsignal("tx", Pins("V12")),
        Subsignal("rx", Pins("W12")),
        IOStandard("LVCMOS33"),
    ),

    # On-board LEDs (LD0–LD3)
    ("user_led", 0, Pins("M14"), IOStandard("LVCMOS33")),
    ("user_led", 1, Pins("M15"), IOStandard("LVCMOS33")),
    ("user_led", 2, Pins("G14"), IOStandard("LVCMOS33")),
    ("user_led", 3, Pins("D18"), IOStandard("LVCMOS33")),
]

_connectors = []


class Platform(XilinxPlatform):
    """PYNQ-Z2 platform targeting the Zynq-7020 PL fabric."""
    default_clk_name   = "sys_clk"
    default_clk_period = 1e9 / 125e6  # ns

    def __init__(self):
        XilinxPlatform.__init__(
            self,
            device      = "xc7z020clg400-1",
            io          = _io,
            connectors  = _connectors,
            toolchain   = "vivado",
        )

    def create_programmer(self):
        return VivadoProgrammer()


# ---------------------------------------------------------------------------
# CRG – Clock and Reset Generator
# ---------------------------------------------------------------------------
class _CRG(LiteXModule):
    """Pass the 125 MHz oscillator directly to the system clock domain.

    A BUFG is inserted to promote the oscillator to the global clock network.
    The synchronous reset is derived from the active-low button (cpu_reset_n).
    """
    def __init__(self, platform, sys_clk_freq):
        self.cd_sys = ClockDomain()

        clk_in = platform.request("sys_clk")
        rst_n  = platform.request("cpu_reset_n")

        # Drive system clock through a global buffer
        self.specials += Instance("BUFG",
            i_I = clk_in,
            o_O = self.cd_sys.clk,
        )

        # Synchronous reset: active high internally, driven by active-low button
        self.comb += self.cd_sys.rst.eq(~rst_n)


# ---------------------------------------------------------------------------
# AES Peripheral
# ---------------------------------------------------------------------------
class AESPeripheral(LiteXModule):
    """LiteX CSR peripheral wrapping the Verilog AES-128 core.

    CSR registers (all 32-bit):
        ctrl   – [0] start trigger, [1] mode (0=enc, 1=dec)
        status – [0] done, [1] busy
        key0   – key bits [127:96]
        key1   – key bits [95:64]
        key2   – key bits [63:32]
        key3   – key bits [31:0]
        din0   – data-in bits [127:96]
        din1   – data-in bits [95:64]
        din2   – data-in bits [63:32]
        din3   – data-in bits [31:0]
        dout0  – data-out bits [127:96]
        dout1  – data-out bits [95:64]
        dout2  – data-out bits [63:32]
        dout3  – data-out bits [31:0]
    """

    def __init__(self, platform):
        # ---- Control / Status ----
        self._ctrl   = CSRStorage(32, description="AES control: [0]=start, [1]=mode(0=enc,1=dec)")
        self._status = CSRStatus(32,  description="AES status: [0]=done, [1]=busy")

        # ---- Key (128 bits as 4×32) ----
        self._key0 = CSRStorage(32, description="AES key [127:96]")
        self._key1 = CSRStorage(32, description="AES key [95:64]")
        self._key2 = CSRStorage(32, description="AES key [63:32]")
        self._key3 = CSRStorage(32, description="AES key [31:0]")

        # ---- Data In (128 bits as 4×32) ----
        self._din0 = CSRStorage(32, description="AES data-in [127:96]")
        self._din1 = CSRStorage(32, description="AES data-in [95:64]")
        self._din2 = CSRStorage(32, description="AES data-in [63:32]")
        self._din3 = CSRStorage(32, description="AES data-in [31:0]")

        # ---- Data Out (128 bits as 4×32) ----
        self._dout0 = CSRStatus(32, description="AES data-out [127:96]")
        self._dout1 = CSRStatus(32, description="AES data-out [95:64]")
        self._dout2 = CSRStatus(32, description="AES data-out [63:32]")
        self._dout3 = CSRStatus(32, description="AES data-out [31:0]")

        # ---- Internal signals ----
        done = Signal()
        busy = Signal()
        dout = Signal(128)

        # Wire status outputs
        self.comb += [
            self._status.status[0].eq(done),
            self._status.status[1].eq(busy),
        ]

        # Wire data-out (key0/din0/dout0 hold the most-significant word)
        self.comb += [
            self._dout0.status.eq(dout[96:128]),
            self._dout1.status.eq(dout[64:96]),
            self._dout2.status.eq(dout[32:64]),
            self._dout3.status.eq(dout[0:32]),
        ]

        # ---- Add Verilog RTL sources ----
        rtl_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rtl")
        for src in [
            "aes_sbox.v",
            "aes_inv_sbox.v",
            "aes_mixcol.v",
            "aes_inv_mixcol.v",
            "aes_key_expand.v",
            "aes_enc_round.v",
            "aes_dec_round.v",
            "aes_core.v",
            "aes_litex_wrapper.v",
        ]:
            platform.add_source(os.path.join(rtl_dir, src))

        # ---- Instantiate the Verilog wrapper ----
        # Cat() places the first argument at the LSB; key0 must be MSB ([127:96])
        # so we concatenate in reverse word order.
        self.specials += Instance("aes_litex_wrapper",
            i_clk   = ClockSignal("sys"),
            i_rst   = ResetSignal("sys"),
            i_start = self._ctrl.storage[0],
            i_mode  = self._ctrl.storage[1],
            o_done  = done,
            o_busy  = busy,
            i_key   = Cat(self._key3.storage,  self._key2.storage,
                          self._key1.storage,  self._key0.storage),
            i_din   = Cat(self._din3.storage,  self._din2.storage,
                          self._din1.storage,  self._din0.storage),
            o_dout  = dout,
        )


# ---------------------------------------------------------------------------
# SoC
# ---------------------------------------------------------------------------
class AESSoC(SoCCore):
    """AES-128 Accelerator SoC for PYNQ-Z2."""

    def __init__(self, platform, sys_clk_freq=int(125e6), **kwargs):
        # Default SoCCore settings suitable for a bare-metal firmware flow
        kwargs.setdefault("cpu_type",              "vexriscv")
        kwargs.setdefault("cpu_variant",           "standard")
        kwargs.setdefault("integrated_rom_size",   0x8000)   # 32 KB firmware ROM
        kwargs.setdefault("integrated_sram_size",  0x4000)   # 16 KB SRAM
        kwargs.setdefault("uart_name",             "serial")
        kwargs.setdefault("uart_baudrate",         115200)
        kwargs.setdefault("with_timer",            True)

        SoCCore.__init__(self, platform, sys_clk_freq,
            ident = "AES-128 Accelerator SoC on PYNQ-Z2",
            **kwargs,
        )

        # Clock and reset
        self.crg = _CRG(platform, sys_clk_freq)

        # AES peripheral – LiteX auto-discovers CSRs via naming convention
        self.aes = AESPeripheral(platform)


# ---------------------------------------------------------------------------
# Build entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Build the AES-128 LiteX SoC for PYNQ-Z2",
    )
    parser.add_argument("--build",        action="store_true", help="Build the bitstream")
    parser.add_argument("--load",         action="store_true", help="Load the bitstream via JTAG")
    parser.add_argument("--sys-clk-freq", default=125e6, type=float,
                        help="System clock frequency in Hz (default: 125 MHz)")
    args = parser.parse_args()

    platform = Platform()
    soc      = AESSoC(platform, sys_clk_freq=int(args.sys_clk_freq))

    builder = Builder(soc,
        output_dir   = "build",
        csr_json     = "build/csr.json",
        csr_csv      = "build/csr.csv",
    )

    build_kwargs = {}
    if args.build:
        builder.build(**build_kwargs)

    if args.load:
        prog = platform.create_programmer()
        prog.load_bitstream(os.path.join(
            builder.gateware_dir,
            soc.build_name + ".bit",
        ))


if __name__ == "__main__":
    main()
