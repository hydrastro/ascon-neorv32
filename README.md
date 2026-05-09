# ascon-neorv32

NEORV32 integration layer for the reusable `ascon-rtl` Ascon-AEAD128 accelerator core.

This repository intentionally contains only NEORV32-facing code:

- `rtl/ascon_aead128_xbus.v` — XBUS/Wishbone-style wrapper around the generic `ascon_aead128_mmio32` core wrapper.
- `sim/tb/tb_ascon_aead128_xbus.v` — XBUS wrapper regression test.
- `sw/neorv32/` — C driver and demo code.

The reusable cryptographic RTL is expected as a pinned Git submodule at `deps/ascon-rtl`:

```text
ascon-neorv32/
  deps/ascon-rtl/
  rtl/
  sim/
  sw/
```

After cloning, initialize the dependency:

```sh
git submodule update --init --recursive
```

Then run:

```sh
nix develop
make sim
make lint-verilator
make sw-host-check
```

For local experiments, you can still override the core path:

```sh
make ASCON_RTL_DIR=/path/to/ascon-rtl sim
```

The committed/default build should use the submodule path so that the NEORV32 integration is pinned to an exact `ascon-rtl` revision.
