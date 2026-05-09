# ascon-neorv32

NEORV32 integration layer for the reusable `ascon-rtl` Ascon-AEAD128 accelerator core.

This repository intentionally contains only NEORV32-facing code:

- `rtl/ascon_aead128_xbus.v` — XBUS/Wishbone-style wrapper around the generic `ascon_aead128_mmio32` core wrapper.
- `sim/tb/tb_ascon_aead128_xbus.v` — XBUS wrapper regression test.
- `sw/neorv32/` — C driver and demo code.

The reusable cryptographic RTL lives in the sibling `ascon-rtl` repository. For local development, keep both repos side by side:

```text
wscon/
  ascon-rtl/
  ascon-neorv32/
```

Then run:

```sh
nix develop
make sim
make lint-verilator
make sw-host-check
```

If the core repo is somewhere else, set:

```sh
make ASCON_RTL_DIR=/path/to/ascon-rtl sim
```
