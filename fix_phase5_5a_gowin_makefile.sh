#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f Makefile || ! -d rtl || ! -d deps/ascon-rtl ]]; then
  echo "ERROR: run this from the ascon-neorv32 repository root" >&2
  exit 1
fi

mkdir -p scripts build

cat > scripts/run_gowin_synth.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

DECRYPT="${1:-${TANG_DECRYPT:-0}}"
RPC="${2:-${TANG_RPC:-1}}"
ASCON_RTL_DIR="${ASCON_RTL_DIR:-deps/ascon-rtl}"
TOP="tangnano9k_ascon_xbus_single"
OUT_BASE="build/gowin_tangnano9k_single_dec${DECRYPT}_rpc${RPC}"
YS="${OUT_BASE}.ys"
TXT="${OUT_BASE}.txt"
JSON="${OUT_BASE}.json"

case "$DECRYPT" in
  0|1) ;;
  *) echo "ERROR: DECRYPT must be 0 or 1, got '$DECRYPT'" >&2; exit 2 ;;
esac
case "$RPC" in
  1|2|4|8) ;;
  *) echo "ERROR: RPC must be 1, 2, 4, or 8, got '$RPC'" >&2; exit 2 ;;
esac

mkdir -p build

cat > "$YS" <<EOF
read_verilog -sv \
  ${ASCON_RTL_DIR}/rtl/ascon_round_comb.v \
  ${ASCON_RTL_DIR}/rtl/ascon_perm_unrolled.v \
  ${ASCON_RTL_DIR}/rtl/ascon_stream_fifo.v \
  ${ASCON_RTL_DIR}/rtl/ascon_block_packer32.v \
  ${ASCON_RTL_DIR}/rtl/ascon_block_unpacker32.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_fullblock_enc.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_enc.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_enc_ad.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_dec_ad.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_enc_ad_buffered.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_dec_ad_buffered.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_buffered.v \
  ${ASCON_RTL_DIR}/rtl/ascon_aead128_mmio32.v \
  rtl/ascon_aead128_xbus.v \
  rtl/tangnano9k_ascon_xbus_single.v
chparam -set ROUNDS_PER_CYCLE ${RPC} ${TOP}
chparam -set DECRYPT ${DECRYPT} ${TOP}
synth_gowin -top ${TOP}
write_json ${JSON}
stat -top ${TOP}
check
EOF

echo "Running Gowin-oriented Yosys synthesis: DECRYPT=${DECRYPT} RPC=${RPC}"
yosys -s "$YS" > "$TXT"
echo "Wrote $TXT"
echo "Wrote $JSON"
EOS
chmod +x scripts/run_gowin_synth.sh

cat > scripts/summarize_gowin_json.py <<'EOS'
#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path

if len(sys.argv) != 2:
    print("usage: summarize_gowin_json.py <yosys-json>", file=sys.stderr)
    sys.exit(2)

path = Path(sys.argv[1])
with path.open() as f:
    data = json.load(f)

cells = Counter()
for mod in data.get("modules", {}).values():
    for cell in mod.get("cells", {}).values():
        cells[cell.get("type", "<unknown>")] += 1

def group_count(prefixes):
    return sum(n for t, n in cells.items() if any(t.startswith(p) for p in prefixes))

lut_like = group_count(["LUT", "$lut", "ALU"])
ff_like = group_count(["DFF", "DFFE", "SDFF", "DFFR", "DFFS", "$_DFF", "$_DFFE"])
mem_like = group_count(["RAM", "ROM", "SP", "DP"])
io_like = group_count(["IBUF", "OBUF", "TBUF", "IOBUF"])
carry_like = group_count(["CARRY", "ALU"])

total = sum(cells.values())
print(f"file: {path}")
print(f"total_cells: {total}")
print(f"lut_like: {lut_like}")
print(f"ff_like: {ff_like}")
print(f"carry_alu_like: {carry_like}")
print(f"memory_like: {mem_like}")
print(f"io_like: {io_like}")
print("top_cell_types:")
for typ, count in cells.most_common(20):
    print(f"  {typ}: {count}")
EOS
chmod +x scripts/summarize_gowin_json.py

cat > scripts/report_gowin_stats.sh <<'EOS'
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
EOS
chmod +x scripts/report_gowin_stats.sh

python3 - <<'PY'
from pathlib import Path

mf = Path('Makefile')
text = mf.read_text()
lines = text.splitlines(True)
remove_targets = {
    'synth-tangnano9k-single-gowin',
    'synth-tangnano9k-gowin-matrix',
    'report-gowin-stats',
    'repot-gowin-stats',
    'check-yosys-gowin',
}
new_lines = []
skip = False
for line in lines:
    stripped = line.lstrip()
    leading_ws = len(line) != len(stripped)
    if not leading_ws:
        token = line.split(':', 1)[0].strip()
        if ':' in line and token in remove_targets:
            skip = True
            continue
    if skip:
        if line.startswith(('\t', ' ')) or line.strip() == '' or line.startswith('#'):
            continue
        skip = False
    new_lines.append(line)

block = r'''

# -----------------------------------------------------------------------------
# Tang Nano 9K Gowin-oriented accelerator estimates
# -----------------------------------------------------------------------------
TANG_DECRYPT ?= 0
TANG_RPC ?= 1

.PHONY: synth-tangnano9k-single-gowin synth-tangnano9k-gowin-matrix report-gowin-stats check-yosys-gowin

synth-tangnano9k-single-gowin:
	@mkdir -p build
	@scripts/run_gowin_synth.sh $(TANG_DECRYPT) $(TANG_RPC)

synth-tangnano9k-gowin-matrix:
	@$(MAKE) TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin
	@$(MAKE) TANG_DECRYPT=0 TANG_RPC=2 synth-tangnano9k-single-gowin
	@$(MAKE) TANG_DECRYPT=0 TANG_RPC=4 synth-tangnano9k-single-gowin
	@$(MAKE) TANG_DECRYPT=1 TANG_RPC=1 synth-tangnano9k-single-gowin
	@$(MAKE) TANG_DECRYPT=1 TANG_RPC=2 synth-tangnano9k-single-gowin

report-gowin-stats:
	@scripts/report_gowin_stats.sh

check-yosys-gowin:
	@yosys -Q -p 'help synth_gowin' >/dev/null
	@echo "Yosys synth_gowin command is available."
'''
new_text = ''.join(new_lines).rstrip() + block + '\n'
mf.write_text(new_text)
PY

cat > doc/phase5_5a.md <<'EOS'
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
EOS

echo "Fixed Phase 5.5a Gowin Makefile targets and scripts."
echo "Run:"
echo "  make TANG_DECRYPT=0 TANG_RPC=1 synth-tangnano9k-single-gowin"
echo "  make synth-tangnano9k-gowin-matrix"
echo "  make report-gowin-stats"
