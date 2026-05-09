# Tang Nano 9K target profile

This directory contains the Tang Nano 9K bring-up profile for the NEORV32 Ascon accelerator integration.

The target board is intentionally treated as a **bring-up board** first, not as the final maximum-throughput FPGA target. The first objective is to prove:

```text
NEORV32 CPU -> XBUS -> Ascon accelerator -> software known-answer test
```

## Board assumptions

Initial target:

```text
Board:       Sipeed Tang Nano 9K
FPGA:        GW1NR-LV9QN88PC6/I5
Clock:       27 MHz onboard oscillator
Capacity:    8640 LUT4-class logic units
```

## Bring-up strategy

Start small and increase the accelerator only after a full SoC build works.

Recommended order:

```text
1. accelerator-only synthesis sweep using the variants in boards/tang-nano-9k/variants/
2. minimal NEORV32 + one encryption accelerator, RPC=1
3. NEORV32 software KAT over UART
4. try RPC=2
5. only then consider RPC=4, RPC=8, or dual encrypt/decrypt hardware
```

Avoid making the first hardware build too ambitious. A dual encrypt/decrypt accelerator with RPC=8 is unlikely to be the best first target on this device.

## Variants

```text
small.mk           encrypt, RPC=1
medium.mk          encrypt, RPC=2
fast-if-fits.mk    encrypt, RPC=4
decrypt-small.mk   decrypt, RPC=1
```

Use from the repository root:

```sh
make TANG_VARIANT=small board-tangnano9k-info
make TANG_VARIANT=small synth-tangnano9k-accel
make synth-tangnano9k-matrix
```

The current synthesis targets are still generic Yosys gates for accelerator sizing. Gowin place-and-route comes after we choose the exact NEORV32 top-level and pin constraints.
