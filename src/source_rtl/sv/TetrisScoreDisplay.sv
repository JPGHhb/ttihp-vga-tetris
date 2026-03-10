`default_nettype none

`include "HelperMacros.svh"

module TetrisScoreDisplay #(
    parameter int ColorBitsToUse = 2,
    parameter int DigitSizeInPx  = 32
) (
    input logic                      reset_i,
    input logic                      pixel_pos_is_valid_i,
    input logic                [9:0] px_x_i,                // X position for actual pixel.
    input logic                [9:0] px_y_i,                // Y position for actual pixel.
    input TetrisTypes::score_t       score_i,

    output logic [(ColorBitsToUse-1):0] vga_r_o,  // VGA Red
    output logic [(ColorBitsToUse-1):0] vga_g_o,  // VGA Green
    output logic [(ColorBitsToUse-1):0] vga_b_o   // VGA Blue
);
  typedef logic [$bits(px_x_i)-1:0] coord_t;

  localparam coord_t BoardHorizStart = $bits(coord_t)'(16 * 16 + 16 + 4);
  localparam coord_t BoardHorizEnd = (BoardHorizStart + $bits(coord_t)'(TetrisTypes::ScoreDigitCount * DigitSizeInPx));
  localparam coord_t BoardVertStart = $bits(coord_t)'(DigitSizeInPx);
  localparam coord_t BoardVertEnd = BoardVertStart + $bits(coord_t)'(DigitSizeInPx);

  logic x_within_the_score;
  logic y_within_the_score;
  logic draw_score;

  localparam int CoordBitsPerDigit = $clog2(DigitSizeInPx);

  logic [$clog2(TetrisTypes::ScoreDigitCount)-1:0] score_digit_index;

  coord_t score_x_coord;
  // verilator lint_off UNUSEDSIGNAL
  coord_t score_y_coord;
  // verilator lint_on UNUSEDSIGNAL

  // verilator lint_off UNUSEDSIGNAL
  logic [$clog2(DigitSizeInPx)-1:0] digit_x_coord;
  logic [$clog2(DigitSizeInPx)-1:0] digit_y_coord;
  // verilator lint_on UNUSEDSIGNAL

  assign score_x_coord = (px_x_i - BoardHorizStart);
  assign score_y_coord = (px_y_i - BoardVertStart);


  assign score_digit_index = $clog2(TetrisTypes::ScoreDigitCount)'(score_x_coord >> CoordBitsPerDigit);
  assign digit_x_coord = $clog2(DigitSizeInPx)'(score_x_coord[$clog2(DigitSizeInPx)-1:0]);  // Basically (score_x_coord mod DigitSizeInPx)
  assign digit_y_coord = $clog2(DigitSizeInPx)'(score_y_coord[$clog2(DigitSizeInPx)-1:0]);

  localparam int NumOfRealRowFields = 3;
  localparam int NumOfLogicalRowFields = 4;
  localparam int NumOfRealRows = 5;

  typedef logic [HelperFunctions::flog2(NumOfLogicalRowFields):0] digit_row_t;
  digit_row_t font_bitmap[10][NumOfRealRows];
  digit_row_t digit_row;

  logic [1:0] font_bitmap_x_index;
  logic [2:0] font_bitmap_y_index;
  logic font_bitmap_x_index_valid;
  logic font_bitmap_y_index_valid;

  localparam int XDivBits = $clog2(2 * NumOfLogicalRowFields);
  assign font_bitmap_x_index = digit_x_coord[XDivBits+1:XDivBits];  // Basically (digit_x_coord / (2*4)) (i.e. digit_x_coord / (2 * NumOfLogicalRowFields))
  assign font_bitmap_y_index = 3'((digit_y_coord - (digit_y_coord >> 2)) >> 2);  // Basically (digit_x_coord / 5) (i.e. digit_x_coord / NumOfRealRows)

  assign font_bitmap_x_index_valid = (font_bitmap_x_index <= $bits(font_bitmap_x_index)'(NumOfRealRowFields - 1));
  assign font_bitmap_y_index_valid = (font_bitmap_y_index <= $bits(font_bitmap_y_index)'(NumOfRealRows - 1));

  assign x_within_the_score = ((px_x_i >= BoardHorizStart) && (px_x_i < BoardHorizEnd));
  assign y_within_the_score = ((px_y_i >= BoardVertStart) && (px_y_i < BoardVertEnd));
  assign draw_score = (x_within_the_score && y_within_the_score && font_bitmap_x_index_valid && font_bitmap_y_index_valid);


  TetrisTypes::score_digit_t score_digit;

  always_comb begin
    score_digit = '0;
    if (draw_score) begin
      score_digit = score_i[$bits(score_digit_index)'(TetrisTypes::ScoreDigitCount-1)-score_digit_index];
    end
  end

  always_comb begin
    vga_r_o = '0;
    vga_g_o = '0;
    vga_b_o = '0;
    digit_row = '0;

    // @ @ @
    // @   @
    // @   @
    // @   @
    // @ @ @
    font_bitmap[0][0] = 3'b111;
    font_bitmap[0][1] = 3'b101;
    font_bitmap[0][2] = 3'b101;
    font_bitmap[0][3] = 3'b101;
    font_bitmap[0][4] = 3'b111;

    // @ @
    //   @
    //   @
    //   @
    // @ @ @
    font_bitmap[1][0] = 3'b110;
    font_bitmap[1][1] = 3'b010;
    font_bitmap[1][2] = 3'b010;
    font_bitmap[1][3] = 3'b010;
    font_bitmap[1][4] = 3'b111;

    // @ @ @
    //     @
    // @ @ @
    // @
    // @ @ @
    font_bitmap[2][0] = 3'b111;
    font_bitmap[2][1] = 3'b001;
    font_bitmap[2][2] = 3'b111;
    font_bitmap[2][3] = 3'b100;
    font_bitmap[2][4] = 3'b111;

    // @ @ @
    //     @
    // @ @ @
    //     @
    // @ @ @
    font_bitmap[3][0] = 3'b111;
    font_bitmap[3][1] = 3'b001;
    font_bitmap[3][2] = 3'b111;
    font_bitmap[3][3] = 3'b001;
    font_bitmap[3][4] = 3'b111;

    // @   @
    // @   @
    // @ @ @
    //     @
    //     @
    font_bitmap[4][0] = 3'b101;
    font_bitmap[4][1] = 3'b101;
    font_bitmap[4][2] = 3'b111;
    font_bitmap[4][3] = 3'b001;
    font_bitmap[4][4] = 3'b001;

    // @ @ @
    // @
    // @ @ @
    //     @
    // @ @ @
    font_bitmap[5][0] = 3'b111;
    font_bitmap[5][1] = 3'b100;
    font_bitmap[5][2] = 3'b111;
    font_bitmap[5][3] = 3'b001;
    font_bitmap[5][4] = 3'b111;

    // @ @ @
    // @
    // @ @ @
    // @   @
    // @ @ @
    font_bitmap[6][0] = 3'b111;
    font_bitmap[6][1] = 3'b100;
    font_bitmap[6][2] = 3'b111;
    font_bitmap[6][3] = 3'b101;
    font_bitmap[6][4] = 3'b111;

    // @ @ @
    //     @
    //     @
    //     @
    //     @
    font_bitmap[7][0] = 3'b111;
    font_bitmap[7][1] = 3'b001;
    font_bitmap[7][2] = 3'b001;
    font_bitmap[7][3] = 3'b001;
    font_bitmap[7][4] = 3'b001;

    // @ @ @
    // @   @
    // @ @ @
    // @   @
    // @ @ @
    font_bitmap[8][0] = 3'b111;
    font_bitmap[8][1] = 3'b101;
    font_bitmap[8][2] = 3'b111;
    font_bitmap[8][3] = 3'b101;
    font_bitmap[8][4] = 3'b111;

    // @ @ @
    // @   @
    // @ @ @
    //     @
    // @ @ @
    font_bitmap[9][0] = 3'b111;
    font_bitmap[9][1] = 3'b101;
    font_bitmap[9][2] = 3'b111;
    font_bitmap[9][3] = 3'b001;
    font_bitmap[9][4] = 3'b111;

    `ASSERT(ColorBitsToUse == 3 || ColorBitsToUse == 2, "ColorBitsToUse is expected to be 2 or 3 bits");
    `ASSERT(`IS_POW2(DigitSizeInPx), "DigitSizeInPx is expected to be power of 2");
    `ASSERT(`DIVISIBLE_BY(BoardHorizStart, $bits(BoardHorizStart)'(NumOfLogicalRowFields)),
            "BoardHorizStart is expected to be divisible by NumOfLogicalRowFields");
    `ASSERT(int'(BoardHorizStart) >= DigitSizeInPx, "Prerequisite (BoardHorizStart >= DigitSizeInPx) not met");

    if (pixel_pos_is_valid_i == 1'b1 && reset_i == '0) begin
      if (draw_score) begin
        digit_row = font_bitmap[score_digit][font_bitmap_y_index];

        if (digit_row[2'd2-font_bitmap_x_index] == 1'b1) begin
          // Yellow color
          vga_r_o = {{ColorBitsToUse} {1'b1}};
          vga_g_o = {{ColorBitsToUse} {1'b1}};
          vga_b_o = '0;
        end
      end
    end
  end
endmodule
