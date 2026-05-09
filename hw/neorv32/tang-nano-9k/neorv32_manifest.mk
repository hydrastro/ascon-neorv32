# Tang Nano 9K / NEORV32 bring-up manifest for the Ascon accelerator.
# This file intentionally captures policy/configuration first. The actual
# Gowin project/top-level integration will be added after the source manifest
# and memory/boot strategy are confirmed.

NEORV32_DIR ?= deps/neorv32
ASCON_RTL_DIR ?= deps/ascon-rtl

# Conservative first-board target.
ASCON_XBUS_BASE_ENC ?= 0xF0000000
ASCON_XBUS_BASE_DEC ?= 0xF0000100
ASCON_RPC ?= 1
ASCON_DECRYPT ?= 0
ASCON_FIFO_DEPTH ?= 4

# Tang Nano 9K board facts used for planning.
TANG_NANO_9K_FPGA ?= GW1NR-LV9QN88PC6/I5
TANG_NANO_9K_CLK_HZ ?= 27000000

# First hardware milestone:
#   - NEORV32 UART0 console
#   - XBUS enabled
#   - one Ascon XBUS accelerator instance first
#   - no dual accelerator until single-instance timing/resource use is known
#   - RPC=1 before RPC=2/4/8 experiments
