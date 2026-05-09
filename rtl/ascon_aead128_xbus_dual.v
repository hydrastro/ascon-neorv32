`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Dual NEORV32 XBUS/Wishbone-style Ascon-AEAD128 peripheral.
//
// This module instantiates two independent ascon_aead128_xbus windows:
//   - encryption at ENC_BASE_ADDR
//   - decryption at DEC_BASE_ADDR
//
// The underlying AEAD core uses an elaboration-time DECRYPT parameter, so a
// runtime encrypt/decrypt selector would otherwise either duplicate hardware
// behind a mux or hide which datapath is being synthesized. This wrapper makes
// the duplication explicit for systems that want both operations mapped at the
// same time.

`default_nettype none

module ascon_aead128_xbus_dual #(
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2,
  parameter [31:0]  ENC_BASE_ADDR       = 32'hF000_0000,
  parameter [31:0]  DEC_BASE_ADDR       = 32'hF000_0100,
  parameter [31:0]  ADDR_MASK           = 32'hFFFF_FF00,
  parameter integer ERROR_ON_MISS       = 0
) (
  input  wire        clk,
  input  wire        rst_n,

  input  wire [31:0] xbus_adr_i,
  input  wire [31:0] xbus_dat_i,
  output wire [31:0] xbus_dat_o,
  input  wire        xbus_we_i,
  input  wire [3:0]  xbus_sel_i,
  input  wire        xbus_stb_i,
  input  wire        xbus_cyc_i,
  output wire        xbus_ack_o,
  output wire        xbus_err_o,

  output wire        irq_o
);

  wire [31:0] enc_dat_w;
  wire        enc_ack_w;
  wire        enc_err_w;
  wire        enc_irq_w;

  wire [31:0] dec_dat_w;
  wire        dec_ack_w;
  wire        dec_err_w;
  wire        dec_irq_w;

  ascon_aead128_xbus #(
    .DECRYPT            (0),
    .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2 (OUT_FIFO_DEPTH_LOG2),
    .BASE_ADDR          (ENC_BASE_ADDR),
    .ADDR_MASK          (ADDR_MASK),
    .ERROR_ON_MISS      (0)
  ) u_enc (
    .clk        (clk),
    .rst_n      (rst_n),
    .xbus_adr_i (xbus_adr_i),
    .xbus_dat_i (xbus_dat_i),
    .xbus_dat_o (enc_dat_w),
    .xbus_we_i  (xbus_we_i),
    .xbus_sel_i (xbus_sel_i),
    .xbus_stb_i (xbus_stb_i),
    .xbus_cyc_i (xbus_cyc_i),
    .xbus_ack_o (enc_ack_w),
    .xbus_err_o (enc_err_w),
    .irq_o      (enc_irq_w)
  );

  ascon_aead128_xbus #(
    .DECRYPT            (1),
    .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2 (OUT_FIFO_DEPTH_LOG2),
    .BASE_ADDR          (DEC_BASE_ADDR),
    .ADDR_MASK          (ADDR_MASK),
    .ERROR_ON_MISS      (0)
  ) u_dec (
    .clk        (clk),
    .rst_n      (rst_n),
    .xbus_adr_i (xbus_adr_i),
    .xbus_dat_i (xbus_dat_i),
    .xbus_dat_o (dec_dat_w),
    .xbus_we_i  (xbus_we_i),
    .xbus_sel_i (xbus_sel_i),
    .xbus_stb_i (xbus_stb_i),
    .xbus_cyc_i (xbus_cyc_i),
    .xbus_ack_o (dec_ack_w),
    .xbus_err_o (dec_err_w),
    .irq_o      (dec_irq_w)
  );

  assign xbus_ack_o = enc_ack_w | dec_ack_w;
  assign xbus_err_o = enc_err_w | dec_err_w |
                      ((ERROR_ON_MISS != 0) && xbus_cyc_i && xbus_stb_i &&
                       (((xbus_adr_i & ADDR_MASK) != ENC_BASE_ADDR) &&
                        ((xbus_adr_i & ADDR_MASK) != DEC_BASE_ADDR)));

  assign xbus_dat_o = enc_ack_w ? enc_dat_w :
                      dec_ack_w ? dec_dat_w :
                      32'd0;

  assign irq_o = enc_irq_w | dec_irq_w;

endmodule

`default_nettype wire
