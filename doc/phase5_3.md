# Phase 5.3 — Pin NEORV32 source and define Tang Nano 9K SoC manifest

Phase 5.3 prepares `ascon-neorv32` for a real NEORV32 SoC integration.

## Goal

Pin the NEORV32 source tree as a Git submodule and define the conservative Tang Nano 9K SoC bring-up policy before writing board-level VHDL.

## Rationale

The accelerator core is already split into `ascon-rtl` and pinned as a submodule. The NEORV32 SoC source should be handled the same way. This keeps the integration reproducible and avoids copying upstream processor files into this repository.

## Required submodules

```text
ascon-neorv32/
  deps/ascon-rtl/
  deps/neorv32/
```

## Bring-up profile

First hardware target:

```text
board:          Tang Nano 9K
accelerator:    one XBUS instance
mode:           encryption first
RPC:            1
FIFO depth:     small
I/O:            UART0 console
validation:     software known-answer test against vectors generated from ascon-c
```

## Non-goals for this phase

- no Gowin bitstream yet;
- no final board constraints yet;
- no DMA path yet;
- no dual encrypt/decrypt FPGA build yet;
- no maximum-throughput claim yet.

## Acceptance checks

```sh
git submodule update --init --recursive
./scripts/check_neorv32_submodule.sh
make board-tangnano9k-neorv32-info
make vectors && make sim && make sim-xbus-dual-smoke && make lint-verilator && make sw-host-check
```
