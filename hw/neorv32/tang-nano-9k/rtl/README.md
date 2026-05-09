# Tang Nano 9K NEORV32 RTL scaffold

This directory is for the future board-level NEORV32 top entity.

Current status:

- The accelerator-side single-instance XBUS peripheral is `rtl/tangnano9k_ascon_xbus_single.v`.
- The default bring-up configuration is encrypt-only, `ROUNDS_PER_CYCLE=1`, shallow FIFOs.
- The actual NEORV32 top-level VHDL integration is intentionally not claimed complete yet.

Next hardware task:

1. Instantiate `neorv32_top` from `deps/neorv32`.
2. Enable XBUS in the NEORV32 generics.
3. Connect the processor XBUS request/response signals to the Ascon XBUS peripheral.
4. Map the accelerator at `0xF000_0000`.
5. Keep only one Ascon instance for the first Tang Nano 9K fit attempt.
