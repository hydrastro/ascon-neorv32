# Phase 5.1 NEORV32 integration scaffold

This directory tracks the hardware integration plan for using the Ascon accelerator through the NEORV32 processor-external bus interface (XBUS).

## Current integration unit

The current hardware-facing top for a system that wants both operations is:

```text
rtl/ascon_aead128_xbus_dual.v
```

It exposes two independent 256-byte XBUS windows:

```text
0xF000_0000  encryption accelerator
0xF000_0100  decryption accelerator
```

Each window contains the generic `ascon_aead128_mmio32` register map from the `ascon-rtl` submodule.

## Why two windows?

The reusable RTL core intentionally selects encryption/decryption using an elaboration-time parameter. This keeps synthesis honest: an encryption build instantiates only the encryption datapath, and a decryption build instantiates only the decryption datapath. A system that wants both at runtime must instantiate two wrappers explicitly.

## NEORV32 hookup

Enable the NEORV32 external bus interface in the SoC configuration and connect the processor's XBUS/Wishbone-compatible signals to `ascon_aead128_xbus_dual`.

The exact signal names depend on the NEORV32 top-level version and the board/setup you use, but the required logical signals are:

```text
clk
reset, active-low at the Ascon wrapper boundary
address[31:0]
write_data[31:0]
read_data[31:0]
write_enable
byte_select[3:0]
strobe
cycle
acknowledge
error
interrupt
```

The current wrapper does not require burst support; all accesses are single 32-bit MMIO transfers.

## Software defaults

The demo driver defaults now match the dual-window wrapper:

```text
ASCON_ACCEL_ENC_BASE = 0xF0000000
ASCON_ACCEL_DEC_BASE = 0xF0000100
```

Override these at compile time if your SoC address map is different.
