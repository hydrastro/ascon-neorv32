#!/usr/bin/env bash
set -euo pipefail

# Phase 5.5a: add Gowin-oriented synthesis/resource-estimate targets for
# the Tang Nano 9K single-accelerator scaffold.
# Run from the root of the ascon-neorv32 repository.

if [ ! -f Makefile ] || [ ! -d rtl ] || [ ! -d deps/ascon-rtl ]; then
  echo "ERROR: run this from the ascon-neorv32 repo root with deps/ascon-rtl initialized." >&2
  exit 1
fi

mkdir -p scripts doc build

cat > scripts/summarize_gowin_json.py <<'PY'
#!/usr/bin/env python3
"""Summarize Yosys JSON cell usage after synth_gowin.

This is intentionally lightweight: it does not try to replace Gowin PnR
reports. It counts mapped cell instances in the Yosys JSON netlist so we can
compare accelerator variants before integrating the full NEORV32 SoC.
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

if len(sys.argv) != 2:
    print("usage: summarize_gowin_json.py <yosys-json>", file=sys.stderr)
    sys.exit(2)

path = Path(sys.argv[1])
with path.open("r", encoding="utf-8") as f:
    design = json.load(f)

modules = design.get("modules", {})
total = Counter()
per_module = {}

for module_name, module in modules.items():
    counter = Counter()
    for cell in module.get("cells", {}).values():
        cell_type = str(cell.get("type", "<unknown>"))
        counter[cell_type] += 1
        total[cell_type] += 1
    if counter:
        per_module[module_name] = counter

print(f"file: {path}")
print("total mapped cells:")
for cell_type, count in sorted(total.items()):
    print(f"  {cell_type:24s} {count}")

# Convenience rollups. Cell names vary a little across Yosys versions, so match
# broad substrings instead of relying on a single exact name.
def rollup(*needles: str) -> int:
    needles_l = tuple(n.lower() for n in needles)
    return sum(count for cell_type, count in total.items()
               if any(n in cell_type.lower() for n in needles_l))

print("rollup:")
print(f"  lut_like                 {rollup('lut')}")
print(f"  ff_like                  {rollup('dff', 'dffe', 'dffr', 'dffs', 'dffsr')}")
print(f"  carry_alu_like           {rollup('alu', 'carry')}")
print(f"  memory_like              {rollup('ram', 'rom', 'spram', 'dpram')}")
print(f"  io_like                  {rollup('ibuf', 'obuf', 'iobuf')}")

print("largest modules by cell count:")
for module_name, counter in sorted(per_module.items(),
                                   key=lambda kv: sum(kv[1].values()),
                                   reverse=True)[:12]:
    print(f"  {module_name:60s} {sum(counter.values())}")
PY
chmod +x scripts/summarize_gowin_json.py

cat > scripts/report_gowin_stats.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

found=0
for summary in build/gowin_tangnano9k_single_*_summary.txt; do
  [ -f "$summary" ] || continue
  found=1
  echo "=== $summary ==="
  cat "$summary"
  echo
  log="${summary%_summary.txt}.txt"
  if [ -f "$log" ]; then
    echo "--- check/warning summary: $log ---"
    grep -E "Found and reported|Warnings:|ERROR:|Warning:" "$log" || true
    echo
  fi
done

if [ "$found" -eq 0 ]; then
  echo "No Gowin summaries found. Run one of:" >&2
  echo "  make synth-tangnano9k-single-gowin" >&2
  echo "  make synth-tangnano9k-gowin-matrix" >&2
  exit 1
fi
SH
chmod +x scripts/report_gowin_stats.sh

cat > doc/phase5_5a.md <<'MD'
# Phase 5.5a — Gowin-oriented Tang Nano 9K accelerator estimates

This phase adds Yosys `synth_gowin` targets for the conservative Tang Nano 9K
single-accelerator scaffold.

The goal is **not** final board timing closure. The goal is to get a mapped,
Gowin-oriented resource estimate before integrating the accelerator into a full
NEORV32 SoC.

## Default profile

```text
Top:        tangnano9k_ascon_xbus_single
Mode:       encryption
RPC:        1
Base addr:  0xF000_0000
```

## Commands

Single profile:

```sh
make TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin
make report-gowin-stats
```

Matrix:

```sh
make synth-tangnano9k-gowin-matrix
make report-gowin-stats
```

## Interpretation

Treat these as **pre-place-and-route estimates**. They are better than generic
Yosys cell counts because the design is mapped through `synth_gowin`, but final
fit and timing still require the Gowin toolchain/place-and-route flow.

For Tang Nano 9K bring-up, the priority order is:

1. `DECRYPT=0`, `RPC=1`
2. `DECRYPT=0`, `RPC=2`
3. `DECRYPT=1`, `RPC=1`
4. `DECRYPT=0`, `RPC=4` only if the estimates are still plausible

Do not target the dual encrypt/decrypt wrapper for first board integration.
MD

# Add Makefile section if it is not already present.
if ! grep -q '^# Phase 5.5a Gowin-oriented Tang Nano 9K estimates' Makefile; then
  cat >> Makefile <<'MK'

# -----------------------------------------------------------------------------
# Phase 5.5a Gowin-oriented Tang Nano 9K estimates
# -----------------------------------------------------------------------------
.PHONY: check-yosys-gowin \
        synth-tangnano9k-single-gowin \
        synth-tangnano9k-gowin-matrix \
        report-gowin-stats

check-yosys-gowin:
	@$(YOSYS) -Q -p 'help synth_gowin' >/dev/null 2>&1 || { \
		echo "ERROR: this Yosys build does not provide synth_gowin."; \
		echo "Use a Yosys/OSS CAD Suite build with Gowin support, or keep using the generic synth target."; \
		exit 1; \
	}

synth-tangnano9k-single-gowin: check-core check-yosys-gowin | $(BUILD_DIR)
	@test -f rtl/tangnano9k_ascon_xbus_single.v || { \
		echo "ERROR: missing rtl/tangnano9k_ascon_xbus_single.v"; \
		exit 1; \
	}
	$(YOSYS) -p 'read_verilog -sv $(CORE_RTL) $(TANG_SINGLE_RTL); \
		chparam -set ROUNDS_PER_CYCLE $(TANG_RPC) tangnano9k_ascon_xbus_single; \
		chparam -set DECRYPT $(TANG_DECRYPT) tangnano9k_ascon_xbus_single; \
		synth_gowin -top tangnano9k_ascon_xbus_single; \
		write_json $(BUILD_DIR)/gowin_tangnano9k_single_dec$(TANG_DECRYPT)_rpc$(TANG_RPC).json; \
		stat -top tangnano9k_ascon_xbus_single; \
		check' \
		> $(BUILD_DIR)/gowin_tangnano9k_single_dec$(TANG_DECRYPT)_rpc$(TANG_RPC).txt
	python3 scripts/summarize_gowin_json.py \
		$(BUILD_DIR)/gowin_tangnano9k_single_dec$(TANG_DECRYPT)_rpc$(TANG_RPC).json \
		| tee $(BUILD_DIR)/gowin_tangnano9k_single_dec$(TANG_DECRYPT)_rpc$(TANG_RPC)_summary.txt

synth-tangnano9k-gowin-matrix:
	$(MAKE) TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin
	$(MAKE) TANG_DECRYPT=0 TANG_RPC=2 synth-tangnano9k-single-gowin
	$(MAKE) TANG_DECRYPT=0 TANG_RPC=4 synth-tangnano9k-single-gowin
	$(MAKE) TANG_DECRYPT=1 TANG_RPC=1 synth-tangnano9k-single-gowin
	$(MAKE) TANG_DECRYPT=1 TANG_RPC=2 synth-tangnano9k-single-gowin

report-gowin-stats:
	scripts/report_gowin_stats.sh
MK
fi

# Keep sanity checker aware of the new scripts/docs without being too invasive.
if [ -f scripts/sanity_check_tree.sh ] && ! grep -q 'scripts/summarize_gowin_json.py' scripts/sanity_check_tree.sh; then
  python3 - <<'PY'
from pathlib import Path
p = Path('scripts/sanity_check_tree.sh')
s = p.read_text()
needle = 'Makefile .gitignore'
if needle in s:
    s = s.replace(needle, 'Makefile .gitignore scripts/summarize_gowin_json.py scripts/report_gowin_stats.sh doc/phase5_5a.md')
p.write_text(s)
PY
  chmod +x scripts/sanity_check_tree.sh
fi

# Best-effort formatting check: do not fail if make cannot dry-run custom target yet.
echo "Phase 5.5a Gowin estimate targets added. Next run:"
echo "  ./scripts/sanity_check_tree.sh"
echo "  make TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin"
echo "  make synth-tangnano9k-gowin-matrix"
echo "  make report-gowin-stats"
