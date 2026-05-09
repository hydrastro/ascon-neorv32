#!/usr/bin/env python3
"""
Definitively rewrite critical ascon-neorv32/ascon-rtl repo metadata/build files
with real newline characters and Makefile tabs.

Run from either:
  - ascon-neorv32 repo root
  - ascon-rtl repo root

Then run the commands printed at the end.
"""
from pathlib import Path
import sys

root = Path.cwd()
name = root.name

def write(path, text, executable=False):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8", newline="\n")
    if executable:
        p.chmod(0o755)
    print(f"wrote {path}: {text.count(chr(10))} lines")

ascon_neorv32_gitignore = """# Build products
/build/

# Generated simulation vectors
/sim/generated/*.vh

# Simulator outputs
*.vcd
*.fst
*.vvp

# Patch/editor/archive leftovers
*.rej
*.orig
*.patch
*.zip
*.tar.gz
*~

# Nix/direnv local outputs
/result
/.direnv/
/.envrc
"""

ascon_neorv32_gitmodules = """[submodule "deps/ascon-rtl"]
\tpath = deps/ascon-rtl
\turl = https://github.com/hydrastro/ascon-rtl.git

[submodule "deps/neorv32"]
\tpath = deps/neorv32
\turl = https://github.com/stnolting/neorv32.git
"""

ascon_neorv32_ci = """name: ascon-neorv32-ci

on:
  push:
  pull_request:

jobs:
  sim-lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout with submodules
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install tools
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential iverilog verilator yosys

      - name: Sanity check
        run: ./scripts/sanity_check_tree.sh

      - name: Check NEORV32 submodule
        run: ./scripts/check_neorv32_submodule.sh

      - name: Generate vectors
        run: make vectors

      - name: Simulate XBUS wrappers
        run: make sim

      - name: Simulate dual XBUS smoke
        run: make sim-xbus-dual-smoke

      - name: Verilator lint
        run: make lint-verilator

      - name: Host-compile software driver
        run: make sw-host-check
"""

check_neorv32 = """#!/usr/bin/env bash
set -euo pipefail

NEORV32_DIR="${NEORV32_DIR:-deps/neorv32}"

if [ ! -d "$NEORV32_DIR" ]; then
  echo "ERROR: NEORV32 dependency directory not found: $NEORV32_DIR" >&2
  echo "Hint: git submodule update --init --recursive" >&2
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

printf 'NEORV32 dependency OK: %s\\n' "$NEORV32_DIR"

if git -C "$NEORV32_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
  printf 'NEORV32 revision: %s\\n' "$(git -C "$NEORV32_DIR" rev-parse --short HEAD)"
fi
"""

neorv32_manifest = """# Tang Nano 9K / NEORV32 bring-up manifest for the Ascon accelerator.
#
# This file intentionally captures policy/configuration first. The actual
# Gowin project/top-level integration will be added after the source manifest
# and memory/boot strategy are confirmed.

NEORV32_DIR ?= deps/neorv32
ASCON_RTL_DIR ?= deps/ascon-rtl

# Conservative first-board target.
ASCON_XBUS_BASE_ENC ?= 0xF0000000
ASCON_XBUS_BASE_DEC ?= 0xF0000100
ASCON_RPC ?= 1
ASCON_DECRYPT ?= 0
ASCON_FIFO_DEPTH ?= 4

# Tang Nano 9K board facts used for planning.
TANG_NANO_9K_FPGA ?= GW1NR-LV9QN88PC6/I5
TANG_NANO_9K_CLK_HZ ?= 27000000

# First hardware milestone:
# - NEORV32 UART0 console
# - XBUS enabled
# - one Ascon XBUS accelerator instance first
# - no dual accelerator until single-instance timing/resource use is known
# - RPC=1 before RPC=2/4/8 experiments
"""

