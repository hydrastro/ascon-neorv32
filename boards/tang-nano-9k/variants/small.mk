# Tang Nano 9K conservative bring-up profile.
BOARD_NAME := tang-nano-9k
FPGA_DEVICE ?= GW1NR-LV9QN88PC6/I5
BOARD_CLOCK_HZ ?= 27000000
ACCEL_TOP := ascon_aead128_xbus
ACCEL_DECRYPT := 0
ACCEL_RPC := 1
ACCEL_PROFILE_NAME := small-encrypt-rpc1
