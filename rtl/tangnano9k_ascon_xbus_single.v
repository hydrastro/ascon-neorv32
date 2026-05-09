`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
//
// Tang Nano 9K conservative single-instance Ascon XBUS accelerator wrapper.
//
// This is the board-bring-up accelerator profile: one memory-mapped XBUS
// peripheral at BASE_ADDR, with elaboration-time selected encrypt/decrypt mode
// and permutation unroll factor.  The default is intentionally small for the
// GW1NR-9 device: encryption, RPC=1, shallow FIFOs.

`default_nettype none

module tangnano9k_ascon_xbus_single #(
  parameter integer DECRYPT             = 0,
  parameter integer ROUNDS_PER_CYCLE    = 1,
  parameter integer AD_FIFO_DEPTH_LOG2   = 2,
  parameter integer IN_FIFO_DEPTH_LOG2   = 2,
  parameter integer OUT_FIFO_DEPTH_LOG2  = 2,
  parameter [31:0]  BASE_ADDR           = 32'hF000_0000,
  parameter [31:0]  ADDR_MASK           = 32'hFFFF_FF00
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

  ascon_aead128_xbus #(
    .DECRYPT            (DECRYPT),
    .ROUNDS_PER_CYCLE   (ROUNDS_PER_CYCLE),
    .AD_FIFO_DEPTH_LOG2  (AD_FIFO_DEPTH_LOG2),
    .IN_FIFO_DEPTH_LOG2  (IN_FIFO_DEPTH_LOG2),
    .OUT_FIFO_DEPTH_LOG2 (OUT_FIFO_DEPTH_LOG2),
    .BASE_ADDR          (BASE_ADDR),
    .ADDR_MASK          (ADDR_MASK),
    .ERROR_ON_MISS      (0)
  ) u_ascon_xbus (
    .clk        (clk),
    .rst_n      (rst_n),
    .xbus_adr_i (xbus_adr_i),
    .xbus_dat_i (xbus_dat_i),
    .xbus_dat_o (xbus_dat_o),
    .xbus_we_i  (xbus_we_i),
    .xbus_sel_i (xbus_sel_i),
    .xbus_stb_i (xbus_stb_i),
    .xbus_cyc_i (xbus_cyc_i),
    .xbus_ack_o (xbus_ack_o),
    .xbus_err_o (xbus_err_o),
    .irq_o      (irq_o)
  );

endmodule

`default_nettype wire
