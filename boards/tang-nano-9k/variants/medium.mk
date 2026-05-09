# Tang Nano 9K medium accelerator profile.
BOARD_NAME := tang-nano-9k
FPGA_DEVICE ?= GW1NR-LV9QN88PC6/I5
BOARD_CLOCK_HZ ?= 27000000
ACCEL_TOP := ascon_aead128_xbus
ACCEL_DECRYPT := 0
ACCEL_RPC := 2
ACCEL_PROFILE_NAME := medium-encrypt-rpc2
