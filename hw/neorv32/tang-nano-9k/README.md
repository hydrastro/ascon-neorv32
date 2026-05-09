# NEORV32 Tang Nano 9K hardware integration

This directory is the future home of the board-specific NEORV32 top-level for Tang Nano 9K.

Current Phase 5.2 scope:

```text
- define board target strategy
- define accelerator sizing variants
- keep one XBUS accelerator as the initial hardware target
- do not yet claim a complete Gowin bitstream build
```

Planned top-level structure:

```text
Tang Nano 9K pins
  -> clock/reset/UART/JTAG wiring
  -> NEORV32 top
      -> XBUS external peripheral interface
          -> ascon_aead128_xbus
```

Initial address map:

```text
0xF000_0000  Ascon accelerator MMIO window
```

For the first board build, use a single accelerator instance. Dual encrypt/decrypt windows can be reintroduced later if resource usage allows.
