# Phase 5.1: NEORV32 dual XBUS integration scaffold

This phase adds the first SoC-shaped integration block for NEORV32.

## Added module

```text
rtl/ascon_aead128_xbus_dual.v
```

This module instantiates:

```text
0xF000_0000  ascon_aead128_xbus, DECRYPT=0
0xF000_0100  ascon_aead128_xbus, DECRYPT=1
```

The wrapper combines `ack`, `err`, `rdata`, and `irq` for a single XBUS-facing peripheral block.

## Why this exists

The underlying AEAD mode is selected by a synthesis/elaboration parameter. That is intentional: it avoids hiding duplicated encryption/decryption datapaths behind a runtime mux. The dual wrapper makes the duplication explicit when a complete runtime encrypt/decrypt peripheral is desired.

## Current verification

Phase 5.1 adds a smoke test:

```text
sim/tb/tb_ascon_aead128_xbus_dual_smoke.v
```

The test validates:

```text
- encryption address window decode
- decryption address window decode
- independent register state in each window
- miss/error behavior when ERROR_ON_MISS=1
```

The full cryptographic behavior remains covered by the single-window XBUS testbench.

## Next step

The next integration step is to choose one concrete NEORV32 setup or board target and add the actual top-level SoC wrapper/application build for that target.
