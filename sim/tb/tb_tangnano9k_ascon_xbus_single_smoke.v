`timescale 1ns/1ps
`default_nettype none

module tb_tangnano9k_ascon_xbus_single_smoke;
  localparam [31:0] BASE = 32'hF000_0000;

  reg         clk = 1'b0;
  reg         rst_n = 1'b0;
  reg  [31:0] xbus_adr_i = 32'd0;
  reg  [31:0] xbus_dat_i = 32'd0;
  wire [31:0] xbus_dat_o;
  reg         xbus_we_i = 1'b0;
  reg  [3:0]  xbus_sel_i = 4'hf;
  reg         xbus_stb_i = 1'b0;
  reg         xbus_cyc_i = 1'b0;
  wire        xbus_ack_o;
  wire        xbus_err_o;
  wire        irq_o;

  integer errors = 0;
  reg [31:0] rdata;

  always #5 clk = ~clk;

  tangnano9k_ascon_xbus_single #(
    .DECRYPT(0),
    .ROUNDS_PER_CYCLE(1),
    .BASE_ADDR(BASE)
  ) dut (
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

  task xbus_idle;
    begin
      xbus_adr_i <= 32'd0;
      xbus_dat_i <= 32'd0;
      xbus_we_i  <= 1'b0;
      xbus_sel_i <= 4'hf;
      xbus_stb_i <= 1'b0;
      xbus_cyc_i <= 1'b0;
    end
  endtask

  task xbus_write;
    input [31:0] addr;
    input [31:0] data;
    integer timeout;
    begin
      @(negedge clk);
      xbus_adr_i <= addr;
      xbus_dat_i <= data;
      xbus_we_i  <= 1'b1;
      xbus_sel_i <= 4'hf;
      xbus_stb_i <= 1'b1;
      xbus_cyc_i <= 1'b1;
      timeout = 0;
      while (!xbus_ack_o && !xbus_err_o && timeout < 100) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      #1;
      if (xbus_err_o) begin
        $display("FAIL xbus write error addr=%08x", addr);
        errors = errors + 1;
      end
      if (!xbus_ack_o) begin
        $display("FAIL xbus write timeout addr=%08x", addr);
        errors = errors + 1;
      end
      @(negedge clk);
      xbus_idle();
    end
  endtask

  task xbus_read;
    input  [31:0] addr;
    output [31:0] data;
    integer timeout;
    begin
      @(negedge clk);
      xbus_adr_i <= addr;
      xbus_dat_i <= 32'd0;
      xbus_we_i  <= 1'b0;
      xbus_sel_i <= 4'hf;
      xbus_stb_i <= 1'b1;
      xbus_cyc_i <= 1'b1;
      timeout = 0;
      while (!xbus_ack_o && !xbus_err_o && timeout < 100) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      #1; // sample after registered read data has settled
      data = xbus_dat_o;
      if (xbus_err_o) begin
        $display("FAIL xbus read error addr=%08x", addr);
        errors = errors + 1;
      end
      if (!xbus_ack_o) begin
        $display("FAIL xbus read timeout addr=%08x", addr);
        errors = errors + 1;
      end
      @(negedge clk);
      xbus_idle();
    end
  endtask

  task expect_read;
    input [31:0] addr;
    input [31:0] expected;
    input [8*32-1:0] label;
    begin
      xbus_read(addr, rdata);
      if (rdata !== expected) begin
        $display("FAIL %0s got=%08x expected=%08x", label, rdata, expected);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    xbus_idle();
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    // Exercise the register path of the Tang Nano 9K single-instance profile.
    xbus_write(BASE + 32'h00, 32'h0000_0002); // CTRL.clear
    xbus_write(BASE + 32'h08, 32'd17);        // AD_BYTES
    xbus_write(BASE + 32'h0c, 32'd31);        // MSG_BYTES
    expect_read(BASE + 32'h08, 32'd17, "AD_BYTES");
    expect_read(BASE + 32'h0c, 32'd31, "MSG_BYTES");

    // Key/nonce register smoke.
    xbus_write(BASE + 32'h10, 32'h00112233);
    xbus_write(BASE + 32'h14, 32'h44556677);
    xbus_write(BASE + 32'h18, 32'h8899aabb);
    xbus_write(BASE + 32'h1c, 32'hccddeeff);
    expect_read(BASE + 32'h10, 32'h00112233, "KEY0");
    expect_read(BASE + 32'h1c, 32'hccddeeff, "KEY3");

    if (errors == 0) begin
      $display("ALL TANG NANO 9K SINGLE XBUS SMOKE TESTS PASSED");
    end else begin
      $display("TANG NANO 9K SINGLE XBUS SMOKE TESTS FAILED errors=%0d", errors);
      $fatal;
    end
    $finish;
  end
endmodule

`default_nettype wire
