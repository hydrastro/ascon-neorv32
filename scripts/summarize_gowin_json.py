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
