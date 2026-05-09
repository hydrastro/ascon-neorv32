#!/usr/bin/env bash
set -euo pipefail

NEORV32_DIR="${NEORV32_DIR:-deps/neorv32}"

if [ ! -d "$NEORV32_DIR" ]; then
  echo "ERROR: NEORV32 dependency directory not found: $NEORV32_DIR" >&2
  echo "Hint: git submodule add https://github.com/stnolting/neorv32.git deps/neorv32" >&2
  exit 1
fi

required=(
  "$NEORV32_DIR/rtl/core/neorv32_top.vhd"
  "$NEORV32_DIR/rtl/core/neorv32_package.vhd"
  "$NEORV32_DIR/sw/common/common.mk"
)

for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: required NEORV32 file missing: $f" >&2
    exit 1
  fi
done

printf 'NEORV32 dependency OK: %s\n' "$NEORV32_DIR"
if git -C "$NEORV32_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
  printf 'NEORV32 revision: %s\n' "$(git -C "$NEORV32_DIR" rev-parse --short HEAD)"
fi
