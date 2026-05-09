`timescale 1ns/1ps
// SPDX-License-Identifier: Apache-2.0
`default_nettype none

module tb_ascon_aead128_xbus_dual_smoke;
  localparam [31:0] ENC_BASE  = 32'hF000_0000;
  localparam [31:0] DEC_BASE  = 32'hF000_0100;
  localparam [31:0] MISS_ADDR = 32'hF000_0200;

  localparam [7:0] REG_CTRL      = 8'h00;
  localparam [7:0] REG_STATUS    = 8'h04;
  localparam [7:0] REG_AD_BYTES  = 8'h08;
  localparam [7:0] REG_MSG_BYTES = 8'h0c;

  reg         clk;
  reg         rst_n;
  reg [31:0] xbus_adr;
  reg [31:0] xbus_dat_i;
  wire [31:0] xbus_dat_o;
  reg         xbus_we;
  reg [3:0]   xbus_sel;
  reg         xbus_stb;
  reg         xbus_cyc;
  wire        xbus_ack;
  wire        xbus_err;
  wire        irq;

  integer errors;

  ascon_aead128_xbus_dual #(
    .ROUNDS_PER_CYCLE(2),
    .ENC_BASE_ADDR(ENC_BASE),
    .DEC_BASE_ADDR(DEC_BASE),
    .ERROR_ON_MISS(1)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .xbus_adr_i (xbus_adr),
    .xbus_dat_i (xbus_dat_i),
    .xbus_dat_o (xbus_dat_o),
    .xbus_we_i  (xbus_we),
    .xbus_sel_i (xbus_sel),
    .xbus_stb_i (xbus_stb),
    .xbus_cyc_i (xbus_cyc),
    .xbus_ack_o (xbus_ack),
    .xbus_err_o (xbus_err),
    .irq_o      (irq)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task xbus_idle;
    begin
      xbus_adr   = 32'd0;
      xbus_dat_i = 32'd0;
      xbus_we    = 1'b0;
      xbus_sel   = 4'hf;
      xbus_stb   = 1'b0;
      xbus_cyc   = 1'b0;
    end
  endtask

  task xbus_write;
    input [31:0] addr;
    input [31:0] data;
    integer cycles;
    begin
      @(negedge clk);
      xbus_adr   = addr;
      xbus_dat_i = data;
      xbus_we    = 1'b1;
      xbus_sel   = 4'hf;
      xbus_stb   = 1'b1;
      xbus_cyc   = 1'b1;

      cycles = 0;
      @(posedge clk); #1;
      while (!xbus_ack && !xbus_err && cycles < 200) begin
        cycles = cycles + 1;
        @(posedge clk); #1;
      end

      if (!xbus_ack || xbus_err) begin
        $display("FAIL xbus write addr=%08x ack=%0d err=%0d", addr, xbus_ack, xbus_err);
        errors = errors + 1;
      end

      @(negedge clk);
      xbus_idle();
    end
  endtask

  task xbus_read;
    input  [31:0] addr;
    output [31:0] data;
    integer cycles;
    begin
      @(negedge clk);
      xbus_adr   = addr;
      xbus_dat_i = 32'd0;
      xbus_we    = 1'b0;
      xbus_sel   = 4'hf;
      xbus_stb   = 1'b1;
      xbus_cyc   = 1'b1;

      cycles = 0;
      @(posedge clk); #1;
      while (!xbus_ack && !xbus_err && cycles < 200) begin
        cycles = cycles + 1;
        @(posedge clk); #1;
      end

      // Sample after the clock-edge NBA updates have settled. The xbus wrapper
      // registers xbus_dat_o on the same edge that asserts xbus_ack_o.
      data = xbus_dat_o;

      if (!xbus_ack || xbus_err) begin
        $display("FAIL xbus read addr=%08x ack=%0d err=%0d", addr, xbus_ack, xbus_err);
        errors = errors + 1;
      end

      @(negedge clk);
      xbus_idle();
    end
  endtask

  task xbus_expect_miss;
    input [31:0] addr;
    integer cycles;
    begin
      @(negedge clk);
      xbus_adr   = addr;
      xbus_dat_i = 32'd0;
      xbus_we    = 1'b0;
      xbus_sel   = 4'hf;
      xbus_stb   = 1'b1;
      xbus_cyc   = 1'b1;

      cycles = 0;
      @(posedge clk); #1;
      while (!xbus_err && cycles < 20) begin
        cycles = cycles + 1;
        @(posedge clk); #1;
      end

      if (!xbus_err) begin
        $display("FAIL expected xbus miss error addr=%08x", addr);
        errors = errors + 1;
      end

      @(negedge clk);
      xbus_idle();
    end
  endtask

  task expect_word;
    input [255:0] label;
    input [31:0]  got;
    input [31:0]  exp;
    begin
      if (got !== exp) begin
        $display("FAIL %0s got=%08x exp=%08x", label, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  reg [31:0] tmp;

  initial begin
    errors = 0;
    rst_n = 1'b0;
    xbus_idle();

    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    // Verify both windows are independently addressable.
    xbus_write(ENC_BASE + REG_CTRL, 32'h0000_0002); // clear enc
    xbus_write(DEC_BASE + REG_CTRL, 32'h0000_0002); // clear dec

    xbus_write(ENC_BASE + REG_AD_BYTES,  32'd17);
    xbus_write(ENC_BASE + REG_MSG_BYTES, 32'd31);
    xbus_write(DEC_BASE + REG_AD_BYTES,  32'd32);
    xbus_write(DEC_BASE + REG_MSG_BYTES, 32'd16);

    xbus_read(ENC_BASE + REG_AD_BYTES, tmp);
    expect_word("enc AD_BYTES", tmp, 32'd17);

    xbus_read(ENC_BASE + REG_MSG_BYTES, tmp);
    expect_word("enc MSG_BYTES", tmp, 32'd31);

    xbus_read(DEC_BASE + REG_AD_BYTES, tmp);
    expect_word("dec AD_BYTES", tmp, 32'd32);

    xbus_read(DEC_BASE + REG_MSG_BYTES, tmp);
    expect_word("dec MSG_BYTES", tmp, 32'd16);

    xbus_read(ENC_BASE + REG_STATUS, tmp);
    if ((tmp & 32'h1) == 32'd0) begin
      $display("FAIL enc STATUS start_ready not set got=%08x", tmp);
      errors = errors + 1;
    end

    xbus_read(DEC_BASE + REG_STATUS, tmp);
    if ((tmp & 32'h1) == 32'd0) begin
      $display("FAIL dec STATUS start_ready not set got=%08x", tmp);
      errors = errors + 1;
    end

    xbus_expect_miss(MISS_ADDR + REG_STATUS);

    if (errors == 0) begin
      $display("ALL DUAL XBUS SMOKE TESTS PASSED");
    end else begin
      $display("DUAL XBUS SMOKE TESTS FAILED errors=%0d", errors);
      $fatal;
    end

    $finish;
  end
endmodule

`default_nettype wire
