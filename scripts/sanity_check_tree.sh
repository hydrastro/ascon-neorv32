#!/usr/bin/env bash
set -euo pipefail

ASCON_RTL_DIR="${ASCON_RTL_DIR:-deps/ascon-rtl}"

bad_files=$(find . \( -name '*.rej' -o -name '*.orig' \) -print)
if [ -n "$bad_files" ]; then
  echo "ERROR: found stale patch files:"
  echo "$bad_files"
  exit 1
fi

for f in \
  rtl/ascon_aead128_xbus.v \
  rtl/ascon_aead128_xbus_dual.v \
  sim/tb/tb_ascon_aead128_xbus.v \
  sim/tb/tb_ascon_aead128_xbus_dual_smoke.v \
  sw/neorv32/ascon_accel.h \
  sw/neorv32/ascon_accel.c \
  sw/neorv32/ascon_accel_demo.c \
  sw/neorv32/README.md \
  doc/phase4_2.md \
  doc/phase4_3.md \
  boards/tang-nano-9k/README.md \
  boards/tang-nano-9k/variants/small.mk \
  boards/tang-nano-9k/variants/medium.mk \
  boards/tang-nano-9k/variants/fast-if-fits.mk \
  boards/tang-nano-9k/variants/decrypt-small.mk \
  hw/neorv32/tang-nano-9k/README.md \
  hw/neorv32/tang-nano-9k/ascon_xbus_map.vh \
  doc/phase5_2.md \
  doc/phase5_1.md \
  hw/neorv32/README.md \
  Makefile .gitignore; do
  test -f "$f" || { echo "ERROR: missing $f"; exit 1; }
done

if find rtl sim sw doc -type f \( -name '*.vvp' -o -name '*.vh' -o -name '*.zip' -o -name '*.patch' -o -name '*.tar.gz' \) | grep -q .; then
  echo "ERROR: generated/archive artifacts found in source directories"
  find rtl sim sw doc -type f \( -name '*.vvp' -o -name '*.vh' -o -name '*.zip' -o -name '*.patch' -o -name '*.tar.gz' \)
  exit 1
fi

grep -q '^/build/' .gitignore || { echo "ERROR: .gitignore must ignore /build/"; exit 1; }
grep -q '^/sim/generated/\*.vh' .gitignore || { echo "ERROR: .gitignore must ignore generated vectors"; exit 1; }

if [ ! -f "$ASCON_RTL_DIR/rtl/ascon_aead128_mmio32.v" ]; then
  echo "ERROR: ascon-rtl dependency not found at ASCON_RTL_DIR='$ASCON_RTL_DIR'"
  echo "If using the default submodule layout, run:"
  echo "  git submodule update --init --recursive"
  exit 1
fi

echo "Sanity check passed: clean ascon-neorv32 tree."

# NEORV32 optional dependency note: this repo can run wrapper-level tests with
# only deps/ascon-rtl. Board-level work additionally expects deps/neorv32.
if [ -d deps/neorv32 ] && [ ! -f deps/neorv32/rtl/core/neorv32_top.vhd ]; then
  echo "ERROR: deps/neorv32 exists but does not look like a NEORV32 checkout" >&2
  exit 1
fi
