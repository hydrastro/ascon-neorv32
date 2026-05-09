# Tang Nano 9K aggressive single-accelerator profile.
# Use only after small/medium fit with NEORV32.
BOARD_NAME := tang-nano-9k
FPGA_DEVICE ?= GW1NR-LV9QN88PC6/I5
BOARD_CLOCK_HZ ?= 27000000
ACCEL_TOP := ascon_aead128_xbus
ACCEL_DECRYPT := 0
ACCEL_RPC := 4
ACCEL_PROFILE_NAME := fast-if-fits-encrypt-rpc4
