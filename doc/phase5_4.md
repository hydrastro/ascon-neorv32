# Phase 5.4 - Tang Nano 9K single-accelerator scaffold

Goal: prepare the first Tang Nano 9K hardware bring-up profile without claiming a full NEORV32/Gowin bitstream yet.

This phase adds:

- `rtl/tangnano9k_ascon_xbus_single.v`: fixed board-bring-up wrapper around the existing XBUS accelerator.
- `sim/tb/tb_tangnano9k_ascon_xbus_single_smoke.v`: register-path smoke test.
- `hw/neorv32/tang-nano-9k/gowin/ascon_accel_sources.tcl`: accelerator source manifest fragment.
- `hw/neorv32/tang-nano-9k/sw/ascon_baseaddr.h`: base-address definition for board software.
- `scripts/report_yosys_stats.sh`: quick report helper for synthesis statistics.

Default hardware profile:

```text
BASE_ADDR        = 0xF000_0000
DECRYPT          = 0
ROUNDS_PER_CYCLE = 1
FIFO depths      = 4 entries each
```

The first board fit attempt should use a single encrypt accelerator. Dual encrypt/decrypt and higher RPC values remain synthesis experiments until resource usage on GW1NR-9 is known.
