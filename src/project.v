/*
 * Copyright (c) 2026
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_tetris (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire left;
  wire right;
  wire rotate;
  wire down;

  assign left   = ~ui_in[0];
  assign right  = ~ui_in[1];
  assign rotate = ~ui_in[2];
  assign down   = ~ui_in[3];

  wire [1:0] r_color;
  wire [1:0] g_color;
  wire [1:0] b_color;
  wire vga_hs;
  wire vga_vs;

  assign uo_out[0] = r_color[1];
  assign uo_out[1] = g_color[1];
  assign uo_out[2] = b_color[1];
  assign uo_out[3] = vga_vs;
  assign uo_out[4] = r_color[0];
  assign uo_out[5] = g_color[0];
  assign uo_out[6] = b_color[0];
  assign uo_out[7] = vga_hs;

  VGATetris vga_tetris (
      .clock(clk),
      .reset(~rst_n),
      .io_button1(left),
      .io_button2(right),
      .io_button3(rotate),
      .io_button4(down),
      .io_vgaR(r_color),
      .io_vgaG(g_color),
      .io_vgaB(b_color),
      .io_vgaHs(vga_hs),
      .io_vgaVs(vga_vs)
  );

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};

endmodule