makefile = r"""# SPDX-License-Identifier: Apache-2.0

IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR ?= verilator
YOSYS    ?= yosys
CC       ?= cc

ASCON_RTL_DIR ?= deps/ascon-rtl
NEORV32_DIR   ?= deps/neorv32

BUILD_DIR := build
GEN_DIR   := sim/generated
RTL_DIR   := rtl
TB_DIR    := sim/tb
SW_DIR    := sw/neorv32

CORE_RTL_FILES := \
	$(ASCON_RTL_DIR)/rtl/ascon_round_comb.v \
	$(ASCON_RTL_DIR)/rtl/ascon_perm_unrolled.v \
	$(ASCON_RTL_DIR)/rtl/ascon_stream_fifo.v \
	$(ASCON_RTL_DIR)/rtl/ascon_block_packer32.v \
	$(ASCON_RTL_DIR)/rtl/ascon_block_unpacker32.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_fullblock_enc.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_enc.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_enc_ad.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_dec_ad.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_enc_ad_buffered.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_dec_ad_buffered.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_buffered.v \
	$(ASCON_RTL_DIR)/rtl/ascon_aead128_mmio32.v

NEORV32_RTL_FILES := \
	$(RTL_DIR)/ascon_aead128_xbus.v \
	$(RTL_DIR)/ascon_aead128_xbus_dual.v

RTL_FILES := $(CORE_RTL_FILES) $(NEORV32_RTL_FILES)

TB_XBUS_FILE      := $(TB_DIR)/tb_ascon_aead128_xbus.v
TB_XBUS_DUAL_FILE := $(TB_DIR)/tb_ascon_aead128_xbus_dual_smoke.v
VEC_AEAD_AD_FILE  := $(GEN_DIR)/ascon_aead128_ad_vectors.vh

IVFLAGS := -g2005-sv -I$(GEN_DIR) -I$(ASCON_RTL_DIR)/rtl -I$(RTL_DIR)

.PHONY: all sim sim-xbus-iverilog \
	sim-xbus-enc-rpc1 sim-xbus-enc-rpc2 sim-xbus-enc-rpc4 sim-xbus-enc-rpc8 \
	sim-xbus-dec-rpc1 sim-xbus-dec-rpc2 sim-xbus-dec-rpc4 sim-xbus-dec-rpc8 \
	sim-xbus-dual-smoke \
	vectors lint-verilator synth-xbus-yosys synth-xbus-dual-yosys \
	synth-xbus-enc-rpc1 synth-xbus-enc-rpc2 synth-xbus-enc-rpc4 synth-xbus-enc-rpc8 \
	synth-xbus-dec-rpc1 synth-xbus-dec-rpc2 synth-xbus-dec-rpc4 synth-xbus-dec-rpc8 \
	sw-host-check sanity check-core check-neorv32 clean \
	board-tangnano9k-info board-tangnano9k-neorv32-info \
	synth-tangnano9k-accel synth-tangnano9k-matrix

all: sim

sim: sim-xbus-iverilog sim-xbus-dual-smoke

sanity:
	./scripts/sanity_check_tree.sh

check-core:
	@if [ ! -f "$(ASCON_RTL_DIR)/Makefile" ]; then \
		echo "ERROR: ASCON_RTL_DIR='$(ASCON_RTL_DIR)' does not look like an ascon-rtl checkout."; \
		echo "Hint: git submodule update --init --recursive"; \
		exit 1; \
	fi

check-neorv32:
	./scripts/check_neorv32_submodule.sh

vectors: check-core $(VEC_AEAD_AD_FILE)

$(VEC_AEAD_AD_FILE): check-core | $(GEN_DIR)
	$(MAKE) -C $(ASCON_RTL_DIR) vectors-ascon-c
	cp $(ASCON_RTL_DIR)/sim/generated/ascon_aead128_ad_vectors.vh $@

sim-xbus-iverilog: sim-xbus-enc-rpc1 sim-xbus-enc-rpc2 sim-xbus-enc-rpc4 sim-xbus-enc-rpc8 \
	sim-xbus-dec-rpc1 sim-xbus-dec-rpc2 sim-xbus-dec-rpc4 sim-xbus-dec-rpc8

sim-xbus-dual-smoke: $(BUILD_DIR)/tb_ascon_aead128_xbus_dual_smoke.vvp
	$(VVP) $<

sim-xbus-enc-rpc1: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc1.vvp
	$(VVP) $<
sim-xbus-enc-rpc2: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc2.vvp
	$(VVP) $<
sim-xbus-enc-rpc4: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc4.vvp
	$(VVP) $<
sim-xbus-enc-rpc8: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc8.vvp
	$(VVP) $<

sim-xbus-dec-rpc1: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc1.vvp
	$(VVP) $<
sim-xbus-dec-rpc2: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc2.vvp
	$(VVP) $<
sim-xbus-dec-rpc4: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc4.vvp
	$(VVP) $<
sim-xbus-dec-rpc8: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc1.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=1 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc2.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=2 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc4.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=4 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc8.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=8 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc1.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=1 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc2.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=2 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc4.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=4 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)
$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc8.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=8 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dual_smoke.vvp: $(RTL_FILES) $(TB_XBUS_DUAL_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $(TB_XBUS_DUAL_FILE) $(RTL_FILES)

lint-verilator:
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(ASCON_RTL_DIR)/rtl -I$(RTL_DIR) --top-module ascon_aead128_xbus $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(ASCON_RTL_DIR)/rtl -I$(RTL_DIR) --top-module ascon_aead128_xbus_dual $(RTL_FILES)

synth-xbus-yosys: synth-xbus-enc-rpc1 synth-xbus-enc-rpc2 synth-xbus-enc-rpc4 synth-xbus-enc-rpc8 \
	synth-xbus-dec-rpc1 synth-xbus-dec-rpc2 synth-xbus-dec-rpc4 synth-xbus-dec-rpc8

synth-xbus-enc-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc1.txt
synth-xbus-enc-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc2.txt
synth-xbus-enc-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc4.txt
synth-xbus-enc-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc8.txt

synth-xbus-dec-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc1.txt
synth-xbus-dec-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc2.txt
synth-xbus-dec-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc4.txt
synth-xbus-dec-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc8.txt

synth-xbus-dual-yosys: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_xbus_dual; synth -top ascon_aead128_xbus_dual; stat -top ascon_aead128_xbus_dual' > $(BUILD_DIR)/yosys_xbus_dual_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_xbus_dual_stat_rpc8.txt

sw-host-check: | $(BUILD_DIR)
	$(CC) -std=c99 -Wall -Wextra -Werror -I$(SW_DIR) -c $(SW_DIR)/ascon_accel.c -o $(BUILD_DIR)/ascon_accel.o
	$(CC) -std=c99 -Wall -Wextra -Werror -I$(SW_DIR) -c $(SW_DIR)/ascon_accel_demo.c -o $(BUILD_DIR)/ascon_accel_demo.o

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GEN_DIR):
	mkdir -p $(GEN_DIR)

clean:
	rm -rf $(BUILD_DIR)

# -----------------------------------------------------------------------------
# Tang Nano 9K board-profile helpers
# -----------------------------------------------------------------------------

TANG_VARIANT ?= small
TANG_VARIANT_FILE := boards/tang-nano-9k/variants/$(TANG_VARIANT).mk
-include $(TANG_VARIANT_FILE)

board-tangnano9k-info:
	@test -f "$(TANG_VARIANT_FILE)" || { echo "ERROR: unknown TANG_VARIANT='$(TANG_VARIANT)'"; exit 1; }
	@echo "Board: tang-nano-9k"
	@echo "Variant: $(TANG_VARIANT)"
	@echo "FPGA_DEVICE: $(FPGA_DEVICE)"
	@echo "BOARD_CLOCK_HZ: $(BOARD_CLOCK_HZ)"
	@echo "ACCEL_TOP: $(ACCEL_TOP)"
	@echo "ACCEL_PROFILE_NAME: $(ACCEL_PROFILE_NAME)"
	@echo "ACCEL_DECRYPT: $(ACCEL_DECRYPT)"
	@echo "ACCEL_RPC: $(ACCEL_RPC)"

board-tangnano9k-neorv32-info: check-neorv32
	@echo "NEORV32_DIR: $(NEORV32_DIR)"
	@echo "ASCON_RTL_DIR: $(ASCON_RTL_DIR)"
	@echo "Manifest: hw/neorv32/tang-nano-9k/neorv32_manifest.mk"
	@echo "Next step: create minimal Tang Nano 9K NEORV32 top with XBUS accelerator."

synth-tangnano9k-accel: check-core | $(BUILD_DIR)
	@test -f "$(TANG_VARIANT_FILE)" || { echo "ERROR: unknown TANG_VARIANT='$(TANG_VARIANT)'"; exit 1; }
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT $(ACCEL_DECRYPT) ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE $(ACCEL_RPC) ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_tangnano9k_$(TANG_VARIANT)_accel.txt
	cat $(BUILD_DIR)/yosys_tangnano9k_$(TANG_VARIANT)_accel.txt

synth-tangnano9k-matrix:
	$(MAKE) TANG_VARIANT=small synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=medium synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=fast-if-fits synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=decrypt-small synth-tangnano9k-accel
"""

