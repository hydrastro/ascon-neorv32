#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
files=(build/gowin_tangnano9k_single_dec*_rpc*.json)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No Gowin summaries found. Run one of:"
  echo "  make synth-tangnano9k-single-gowin"
  echo "  make synth-tangnano9k-gowin-matrix"
  exit 1
fi
for json in "${files[@]}"; do
  txt="${json%.json}.txt"
  echo "=== ${json} ==="
  scripts/summarize_gowin_json.py "$json"
  if [[ -f "$txt" ]]; then
    grep -E "Found and reported|Warnings:" "$txt" || true
  fi
  echo
done
