# Constraints placeholder

Do not add guessed Tang Nano 9K pin constraints here.

The first real `.cst` file should be derived from the Sipeed schematic and the chosen NEORV32 top-level pins. At minimum we will need:

```text
27 MHz clock input
UART RX/TX through the onboard USB-UART path
reset strategy
optional LEDs for heartbeat/status
JTAG kept available for programming/debug
```

Until those signals are fixed in the top-level, this directory remains documentation-only.
