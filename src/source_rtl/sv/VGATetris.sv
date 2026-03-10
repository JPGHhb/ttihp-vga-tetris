`default_nettype none  //disable implicit definitions by Verilog

`define NEXT_POW_OF_2(v) (((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) | (((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) >> 4) | \
    ((((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) | (((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) >> 4)) >> 8) | \
    ((((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) | (((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) >> 4) | \
    ((((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) | (((v-1) | (v-1 >> 1) | (((v-1) | (v-1 >> 1)) >> 2)) >> 4)) >> 8)) >> 16)) + 1

module VGATetris #(
    parameter int AvailableColors   = 3,
    parameter int ColorBitsPerBlock = $clog2(AvailableColors)
) (

`ifndef PERFORMING_SYNTHESIS
    input  logic                         clk_i,                // 25.175MHz
    input  logic                         rst_ni,
    // verilator lint_off UNUSEDSIGNAL
    input  logic                         button_1_i,
    input  logic                         button_2_i,
    input  logic                         button_3_i,
    input  logic                         button_4_i,
    // verilator lint_on UNUSEDSIGNAL
    output logic [ColorBitsPerBlock-1:0] vga_r_o,              // VGA Red 3 bit
    output logic [ColorBitsPerBlock-1:0] vga_g_o,              // VGA Green 3 bit
    output logic [ColorBitsPerBlock-1:0] vga_b_o,              // VGA Blue 3 bit
    output logic                         vga_hs_o,             // H-sync pulse
    output logic                         vga_vs_o,             // V-sync pulse
    output logic                         vga_visible_pixels_o,

    output logic [                  9:0] px_x_o,
    output logic [                  9:0] px_y_o
`else
    input  logic                         clk_i,                // 25.175MHz
    input  logic                         rst_ni,
    // verilator lint_off UNUSEDSIGNAL
    input  logic                         button_1_i,
    input  logic                         button_2_i,
    input  logic                         button_3_i,
    input  logic                         button_4_i,
    // verilator lint_on UNUSEDSIGNAL
    output logic [ColorBitsPerBlock-1:0] vga_r_o,              // VGA Red 3 bit
    output logic [ColorBitsPerBlock-1:0] vga_g_o,              // VGA Green 3 bit
    output logic [ColorBitsPerBlock-1:0] vga_b_o,              // VGA Blue 3 bit
    output logic                         vga_hs_o,             // H-sync pulse
    output logic                         vga_vs_o,             // V-sync pulse
    output logic                         vga_visible_pixels_o
`endif  // PERFORMING_SYNTHESIS
);

`ifndef USE_CHISEL_GENERATED_MODULES
  localparam int ScreenWidth = 640;
  localparam int ScreenHeight = 480;
`endif  // USE_CHISEL_GENERATED_MODULES

  logic activevideo;

  logic [9:0] px_x;
  logic [9:0] px_y;

`ifndef PERFORMING_SYNTHESIS
  assign px_x_o = px_x;
  assign px_y_o = px_y;
`endif  // PERFORMING_SYNTHESIS

  assign vga_visible_pixels_o = activevideo;

`ifdef USE_CHISEL_GENERATED_MODULES
  VGAController vga_controller_instance (
      .clock(clk_i),
      .reset(~rst_ni),

      .io_hSync          (vga_hs_o),    // Horizontal Sync
      .io_vSync          (vga_vs_o),    // Vertical Sync
      .io_pixelPosX      (px_x),        // X coordinate of a visible pixel (0 to screen width)
      .io_pixelPosY      (px_y),        // Y coordinate of a visible pixel (0 to screen height)
      .io_pixelPosIsValid(activevideo)
  );
`else
  VGAController #(
      .ScreenWidth (ScreenWidth),
      .ScreenHeight(ScreenHeight)
  ) vga_controller_instance (
      .px_clk_i(clk_i),
      .reset_i (~rst_ni),

      .h_sync_o            (vga_hs_o),    // Horizontal Sync
      .v_sync_o            (vga_vs_o),    // Vertical Sync
      .pixel_pos_x_o       (px_x),        // X coordinate of a visible pixel (0 to screen width)
      .pixel_pos_y_o       (px_y),        // Y coordinate of a visible pixel (0 to screen height)
      .pixel_pos_is_valid_o(activevideo)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

`ifndef USE_CHISEL_GENERATED_MODULES
  localparam int BlockSizeInPx = 16;
`endif  // USE_CHISEL_GENERATED_MODULES
  localparam int BoardWidthInBlocks = 10;
  localparam int BoardHeightInBlocks = 20;

  localparam int BoardRowLenInBits = (BoardWidthInBlocks * ColorBitsPerBlock);  // `NEXT_POW_OF_2();

  logic [BoardRowLenInBits-1:0] board_row_data;
  logic coords_valid;
  logic [$clog2(BoardHeightInBlocks)-1:0] display_board_read_y_coord;

  logic running_tetris_logic_q;
  logic running_tetris_logic_d;

  logic start_tetris_logic_q;
  logic start_tetris_logic_d;

  TetrisTypes::score_t score;

  logic game_over;

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisDisplay tetris_display_instance (
      .io_reset(~rst_ni),

      .io_pixelPosIsValid(activevideo),
      .io_pxX(px_x),
      .io_pxY(px_y),
      .io_showGameOver(game_over),
      .io_score_0(score[0]),
      .io_score_1(score[1]),
      .io_score_2(score[2]),
      .io_score_3(score[3]),
      .io_boardRowData(board_row_data),

      .io_coordsValid(coords_valid),
      .io_boardYCoord(display_board_read_y_coord),
      .io_vgaR(vga_r_o),
      .io_vgaG(vga_g_o),
      .io_vgaB(vga_b_o)
  );
`else
  TetrisDisplay #(
      .ScreenWidth(ScreenWidth),
      .ScreenHeight(ScreenHeight),
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardRowLenInBits(BoardRowLenInBits),
      .BlockSizeInPx(BlockSizeInPx),
      .BoardWidthInBlocks(BoardWidthInBlocks),
      .BoardHeightInBlocks(BoardHeightInBlocks)
  ) tetris_display_instance (
      .reset_i(~rst_ni),
      .pixel_pos_is_valid_i(activevideo),
      .px_x_i(px_x),
      .px_y_i(px_y),
      .show_game_over_i(game_over),
      .score_i(score),
      .board_row_data_i(board_row_data),

      .coords_valid_o(coords_valid),
      .board_y_coord_o(display_board_read_y_coord),
      .vga_r_o(vga_r_o),
      .vga_g_o(vga_g_o),
      .vga_b_o(vga_b_o)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic tetris_logic_done;
  logic read_board;
  logic write_board;
  logic tetris_logic_read_board;
  logic [$clog2(BoardHeightInBlocks)-1:0] tetris_logic_row_index;
  logic [(BoardRowLenInBits - 1):0] board_row_data_to_write;
  logic [$clog2(BoardHeightInBlocks)-1:0] board_read_y_coord;
  logic [$clog2(BoardHeightInBlocks)-1:0] board_write_y_coord;

  assign read_board = running_tetris_logic_q ? tetris_logic_read_board : coords_valid;
  assign board_read_y_coord = running_tetris_logic_q ? tetris_logic_row_index : display_board_read_y_coord;
  assign board_write_y_coord = tetris_logic_row_index;

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisBoardMemory board_mem (
      .clock(clk_i),
      .reset(~rst_ni),
      .io_wen(write_board),
      .io_ren(read_board),
      .io_readYCoord(board_read_y_coord),
      .io_writeYCoord(board_write_y_coord),
      .io_writeRowData(board_row_data_to_write),
      .io_readRowData(board_row_data)
  );
`else
  TetrisBoardMemory #(
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardHeightInBlocks(BoardHeightInBlocks),
      .RowLenInBits(BoardRowLenInBits)
  ) board_mem (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .wen_i(write_board),
      .ren_i(read_board),
      .read_y_coord_i(board_read_y_coord),
      .write_y_coord_i(board_write_y_coord),
      .write_row_data_i(board_row_data_to_write),

      .read_row_data_o(board_row_data)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic ms_timer_tick;

`ifdef USE_CHISEL_GENERATED_MODULES
  MillisecondTimer ms_timer (
      .clock(clk_i),
      .reset(~rst_ni),

      .io_tick(ms_timer_tick)
  );
`else
  MillisecondTimer #(
      .ClockRateInMHz(25)
  ) ms_timer (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .tick_o(ms_timer_tick)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic rotate_button_active;
  logic left_button_active;
  logic right_button_active;
  logic down_button_active;

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisInputs inputs (
      .clock(clk_i),
      .reset(~rst_ni),

      .io_millisecondTimerTick(ms_timer_tick),
      .io_clear(tetris_logic_done),

      .io_rotateButtonPressed(button_3_i),
      .io_leftButtonPressed  (button_1_i),
      .io_rightButtonPressed (button_2_i),
      .io_downButtonPressed  (button_4_i),

      .io_rotateButtonActive(rotate_button_active),
      .io_leftButtonActive  (left_button_active),
      .io_rightButtonActive (right_button_active),
      .io_downButtonActive  (down_button_active)
  );
`else
  TetrisInputs #(
      .ButtonStateHoldingIntervalsInMs('{100, 100, 100, 1})
  ) inputs (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .millisecond_timer_tick_i(ms_timer_tick),
      .clear_i(tetris_logic_done),

      .rotate_button_pressed_i(button_3_i),
      .left_button_pressed_i  (button_1_i),
      .right_button_pressed_i (button_2_i),
      .down_button_pressed_i  (button_4_i),

      .rotate_button_active_o(rotate_button_active),
      .left_button_active_o  (left_button_active),
      .right_button_active_o (right_button_active),
      .down_button_active_o  (down_button_active)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  TetrisLogic #(
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardWidthInBlocks(BoardWidthInBlocks),
      .BoardHeightInBlocks(BoardHeightInBlocks),
      .RowLenInBits(BoardRowLenInBits)
  ) tetris_logic (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .start_i(start_tetris_logic_q),

      .shape_start_pos_x_i((HelperFunctions::flog2(BoardWidthInBlocks) + 1)'((BoardWidthInBlocks / 4) + 1)),
      .shape_start_pos_y_i('0),
      .shape_start_type_i('0),
      .always_start_in_init_state_i('0),

      .rotate_button_active_i(rotate_button_active),
      .left_button_active_i  (left_button_active),
      .right_button_active_i (right_button_active),
      .down_button_active_i  (down_button_active),

      .board_row_data_i(board_row_data),
      .reading_o(tetris_logic_read_board),
      .writing_o(write_board),
      .board_row_data_o(board_row_data_to_write),
      .row_index_o(tetris_logic_row_index),

      .score_o(score),
      .game_over_o(game_over),
      .done_o(tetris_logic_done)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      running_tetris_logic_q <= '0;
      start_tetris_logic_q   <= '0;
    end else begin
      running_tetris_logic_q <= running_tetris_logic_d;
      start_tetris_logic_q   <= start_tetris_logic_d;
    end
  end

  always_comb begin
    running_tetris_logic_d = running_tetris_logic_q;
    start_tetris_logic_d   = start_tetris_logic_q;
    if (running_tetris_logic_q) begin
      running_tetris_logic_d = ~vga_vs_o;
      start_tetris_logic_d   = '0;
    end else begin
      if (start_tetris_logic_q == '0) begin
        start_tetris_logic_d   = (~vga_vs_o & ~activevideo);
        running_tetris_logic_d = start_tetris_logic_d;
      end else begin
        start_tetris_logic_d = '0;
      end
    end
  end

endmodule

