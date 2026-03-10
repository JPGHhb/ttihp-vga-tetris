`default_nettype none

`include "HelperMacros.svh"

`define VAL_8BIT_TO_VAL_COLOR_BITS(v, bit_count) ((bit_count)'(int'($ceil((real'(v)/255.0)*real'((1 << bit_count)-1)))))

module TetrisDisplay #(
    parameter int ScreenWidth = 640,
    parameter int ScreenHeight = 480,
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardRowLenInBits = 20,

    parameter int BlockSizeInPx = 16,
    parameter int BoardWidthInBlocks = 10,
    parameter int BoardHeightInBlocks = 20
) (
    input logic                      reset_i,
    input logic                      pixel_pos_is_valid_i,
    input logic                [9:0] px_x_i,                // X position for actual pixel.
    input logic                [9:0] px_y_i,                // Y position for actual pixel.
    input logic                      show_game_over_i,
    input TetrisTypes::score_t       score_i,

    input logic [BoardRowLenInBits-1:0] board_row_data_i,

    output logic coords_valid_o,
    output logic [$clog2(BoardHeightInBlocks)-1:0] board_y_coord_o,

    output logic [(ColorBitsPerBlock-1):0] vga_r_o,  // VGA Red
    output logic [(ColorBitsPerBlock-1):0] vga_g_o,  // VGA Green
    output logic [(ColorBitsPerBlock-1):0] vga_b_o   // VGA Blue
);
  localparam logic [$bits(px_x_i)-1:0] BoardHorizStart = $bits(px_x_i)'(BlockSizeInPx * BlockSizeInPx);
  localparam logic [$bits(px_x_i)-1:0] BoardHorizEnd = (BoardHorizStart + $bits(px_x_i)'(BoardWidthInBlocks * BlockSizeInPx));
  localparam logic [$bits(px_y_i)-1:0] BoardVertStart = $bits(px_y_i)'(BlockSizeInPx * 4);
  localparam logic [$bits(px_y_i)-1:0] BoardVertEnd = BoardVertStart + $bits(px_x_i)'(BlockSizeInPx * BoardHeightInBlocks);

  logic tetris_score_pixel_pos_is_valid;
  logic [(ColorBitsPerBlock-1):0] score_vga_r;
  logic [(ColorBitsPerBlock-1):0] score_vga_g;
  logic [(ColorBitsPerBlock-1):0] score_vga_b;

  TetrisScoreDisplay #(
      .ColorBitsToUse(ColorBitsPerBlock),
      .DigitSizeInPx (32)
  ) score_display (
      .reset_i(reset_i),
      .pixel_pos_is_valid_i(tetris_score_pixel_pos_is_valid),
      .px_x_i(px_x_i),
      .px_y_i(px_y_i),
      .score_i(score_i),

      .vga_r_o(score_vga_r),
      .vga_g_o(score_vga_g),
      .vga_b_o(score_vga_b)
  );

  logic game_over_pixel_pos_is_valid;
  logic game_over_pixel_data_valid;
  logic [(ColorBitsPerBlock-1):0] game_over_vga_r;
  logic [(ColorBitsPerBlock-1):0] game_over_vga_g;
  logic [(ColorBitsPerBlock-1):0] game_over_vga_b;

  TetrisGameOverDisplay #(
      .ColorBitsToUse(ColorBitsPerBlock),
      .PixelSize(4),
      .TextTopLeftX(int'(BoardHorizStart) + 36),
      .TextTopLeftY(int'(BoardVertStart) + 140)
  ) game_over_text (
      .reset_i(reset_i),
      .pixel_pos_is_valid_i(game_over_pixel_pos_is_valid),
      .px_x_i(px_x_i),
      .px_y_i(px_y_i),

      .vga_r_o(game_over_vga_r),
      .vga_g_o(game_over_vga_g),
      .vga_b_o(game_over_vga_b),
      .pixel_data_valid_o(game_over_pixel_data_valid)
  );

  logic [(ColorBitsPerBlock-1):0] display_vga_r;
  logic [(ColorBitsPerBlock-1):0] display_vga_g;
  logic [(ColorBitsPerBlock-1):0] display_vga_b;


  logic [$clog2(BoardWidthInBlocks * ColorBitsPerBlock)-1:0] board_x_coord_data_start;
  logic [$clog2(BoardWidthInBlocks)-1:0] board_x_coord;

  logic x_within_the_board;
  logic y_within_the_board;
  logic draw_board;

  localparam int CoordBitsPerBlock = $clog2(BlockSizeInPx);

  assign board_x_coord = $clog2(BoardWidthInBlocks)'((px_x_i - BoardHorizStart) >> CoordBitsPerBlock);
  assign board_y_coord_o = $clog2(BoardHeightInBlocks)'((px_y_i - BoardVertStart) >> CoordBitsPerBlock);

  assign x_within_the_board = ((px_x_i >= BoardHorizStart) && (px_x_i < BoardHorizEnd));
  assign y_within_the_board = ((px_y_i >= BoardVertStart) && (px_y_i < BoardVertEnd));

  logic draw_block_frame;
  logic draw_block_frame_horizontal;
  logic draw_block_frame_vertical;
  assign draw_block_frame_horizontal = (px_y_i[CoordBitsPerBlock-1:0] == {CoordBitsPerBlock{1'b1}}) | (px_y_i[CoordBitsPerBlock-1:0] == '0);
  assign draw_block_frame_vertical = (px_x_i[CoordBitsPerBlock-1:0] == {CoordBitsPerBlock{1'b1}});
  assign draw_block_frame = (draw_block_frame_horizontal | draw_block_frame_vertical);

  assign draw_board = (x_within_the_board && y_within_the_board) & ~draw_block_frame;
  assign tetris_score_pixel_pos_is_valid = (pixel_pos_is_valid_i & ~draw_board);
  assign game_over_pixel_pos_is_valid = (pixel_pos_is_valid_i & show_game_over_i);

  logic draw_block_frame_in_board;
  assign draw_block_frame_in_board = (draw_block_frame & x_within_the_board & y_within_the_board);

  typedef logic [(ColorBitsPerBlock - 1):0] board_color_t;
  board_color_t color;

  logic draw_baord_colors;

  assign draw_baord_colors = draw_board & ~draw_block_frame;
  assign coords_valid_o = draw_baord_colors;

  logic draw_screen_outline;
  logic draw_tetris_board_outline;
  logic draw_outlines;

  assign draw_screen_outline = px_y_i == '0 || px_x_i == '0 || px_y_i == $bits(px_y_i)'(ScreenHeight - 1) || px_x_i == $bits(px_x_i)'(ScreenWidth - 1);
  assign draw_tetris_board_outline = (((px_y_i == BoardVertStart) || (px_y_i == BoardVertEnd)) && (px_x_i >= BoardHorizStart) && (px_x_i <= BoardHorizEnd)) ||
              (((px_x_i == BoardHorizStart) || (px_x_i == BoardHorizEnd)) && (px_y_i >= BoardVertStart) && (px_y_i <= BoardVertEnd));
  assign draw_outlines = draw_screen_outline || draw_tetris_board_outline;

  logic display_board;
  logic display_game_over;

  assign display_board = (draw_board | draw_block_frame_in_board | draw_outlines);
  assign display_game_over = game_over_pixel_data_valid;

  assign vga_r_o = display_board ? (display_game_over ? game_over_vga_r : display_vga_r) : score_vga_r;
  assign vga_g_o = display_board ? (display_game_over ? game_over_vga_g : display_vga_g) : score_vga_g;
  assign vga_b_o = display_board ? (display_game_over ? game_over_vga_b : display_vga_b) : score_vga_b;

  always_comb begin
    display_vga_r = '0;
    display_vga_g = '0;
    display_vga_b = '0;
    color = '0;

    if (ColorBitsPerBlock == 3) begin
      board_x_coord_data_start = (board_x_coord << 1) + board_x_coord;
    end else if (ColorBitsPerBlock == 2) begin
      board_x_coord_data_start = (board_x_coord << 1);
    end

    `ASSERT(ColorBitsPerBlock == 3 || ColorBitsPerBlock == 2, "ColorBitsPerBlock is expected to be 2 or 3 bits");
    `ASSERT(`IS_POW2(BlockSizeInPx), "BlockSizeInPx is expected to be power of 2");
    `ASSERT(`IS_POW2(BoardHorizStart), "BoardHorizStart is expected to be power of 2");
    `ASSERT(int'(BoardHorizStart) >= BlockSizeInPx, "Prerequisite (BoardHorizStart >= BlockSizeInPx) not met");

    if (pixel_pos_is_valid_i == 1'b1 && reset_i == '0) begin
      if (draw_outlines) begin
        display_vga_r = {ColorBitsPerBlock{1'b1}};
        display_vga_g = '0;
        display_vga_b = '0;
      end else if (draw_baord_colors) begin
        for (int i = 0; i < ColorBitsPerBlock; i++) begin
          color[i] = board_row_data_i[board_x_coord_data_start+$bits(board_x_coord_data_start)'(i)];
        end

        if (ColorBitsPerBlock == 2) begin
          if (color == board_color_t'(1)) begin
            display_vga_r = 2'b11;
            display_vga_g = 2'b01;
            display_vga_b = 2'b00;
          end else if (color == board_color_t'(2)) begin
            display_vga_r = 2'b00;
            display_vga_g = 2'b11;
            display_vga_b = 2'b01;
          end else if (color == board_color_t'(3)) begin
            display_vga_r = 2'b01;
            display_vga_g = 2'b00;
            display_vga_b = 2'b11;
          end
        end else begin
          if (color == board_color_t'(1)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'haa, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h00, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h00, ColorBitsPerBlock);
          end else if (color == board_color_t'(2)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h8b, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hc5, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h3f, ColorBitsPerBlock);
          end else if (color == board_color_t'(3)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hec, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h00, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h8b, ColorBitsPerBlock);
          end else if (color == board_color_t'(4)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hf6, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h92, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h1e, ColorBitsPerBlock);
          end else if (color == board_color_t'(5)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h00, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'had, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hee, ColorBitsPerBlock);
          end else if (color == board_color_t'(6)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h8b, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hc5, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h3f, ColorBitsPerBlock);
          end else if (color == board_color_t'(7)) begin
            display_vga_r = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h1a, ColorBitsPerBlock);
            display_vga_g = `VAL_8BIT_TO_VAL_COLOR_BITS(8'h73, ColorBitsPerBlock);
            display_vga_b = `VAL_8BIT_TO_VAL_COLOR_BITS(8'hba, ColorBitsPerBlock);
          end
        end
      end
    end
  end
endmodule
