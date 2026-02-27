`default_nettype none  //disable implicit definitions by Verilog

module vga_tetris_top (  //top module and signals wired to FPGA pins
    input        CLK100MHz,  // Oscillator input 100Mhz
    input        button_1,
    input        button_2,
    input        button_3,
    input        button_4,
    output [2:0] vga_r,      // VGA Red 3 bit
    output [2:0] vga_g,      // VGA Green 3 bit
    output [2:0] vga_b,      // VGA Blue 3 bit
    output       vga_hs,     // H-sync pulse
    output       vga_vs      // V-sync pulse
);

  wire pll_locked;
  wire vga_clk;

  wire  [9:0]    px_x;
  wire  [9:0]    px_y;

  logic   [7:0] reset_timer = 8'b0;  // 8 bit timer with 0 initialization
  logic reset_active;
  logic reset;

  assign reset = (!pll_locked || reset_active) ? 1 : 0;

  always_ff @(posedge vga_clk) begin
    if (pll_locked) begin
      if (reset_timer > 250) begin
        reset_active <= 0;
      end else begin
        reset_active <= 1;
        reset_timer  <= reset_timer + 1;
      end
    end
  end

  pll pll_instance (
      .clock_in(CLK100MHz),
      .clock_out(vga_clk),
      .locked(pll_locked)
  );

  logic [1:0] io_vgaR;
  logic [1:0] io_vgaG;
  logic [1:0] io_vgaB;

  assign vga_r = {1'b0, io_vgaR};
  assign vga_g = {1'b0, io_vgaG};
  assign vga_b = {1'b0, io_vgaB};

  wire [7:0] ui_in;
  wire [7:0] uo_out;

  wire [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  assign ui_in[0]   = button_1;
  assign ui_in[1]   = button_2;
  assign ui_in[2]   = button_3;
  assign ui_in[3]   = button_4;

  assign io_vgaR[1] = uo_out[0];
  assign io_vgaG[1] = uo_out[1];
  assign io_vgaB[1] = uo_out[2];
  assign vga_vs     = uo_out[3];
  assign io_vgaR[0] = uo_out[4];
  assign io_vgaG[0] = uo_out[5];
  assign io_vgaB[0] = uo_out[6];
  assign vga_hs     = uo_out[7];

  tt_um_vga_tetris tetris (
      .ui_in (ui_in),  // Dedicated inputs
      .uo_out(uo_out), // Dedicated outputs

      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)

      .ena  (1'b1),     // always 1 when the design is powered, so you can ignore it
      .clk  (vga_clk),  // clock
      .rst_n(~reset)    // reset_n - low to reset
  );
endmodule
