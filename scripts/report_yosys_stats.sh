#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  files=(build/*yosys*.txt build/*stat*.txt)
else
  files=("$@")
fi

for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  echo "=== $f ==="
  grep -E "^(=== |[[:space:]]+[0-9]+ cells|[[:space:]]+[0-9]+ wires|[[:space:]]+[0-9]+ wire bits|Warnings:|Found and reported)" "$f" || true
  echo
 done
