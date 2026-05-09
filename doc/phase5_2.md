# Phase 5.2 — Tang Nano 9K target profile

Phase 5.2 introduces Tang Nano 9K as the first physical bring-up board.

This phase does **not** yet create a complete NEORV32 Gowin bitstream. It establishes a conservative board profile and accelerator synthesis variants so we can answer resource-fit questions before wiring the full SoC.

## Target

```text
Board: Sipeed Tang Nano 9K
FPGA:  GW1NR-LV9QN88PC6/I5
Clock: 27 MHz onboard oscillator
```

## Principle

The board is small. Therefore the first hardware build should not use the fastest or largest accelerator.

Initial profile:

```text
single accelerator instance
DECRYPT=0
ROUNDS_PER_CYCLE=1
small FIFO defaults from the core wrapper
```

After that works:

```text
try RPC=2
try RPC=4 only if there is comfortable timing/resource margin
add decryption or dual windows only if area allows
```

## Commands

```sh
make TANG_VARIANT=small board-tangnano9k-info
make TANG_VARIANT=small synth-tangnano9k-accel
make synth-tangnano9k-matrix
```

## Exit criteria

Phase 5.2 is complete when:

```text
- the board profile files are committed
- accelerator-only synthesis matrix runs
- we choose the first NEORV32 top-level configuration for Phase 5.3
```
