#!/usr/bin/env bash
set -euo pipefail

# Run from the root of ascon-neorv32.
# This force-rewrites files that GitHub currently shows as one-line files.

python3 - <<'PY'
from pathlib import Path

files = {}

files['.gitignore'] = r'''# Build products
/build/

# Generated simulation vectors copied from core
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

# Helper scripts downloaded during development
fix_*.sh
apply_*.sh

# Nix/direnv local outputs
/result
/.direnv/
/.envrc
'''

files['.gitmodules'] = r'''[submodule "deps/ascon-rtl"]
	path = deps/ascon-rtl
	url = https://github.com/hydrastro/ascon-rtl.git
[submodule "deps/neorv32"]
	path = deps/neorv32
	url = https://github.com/stnolting/neorv32.git
'''

files['.github/workflows/ci.yml'] = r'''name: ascon-neorv32-ci

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
'''

files['scripts/check_neorv32_submodule.sh'] = r'''#!/usr/bin/env bash
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

printf 'NEORV32 dependency OK: %s\n' "$NEORV32_DIR"

if git -C "$NEORV32_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
  printf 'NEORV32 revision: %s\n' "$(git -C "$NEORV32_DIR" rev-parse --short HEAD)"
fi
'''

files['Makefile'] = r'''# SPDX-License-Identifier: Apache-2.0

IVERILOG  ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
CC        ?= cc

ASCON_RTL_DIR ?= deps/ascon-rtl
BUILD_DIR := build
GEN_DIR := sim/generated
RTL_DIR := rtl
TB_DIR := sim/tb
SW_DIR := sw/neorv32

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

TB_XBUS_FILE := $(TB_DIR)/tb_ascon_aead128_xbus.v
TB_XBUS_DUAL_FILE := $(TB_DIR)/tb_ascon_aead128_xbus_dual_smoke.v
VEC_AEAD_AD_FILE := $(GEN_DIR)/ascon_aead128_ad_vectors.vh

IVFLAGS := -g2005-sv -I$(GEN_DIR) -I$(ASCON_RTL_DIR)/rtl -I$(RTL_DIR)

.PHONY: all sim sim-xbus-iverilog \
  sim-xbus-enc-rpc1 sim-xbus-enc-rpc2 sim-xbus-enc-rpc4 sim-xbus-enc-rpc8 \
  sim-xbus-dec-rpc1 sim-xbus-dec-rpc2 sim-xbus-dec-rpc4 sim-xbus-dec-rpc8 \
  sim-xbus-dual-smoke \
  vectors lint-verilator synth-xbus-yosys synth-xbus-dual-yosys \
  synth-xbus-enc-rpc1 synth-xbus-enc-rpc2 synth-xbus-enc-rpc4 synth-xbus-enc-rpc8 \
  synth-xbus-dec-rpc1 synth-xbus-dec-rpc2 synth-xbus-dec-rpc4 synth-xbus-dec-rpc8 \
  sw-host-check sanity check-core clean \
  board-tangnano9k-info synth-tangnano9k-accel synth-tangnano9k-matrix \
  board-tangnano9k-neorv32-info

all: sim

sim: sim-xbus-iverilog sim-xbus-dual-smoke

sanity:
	./scripts/sanity_check_tree.sh

check-core:
	@if [ ! -f "$(ASCON_RTL_DIR)/Makefile" ]; then \
	  echo "ERROR: ASCON_RTL_DIR='$(ASCON_RTL_DIR)' does not look like an ascon-rtl checkout."; \
	  echo "If using the default layout, run:"; \
	  echo "  git submodule update --init --recursive"; \
	  echo "Or override with:"; \
	  echo "  make ASCON_RTL_DIR=/path/to/ascon-rtl"; \
	  exit 1; \
	fi

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
	@echo "Board: $${BOARD_NAME:-tang-nano-9k}"
	@echo "Variant: $(TANG_VARIANT)"
	@echo "FPGA_DEVICE: $(FPGA_DEVICE)"
	@echo "BOARD_CLOCK_HZ: $(BOARD_CLOCK_HZ)"
	@echo "ACCEL_TOP: $(ACCEL_TOP)"
	@echo "ACCEL_PROFILE_NAME: $(ACCEL_PROFILE_NAME)"
	@echo "ACCEL_DECRYPT: $(ACCEL_DECRYPT)"
	@echo "ACCEL_RPC: $(ACCEL_RPC)"

synth-tangnano9k-accel: check-core | $(BUILD_DIR)
	@test -f "$(TANG_VARIANT_FILE)" || { echo "ERROR: unknown TANG_VARIANT='$(TANG_VARIANT)'"; exit 1; }
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT $(ACCEL_DECRYPT) ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE $(ACCEL_RPC) ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_tangnano9k_$(TANG_VARIANT)_accel.txt
	cat $(BUILD_DIR)/yosys_tangnano9k_$(TANG_VARIANT)_accel.txt

synth-tangnano9k-matrix:
	$(MAKE) TANG_VARIANT=small synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=medium synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=fast-if-fits synth-tangnano9k-accel
	$(MAKE) TANG_VARIANT=decrypt-small synth-tangnano9k-accel

board-tangnano9k-neorv32-info:
	@echo "Tang Nano 9K NEORV32 bring-up scaffold"
	@echo "NEORV32_DIR=$${NEORV32_DIR:-deps/neorv32}"
	@echo "ASCON_RTL_DIR=$(ASCON_RTL_DIR)"
	@echo "Manifest: hw/neorv32/tang-nano-9k/neorv32_manifest.mk"
	@echo "Next milestone: instantiate one ascon_aead128_xbus peripheral on NEORV32 XBUS"
'''

for path, content in files.items():
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    # Normalize to LF and make sure final newline exists.
    p.write_text(content.replace('\r\n', '\n').replace('\r', '\n'), encoding='utf-8', newline='\n')

for path in files:
    n = len(Path(path).read_text(encoding='utf-8').splitlines())
    if n <= 1:
        raise SystemExit(f'ERROR: {path} still has {n} line(s)')
    print(f'{path}: {n} lines')
PY

chmod +x scripts/check_neorv32_submodule.sh

# Remove stale local build products so test results cannot be stale.
rm -rf build
rm -f sim/generated/*.vh

# Verify Git sees real changes if the public repo was malformed.
printf '\nLine count check:\n'
wc -l .gitignore .gitmodules Makefile .github/workflows/ci.yml scripts/check_neorv32_submodule.sh

printf '\nGit status:\n'
git status --short

printf '\nNow run:\n'
printf '  git submodule sync --recursive\n'
printf '  git submodule update --init --recursive\n'
printf '  make vectors && make sim && make sim-xbus-dual-smoke && make lint-verilator && make sw-host-check\n'
printf '  git add .gitignore .gitmodules Makefile .github/workflows/ci.yml scripts/check_neorv32_submodule.sh\n'
printf '  git commit -m "Fix repository newlines"\n'
printf '  git push\n'