ascon_rtl_gitignore = """# Build products
/build/

# Generated simulation vectors
/sim/generated/*.vh

# Local external dependencies
/external/

# Simulator outputs
*.vcd
*.fst
*.vvp

# Patch/editor/archive leftovers
*.rej
*.orig
*.patch
*.zip
*.tar.gz
*~

# Nix/direnv local outputs
/result
/.direnv/
/.envrc
"""

if (root / "rtl/ascon_aead128_xbus.v").exists() and (root / "sw/neorv32").exists():
    write(".gitignore", ascon_neorv32_gitignore)
    write(".gitmodules", ascon_neorv32_gitmodules)
    write(".github/workflows/ci.yml", ascon_neorv32_ci)
    write("scripts/check_neorv32_submodule.sh", check_neorv32, executable=True)
    write("hw/neorv32/tang-nano-9k/neorv32_manifest.mk", neorv32_manifest)
    write("Makefile", makefile)
    print("\nRepo detected: ascon-neorv32")
    print("Next:")
    print("  git submodule sync --recursive")
    print("  git submodule update --init --recursive")
    print("  make clean && make vectors && make sim && make sim-xbus-dual-smoke && make lint-verilator && make sw-host-check")
    print("  git add .gitignore .gitmodules Makefile .github/workflows/ci.yml scripts/check_neorv32_submodule.sh hw/neorv32/tang-nano-9k/neorv32_manifest.mk")
    print('  git commit -m "Fix critical text-file newlines" && git push')
elif (root / "rtl/ascon_round_comb.v").exists() and (root / "rtl/ascon_aead128_mmio32.v").exists():
    write(".gitignore", ascon_rtl_gitignore)
    print("\nRepo detected: ascon-rtl")
    print("Next:")
    print("  ./scripts/sanity_check_tree.sh")
    print("  make clean && make vectors-ascon-c && make sim && make lint-verilator")
    print("  git add .gitignore")
    print('  git commit -m "Fix ignore file newlines" && git push')
else:
    print("ERROR: cannot identify repo. Run from ascon-neorv32 or ascon-rtl root.", file=sys.stderr)
    sys.exit(1)
