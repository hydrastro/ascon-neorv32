# Source manifest fragment for the Ascon accelerator side of the Tang Nano 9K build.
# This is not a complete Gowin project yet; it is a reusable fragment for Phase 5.5.

set ASCON_RTL_DIR "deps/ascon-rtl"

add_file $ASCON_RTL_DIR/rtl/ascon_round_comb.v
add_file $ASCON_RTL_DIR/rtl/ascon_perm_unrolled.v
add_file $ASCON_RTL_DIR/rtl/ascon_stream_fifo.v
add_file $ASCON_RTL_DIR/rtl/ascon_block_packer32.v
add_file $ASCON_RTL_DIR/rtl/ascon_block_unpacker32.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_fullblock_enc.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_enc.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_enc_ad.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_dec_ad.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_enc_ad_buffered.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_dec_ad_buffered.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_buffered.v
add_file $ASCON_RTL_DIR/rtl/ascon_aead128_mmio32.v
add_file rtl/ascon_aead128_xbus.v
add_file rtl/tangnano9k_ascon_xbus_single.v
