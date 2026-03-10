

`default_nettype none

`include "HelperMacros.svh"

module TetrisGameOverDisplay #(
    parameter int ColorBitsToUse = 2,
    parameter int PixelSize = 4,
    parameter int TextTopLeftX = 0,
    parameter int TextTopLeftY = 0
) (
    input logic       reset_i,
    input logic       pixel_pos_is_valid_i,
    input logic [9:0] px_x_i,                // X position for actual pixel.
    input logic [9:0] px_y_i,                // Y position for actual pixel.

    output logic [(ColorBitsToUse-1):0] vga_r_o,  // VGA Red
    output logic [(ColorBitsToUse-1):0] vga_g_o,  // VGA Green
    output logic [(ColorBitsToUse-1):0] vga_b_o,  // VGA Blue
    output logic pixel_data_valid_o
);
  typedef logic [22:0] text_line_t;

  localparam text_line_t GameOverTextLines[11] = {
    23'b11111010001011111011111,
    23'b00001011011010001000001,
    23'b01111010101011111011001,
    23'b00001010001010001010001,
    23'b11111010001010001011111,
    23'b00000000000000000000000,
    23'b11111011111010001011111,
    23'b10001000001010001010001,
    23'b11111001111001010010001,
    23'b01001000001001010010001,
    23'b10001011111000100011111
  };

  localparam int MaxXCoord = ($bits(text_line_t) - 1);
  localparam int MaxYCoord = $size(GameOverTextLines) - 1;

  localparam int TextWidthInPixels = ((MaxXCoord + 1) * PixelSize);
  localparam int TextHeightInPixels = ((MaxYCoord + 1) * PixelSize);

  typedef logic [$bits(px_x_i)-1:0] coord_t;
  localparam coord_t TextHorizStart = coord_t'(TextTopLeftX);
  localparam coord_t TextHorizEnd = TextHorizStart + coord_t'(TextWidthInPixels);
  localparam coord_t TextVertStart = coord_t'(TextTopLeftY);
  localparam coord_t TextVertEnd = TextVertStart + coord_t'(TextHeightInPixels);



  localparam int PixelSizeLog2 = ($clog2(PixelSize));

  localparam int XBits = $clog2(MaxXCoord + 1);
  localparam int YBits = $clog2(MaxYCoord + 1);

  logic [XBits-1:0] text_coord_x;
  logic [YBits-1:0] text_coord_y;
  logic x_coord_is_valid;
  logic y_coord_is_valid;

  // verilator lint_off UNUSEDSIGNAL
  coord_t text_coord_start_x;
  coord_t text_coord_start_y;
  // verilator lint_on UNUSEDSIGNAL

  assign text_coord_start_x = (px_x_i - TextHorizStart);
  assign text_coord_start_y = (px_y_i - TextVertStart);

  assign text_coord_x = text_coord_start_x[(XBits-1)+PixelSizeLog2:PixelSizeLog2];
  assign text_coord_y = text_coord_start_y[(YBits-1)+PixelSizeLog2:PixelSizeLog2];

  assign x_coord_is_valid = text_coord_x <= $bits(text_coord_x)'(MaxXCoord);
  assign y_coord_is_valid = text_coord_y <= $bits(text_coord_y)'(MaxYCoord);

  logic in_text_drawing_area;
  assign in_text_drawing_area = (px_x_i >= TextHorizStart && px_x_i <= TextHorizEnd) && (px_y_i >= TextVertStart && px_y_i <= TextVertEnd);

  always_comb begin
    `ASSERT(`IS_POW2(PixelSize), "PixelSize must be a power of 2");
    `ASSERT(`DIVISIBLE_BY(TextTopLeftX, PixelSize), "TextTopLeftX It must be divisible by PixelSize");
    `ASSERT(`DIVISIBLE_BY(TextTopLeftY, PixelSize), "TextTopLeftY It must be divisible by PixelSize");

    vga_r_o = '0;
    vga_g_o = '0;
    vga_b_o = '0;

    pixel_data_valid_o = '0;

    if (pixel_pos_is_valid_i & !reset_i) begin
      if (in_text_drawing_area & x_coord_is_valid & y_coord_is_valid) begin
        if (GameOverTextLines[text_coord_y][text_coord_x]) begin
          pixel_data_valid_o = 1'b1;
          vga_r_o = {{ColorBitsToUse} {1'b1}};
        end
      end
    end
  end

endmodule
