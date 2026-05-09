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
