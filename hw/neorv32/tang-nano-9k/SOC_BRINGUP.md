# Tang Nano 9K NEORV32 + Ascon bring-up plan

This directory tracks the board-level NEORV32 integration for the Ascon-AEAD128 XBUS accelerator.

## Current architectural decision

The first board build should be conservative:

- one accelerator instance, not dual encrypt/decrypt hardware;
- `ROUNDS_PER_CYCLE=1`;
- small FIFO depth;
- UART0-based software demo;
- XBUS memory-mapped accelerator window;
- no DMA/streaming path yet.

The dual-window wrapper is useful in simulation, but it is not the first Tang Nano 9K implementation target because it roughly doubles accelerator datapath area.

## Proposed memory map

| Region | Purpose |
|---:|---|
| `0xF000_0000` | Ascon encryption accelerator window |
| `0xF000_0100` | Optional Ascon decryption accelerator window |

For the first FPGA image, use only one window until resource/timing numbers are known.

## Dependency policy

`ascon-neorv32` pins two source dependencies as submodules:

- `deps/ascon-rtl` for the reusable accelerator core;
- `deps/neorv32` for the NEORV32 SoC source tree.

Do not copy NEORV32 source files into this repository. Keep the dependency pinned.

## Next implementation checkpoint

The next step after adding the NEORV32 submodule is to write a minimal VHDL top-level that instantiates:

1. the NEORV32 top entity with XBUS enabled;
2. one Ascon XBUS wrapper;
3. simple address decode / bus response glue if required;
4. clock/reset/UART pins for Tang Nano 9K.

The VHDL top should be added only after the exact NEORV32 version is pinned and inspected.
