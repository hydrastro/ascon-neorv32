# Phase 5.5a — Gowin-oriented resource estimates

This phase adds Yosys `synth_gowin` estimates for the Tang Nano 9K single-accelerator scaffold.

These reports are not final Gowin place-and-route results. They are used to compare accelerator variants before integrating the full NEORV32 SoC.

## Commands

```sh
make TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin
make synth-tangnano9k-gowin-matrix
make report-gowin-stats
```

## First profiles

- encrypt, RPC=1
- encrypt, RPC=2
- encrypt, RPC=4
- decrypt, RPC=1
- decrypt, RPC=2

Avoid dual mode and RPC=8 on Tang Nano 9K until these estimates and the full SoC fit are understood.
