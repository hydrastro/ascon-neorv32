#!/usr/bin/env bash
set -euo pipefail

bad_files=$(find . \( -name '*.rej' -o -name '*.orig' \) -print)
if [ -n "$bad_files" ]; then
  echo "ERROR: found stale patch files:"
  echo "$bad_files"
  exit 1
fi

for f in \
  rtl/ascon_aead128_xbus.v \
  sim/tb/tb_ascon_aead128_xbus.v \
  sw/neorv32/ascon_accel.h \
  sw/neorv32/ascon_accel.c \
  sw/neorv32/ascon_accel_demo.c \
  sw/neorv32/README.md \
  doc/phase4_2.md \
  doc/phase4_3.md \
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

echo "Sanity check passed: clean ascon-neorv32 tree."
