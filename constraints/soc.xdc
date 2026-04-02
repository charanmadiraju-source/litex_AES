# soc.xdc — Xilinx Design Constraints for PYNQ-Z2
# AES-128 LiteX Accelerator SoC
#
# Board:   PYNQ-Z2 (TUL / Digilent)
# Device:  XC7Z020-CLG400-1 (Zynq-7020)
# Toolchain: Vivado
#
# Only PL-accessible pins are constrained here (no PS7 dependency).
# Verify pin assignments against the PYNQ-Z2 board schematic before
# running synthesis.

# ---------------------------------------------------------------------------
# System clock — 125 MHz PL oscillator
# ---------------------------------------------------------------------------
set_property PACKAGE_PIN H16 [get_ports sys_clk]
set_property IOSTANDARD  LVCMOS33 [get_ports sys_clk]
create_clock -period 8.000 -name sys_clk [get_ports sys_clk]

# ---------------------------------------------------------------------------
# CPU reset — BTNC push button (active low)
# ---------------------------------------------------------------------------
set_property PACKAGE_PIN D19 [get_ports cpu_reset_n]
set_property IOSTANDARD  LVCMOS33 [get_ports cpu_reset_n]

# ---------------------------------------------------------------------------
# UART — PMOD JA connector (J1)
#   JA1 = V12  TX (output from FPGA)
#   JA2 = W12  RX (input  to   FPGA)
# Connect a USB-UART adapter (e.g. FTDI FT232R) to JA1/JA2 and GND.
# ---------------------------------------------------------------------------
set_property PACKAGE_PIN V12 [get_ports serial_tx]
set_property IOSTANDARD  LVCMOS33 [get_ports serial_tx]

set_property PACKAGE_PIN W12 [get_ports serial_rx]
set_property IOSTANDARD  LVCMOS33 [get_ports serial_rx]

# ---------------------------------------------------------------------------
# On-board LEDs (LD0–LD3) — optional status indicators
# ---------------------------------------------------------------------------
set_property PACKAGE_PIN M14 [get_ports {user_led[0]}]
set_property PACKAGE_PIN M15 [get_ports {user_led[1]}]
set_property PACKAGE_PIN G14 [get_ports {user_led[2]}]
set_property PACKAGE_PIN D18 [get_ports {user_led[3]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {user_led[*]}]

# ---------------------------------------------------------------------------
# Timing constraints
# ---------------------------------------------------------------------------
# Relax I/O timing for PMOD UART (no strict timing needed for 115200 baud)
set_false_path -from [get_ports serial_rx]
set_false_path -to   [get_ports serial_tx]
set_false_path -to   [get_ports {user_led[*]}]
set_false_path -from [get_ports cpu_reset_n]

# ---------------------------------------------------------------------------
# Bitstream configuration
# ---------------------------------------------------------------------------
set_property CONFIG_VOLTAGE  3.3  [current_design]
set_property CFGBVS          VCCO [current_design]
