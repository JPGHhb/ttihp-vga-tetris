`default_nettype none  // Don't allow undeclared nets

module TetrisLogic #(
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardWidthInBlocks = 10,
    parameter int BoardHeightInBlocks = 20,
    parameter int RowLenInBits = 20,
    parameter logic [5:0] ShapeDropTimerNormalMax = 60,
    parameter logic [$bits(ShapeDropTimerNormalMax)-1:0] ShapeDropTimerFastMax = 5
) (
    input logic clk_i,
    input logic rst_ni,

    input logic start_i,

    input logic [HelperFunctions::flog2(BoardWidthInBlocks):0] shape_start_pos_x_i,
    input logic [HelperFunctions::flog2(BoardHeightInBlocks):0] shape_start_pos_y_i,
    input TetrisTypes::shape_type_t shape_start_type_i,
    input logic always_start_in_init_state_i,

    input logic rotate_button_active_i,
    input logic left_button_active_i,
    input logic right_button_active_i,
    input logic down_button_active_i,

    input logic [(RowLenInBits - 1):0] board_row_data_i,
    output logic reading_o,
    output logic writing_o,
    output logic [(RowLenInBits - 1):0] board_row_data_o,
    output logic [$clog2(BoardHeightInBlocks)-1:0] row_index_o,

    output TetrisTypes::score_t score_o,

    output logic game_over_o,

    output logic done_o
);

  typedef enum logic [14:0] {
    ST_PERFORM_INITIAL_CLEAR_BOARD,
    ST_INITIAL_CLEAR_BOARD,
    ST_INIT_STATE,
    ST_IDLE,
    ST_REMOVE_SHAPE_FROM_THE_BOARD,
    ST_GET_INPUT,
    ST_ROTATE_IS_ALLOWED,
    ST_MOVE_LEFT_IF_ALLOWED,
    ST_MOVE_RIGHT_IF_ALLOWED,
    ST_MOVE_SHAPE_DOWN_STEP_0,
    ST_MOVE_SHAPE_DOWN_STEP_1,
    ST_CHECK_IF_SHAPE_STOPPED_MOVING,
    ST_ADD_SHAPE_TO_THE_BOARD,
    ST_ADD_SHAPE_TO_THE_BOARD_AND_DONE,
    ST_SHIFT_BOARD,
    ST_GET_NEXT_SHAPE,
    ST_CHECK_IF_GAME_OVER_STEP_0,
    ST_CHECK_IF_GAME_OVER_STEP_1,
    ST_CLEAR_BOARD,
    ST_DONE_WITH_GAME_OVER,
    ST_DONE_AFTER_INITIAL_BOARD_CLEAR,
    ST_DONE
  } logic_state_e;

  typedef struct packed {
    logic [HelperFunctions::flog2(BoardWidthInBlocks):0] pos_x;
    logic [HelperFunctions::flog2(BoardHeightInBlocks):0] pos_y;
    TetrisTypes::shape_type_t shape_type;
    TetrisTypes::shape_rotation_t rotation;
  } shape_state_t;

  shape_state_t shape_state_q;
  shape_state_t shape_state_d;

  logic_state_e state_q;
  logic_state_e state_d;

  logic [$bits(ShapeDropTimerNormalMax)-1:0] shape_drop_timer_q;
  logic [$bits(ShapeDropTimerNormalMax)-1:0] shape_drop_timer_d;

  logic game_over_reset_happened_q;
  logic game_over_reset_happened_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shape_state_q <= '{pos_x : '0, pos_y : '0, shape_type: '0, rotation: '0};
      state_q <= ST_PERFORM_INITIAL_CLEAR_BOARD;
      shape_drop_timer_q <= '0;
      game_over_reset_happened_q <= '0;
    end else begin
      shape_state_q <= shape_state_d;
      state_q <= state_d;
      shape_drop_timer_q <= shape_drop_timer_d;
      game_over_reset_happened_q <= game_over_reset_happened_d;
    end
  end

  logic in_perform_initial_board_clear_state;
  logic in_initial_clear_board_state;
  logic in_init_state;
  logic in_idle_state;
  logic in_remove_shape_from_the_board_state;
  logic in_get_input_state;
  logic in_rotate_is_allowed_state;
  logic in_move_left_if_allowed_state;
  logic in_move_right_if_allowed_state;
  logic in_move_shape_down_state_step_0;
  logic in_move_shape_down_state_step_1;
  logic in_add_shape_to_the_board_state;
  logic in_add_shape_to_the_board_and_done_state;
  logic in_check_if_shape_stopped_moving_state;
  logic in_shift_board_state;
  logic in_get_next_shape_state;
  logic in_check_if_game_over_step_0_state;
  logic in_check_if_game_over_step_1_state;
  logic in_clear_board_state;
  logic in_done_with_game_over_state;
  logic in_done_after_initial_board_clear_state;
  logic in_done_state;

  always_comb begin
    in_perform_initial_board_clear_state = '0;
    in_initial_clear_board_state = '0;
    in_init_state = '0;
    in_idle_state = '0;
    in_remove_shape_from_the_board_state = '0;
    in_get_input_state = '0;
    in_rotate_is_allowed_state = '0;
    in_move_left_if_allowed_state = '0;
    in_move_right_if_allowed_state = '0;
    in_move_shape_down_state_step_0 = '0;
    in_move_shape_down_state_step_1 = '0;
    in_check_if_shape_stopped_moving_state = '0;
    in_add_shape_to_the_board_state = '0;
    in_add_shape_to_the_board_and_done_state = '0;
    in_shift_board_state = '0;
    in_get_next_shape_state = '0;
    in_check_if_game_over_step_0_state = '0;
    in_check_if_game_over_step_1_state = '0;
    in_clear_board_state = '0;
    in_done_with_game_over_state = '0;
    in_done_after_initial_board_clear_state = '0;
    in_done_state = '0;

    case (state_q)
      ST_PERFORM_INITIAL_CLEAR_BOARD: in_perform_initial_board_clear_state = 1'b1;
      ST_INITIAL_CLEAR_BOARD: in_initial_clear_board_state = 1'b1;
      ST_INIT_STATE: in_init_state = 1'b1;
      ST_IDLE: in_idle_state = 1'b1;
      ST_REMOVE_SHAPE_FROM_THE_BOARD: in_remove_shape_from_the_board_state = 1'b1;
      ST_GET_INPUT: in_get_input_state = 1'b1;
      ST_ROTATE_IS_ALLOWED: in_rotate_is_allowed_state = 1'b1;
      ST_MOVE_LEFT_IF_ALLOWED: in_move_left_if_allowed_state = 1'b1;
      ST_MOVE_RIGHT_IF_ALLOWED: in_move_right_if_allowed_state = 1'b1;
      ST_MOVE_SHAPE_DOWN_STEP_0: in_move_shape_down_state_step_0 = 1'b1;
      ST_MOVE_SHAPE_DOWN_STEP_1: in_move_shape_down_state_step_1 = 1'b1;
      ST_CHECK_IF_SHAPE_STOPPED_MOVING: in_check_if_shape_stopped_moving_state = 1'b1;
      ST_ADD_SHAPE_TO_THE_BOARD: in_add_shape_to_the_board_state = 1'b1;
      ST_ADD_SHAPE_TO_THE_BOARD_AND_DONE: in_add_shape_to_the_board_and_done_state = 1'b1;
      ST_SHIFT_BOARD: in_shift_board_state = 1'b1;
      ST_GET_NEXT_SHAPE: in_get_next_shape_state = 1'b1;
      ST_CHECK_IF_GAME_OVER_STEP_0: in_check_if_game_over_step_0_state = 1'b1;
      ST_CHECK_IF_GAME_OVER_STEP_1: in_check_if_game_over_step_1_state = 1'b1;
      ST_CLEAR_BOARD: in_clear_board_state = 1'b1;
      ST_DONE_WITH_GAME_OVER: in_done_with_game_over_state = 1'b1;
      ST_DONE_AFTER_INITIAL_BOARD_CLEAR: in_done_after_initial_board_clear_state = 1'b1;
      ST_DONE: in_done_state = 1'b1;
      default: ;
    endcase
  end

  logic adding_or_removing_shape;
  logic in_move_if_allowed_state;
  assign adding_or_removing_shape = (in_remove_shape_from_the_board_state | in_add_shape_to_the_board_state | in_add_shape_to_the_board_and_done_state);
  assign in_move_if_allowed_state = (in_rotate_is_allowed_state |
                                     in_move_left_if_allowed_state |
                                     in_move_right_if_allowed_state |
                                     in_move_shape_down_state_step_0 |
                                     in_move_shape_down_state_step_1 |
                                     in_check_if_shape_stopped_moving_state |
                                     in_check_if_game_over_step_0_state |
                                     in_check_if_game_over_step_1_state);

  assign done_o = in_done_state | in_done_with_game_over_state | in_done_after_initial_board_clear_state;

  typedef struct packed {
    logic start;
    logic clear_shape;
    logic done;
  } add_remove_shape_state_t;

  typedef struct packed {
    logic start;
    logic move_allowed;
    logic done;
  } check_move_allowed_state_t;

  logic [1:0] relative_row_index;
  logic [1:0] add_remove_shape_state_relative_row_index;
  logic [1:0] check_move_allowed_state_relative_row_index;

  add_remove_shape_state_t add_remove_shape_state;
  check_move_allowed_state_t check_move_allowed_state;

  assign relative_row_index = (adding_or_removing_shape ? add_remove_shape_state_relative_row_index :
                                                          (in_move_if_allowed_state ? check_move_allowed_state_relative_row_index : '0));

  logic [$bits(row_index_o)-1:0] board_shift_row_index_out;
  logic [$bits(row_index_o)-1:0] add_or_remove_shape_or_check_if_move_allowed_row_index_out;
  logic [$bits(row_index_o)-1:0] row_index;
  logic shape_y_coord_last_index;
  logic shape_y_coord_outside_the_range;

  logic adding_or_removing_shape_or_check_if_move_allowed_state;
  assign adding_or_removing_shape_or_check_if_move_allowed_state = adding_or_removing_shape | in_move_if_allowed_state;

  assign add_or_remove_shape_or_check_if_move_allowed_row_index_out = (shape_state_q.pos_y + $bits(shape_state_q.pos_y)'(relative_row_index));

  assign row_index = in_shift_board_state ? board_shift_row_index_out :
                  (adding_or_removing_shape_or_check_if_move_allowed_state ? add_or_remove_shape_or_check_if_move_allowed_row_index_out : shape_state_q.pos_y);
  assign shape_y_coord_last_index = (row_index == $bits(row_index)'(BoardHeightInBlocks - 1));
  assign shape_y_coord_outside_the_range = (row_index > $bits(row_index)'(BoardHeightInBlocks - 1));
  assign row_index_o = shape_y_coord_outside_the_range ? shape_state_q.pos_y : row_index;

  logic [$bits(board_row_data_o)-1:0] add_remove_shape_board_row_data_out;
  logic [$bits(board_row_data_o)-1:0] board_shift_board_row_data_out;

  logic add_or_remove_shape_reading_out;
  logic add_or_remove_shape_writing_out;
  logic board_shift_reading_out;
  logic board_shift_writing_out;
  logic clearing_board;

  assign clearing_board = (in_clear_board_state | in_initial_clear_board_state);

  assign reading_o = in_move_if_allowed_state | (adding_or_removing_shape ? add_or_remove_shape_reading_out : board_shift_reading_out);
  assign writing_o = clearing_board |
                     (~shape_y_coord_outside_the_range & (adding_or_removing_shape ? add_or_remove_shape_writing_out : board_shift_writing_out));

  assign board_row_data_o = clearing_board ? '0 : (adding_or_removing_shape ? add_remove_shape_board_row_data_out : board_shift_board_row_data_out);

  logic [3:0] shape_row_data;
  logic [1:0] current_shape_last_rotation_id;

  logic [$bits(shape_state_q.pos_y)-1:0] add_subb_in_a;
  logic [$bits(shape_state_q.pos_y)-1:0] add_subb_in_b;
  logic add_subb_subtract;
  logic [$bits(shape_state_q.pos_y)-1:0] add_subb_res;
  /* verilator lint_off UNUSED */
  logic add_subb_a_eq_b;
  logic add_subb_a_lt_b;
  /* verilator lint_on UNUSED */

  logic game_over_reset;
  TetrisGameOverLogic #(
      .ButtonPressCountForReset(4)
  ) game_over_logic (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .enter_game_over_state_i(in_done_with_game_over_state),
      .down_button_active_i(down_button_active_i),

      .in_game_over_state_o(game_over_o),
      .game_over_reset_o(game_over_reset)
  );

  logic increment_score;
  TetrisScoreCounter score_counter (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .increment_score_i(increment_score),
      .reset_to_zero_i  (game_over_reset),

      .score_o(score_o)
  );

  logic gen_random_num;
  logic [$clog2((TetrisParameters::ShapeCount - 1))-1:0] random_num_0_to_6;
`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisLFSRPseudoRandomNumGen pseudo_rng (
      .clock(clk_i),
      .reset(~rst_ni),
      .io_enable(gen_random_num),
      .io_random(random_num_0_to_6)
  );
`else
  TetrisLFSRPseudoRandomNumGen #(
      .MaxNum(TetrisParameters::ShapeCount - 1)
  ) pseudo_rng (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .enable_i(gen_random_num),
      .random_o(random_num_0_to_6)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

`ifdef USE_CHISEL_GENERATED_MODULES
  AdderSubtracter adder_subtracter (
      .io_a(add_subb_in_a),
      .io_b(add_subb_in_b),

      // If set to 1 perform subtraction, otherwise perform addition
      .io_subtract(add_subb_subtract),

      // Set if a_i == b_i (Note: Only valid if subtract_i is set)
      .io_isZeroResult(add_subb_a_eq_b),

      // Set if a_i < b_i (Note: Only valid if subtract_i is set and both a_i and b_i are signed values)
      .io_signedIsLowerThan(add_subb_a_lt_b),

      .io_result(add_subb_res)
  );
`else
  AdderSubtracter #(
      .Width($bits(shape_state_q.pos_y))
  ) adder_subtracter (
      .a_i(add_subb_in_a),
      .b_i(add_subb_in_b),

      // If set to 1 perform subtraction, otherwise perform addition
      .subtract_i(add_subb_subtract),

      // Set if a_i == b_i (Note: Only valid if subtract_i is set)
      .is_zero_result_o(add_subb_a_eq_b),

      // Set if a_i < b_i (Note: Only valid if subtract_i is set and both a_i and b_i are signed values)
      .signed_is_lower_than_o(add_subb_a_lt_b),

      .result_o(add_subb_res)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisShapeDataProvider shape_data_provider (
      .io_shapeSelector(shape_state_q.shape_type),
      .io_shapeRotationSelector(shape_state_q.rotation),
      .io_shapeDataRowIndex(relative_row_index),
      .io_shapeRowData(shape_row_data),
      .io_currentShapeLastRotationId(current_shape_last_rotation_id)
  );
`else
  TetrisShapeDataProvider #(
      .ShapeCount(TetrisParameters::ShapeCount)
  ) shape_data_provider (
      .shape_selector_i(shape_state_q.shape_type),
      .shape_rotation_selector_i(shape_state_q.rotation),
      .shape_data_row_index_i(relative_row_index),
      .shape_row_data_o(shape_row_data),
      .current_shape_last_rotation_id_o(current_shape_last_rotation_id)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic [(ColorBitsPerBlock-1):0] shape_colors[TetrisParameters::ShapeCount];

  generate
    if (ColorBitsPerBlock == 3) begin : gen_label_0
      assign shape_colors = {3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6, 3'd7};
    end else if (ColorBitsPerBlock == 2) begin : gen_label_1
      assign shape_colors = {2'd1, 2'd2, 2'd3, 2'd1, 2'd2, 2'd3, 2'd1};
    end
  endgenerate

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisAddCurrentShapeToOrRemoveFromTheBoard add_or_remove_shape (
      .clock(clk_i),
      .reset(~rst_ni),
      .io_start(add_remove_shape_state.start),
      .io_clearShape(add_remove_shape_state.clear_shape),
      .io_shapeRowData(shape_row_data),
      .io_shapeColor(shape_colors[shape_state_q.shape_type]),
      .io_boardRowDataIn(board_row_data_i),
      .io_shapeXCoord(shape_state_q.pos_x),
      .io_reading(add_or_remove_shape_reading_out),
      .io_writing(add_or_remove_shape_writing_out),
      .io_boardRowDataOut(add_remove_shape_board_row_data_out),
      .io_rowIndex(add_remove_shape_state_relative_row_index),
      .io_done(add_remove_shape_state.done)
  );
`else
  TetrisAddCurrentShapeToOrRemoveFromTheBoard #(
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardWidthInBlocks(BoardWidthInBlocks),
      .RowLenInBits(RowLenInBits)
  ) add_or_remove_shape (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .start_i(add_remove_shape_state.start),
      .clear_shape_i(add_remove_shape_state.clear_shape),
      .shape_row_data_i(shape_row_data),
      .shape_color_i(shape_colors[shape_state_q.shape_type]),
      .board_row_data_i(board_row_data_i),
      .shape_x_coord_i(shape_state_q.pos_x),
      .reading_o(add_or_remove_shape_reading_out),
      .writing_o(add_or_remove_shape_writing_out),
      .board_row_data_o(add_remove_shape_board_row_data_out),
      .row_index_o(add_remove_shape_state_relative_row_index),
      .done_o(add_remove_shape_state.done)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisCheckMoveAllowed check_move_allowed (
      .clock(clk_i),
      .reset(~rst_ni),

      .io_startCheck(check_move_allowed_state.start),
      .io_shapeRowData(shape_row_data),
      .io_boardRowData(board_row_data_i),
      .io_shapeXCoord(shape_state_q.pos_x),
      .io_rowIndexIsOutOfRange(shape_y_coord_outside_the_range),

      .io_rowIndex(check_move_allowed_state_relative_row_index),
      .io_moveAllowed(check_move_allowed_state.move_allowed),
      .io_checkDone(check_move_allowed_state.done)
  );
`else
  TetrisCheckMoveAllowed #(
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardWidthInBlocks(BoardWidthInBlocks),
      .RowLenInBits(RowLenInBits)
  ) check_move_allowed (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .start_check_i(check_move_allowed_state.start),
      .shape_row_data_i(shape_row_data),
      .board_row_data_i(board_row_data_i),
      .shape_x_coord_i(shape_state_q.pos_x),
      .row_index_is_out_of_range_i(shape_y_coord_outside_the_range),

      .row_index_o(check_move_allowed_state_relative_row_index),
      .move_allowed_o(check_move_allowed_state.move_allowed),
      .check_done_o(check_move_allowed_state.done)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic board_shifter_state_start;
  logic board_shifter_state_done;

`ifdef USE_CHISEL_GENERATED_MODULES
  TetrisShiftTheBoard shift_the_board (
      .clock(clk_i),
      .reset(~rst_ni),

      .io_start(board_shifter_state_start),
      .io_boardRowDataIn(board_row_data_i),

      .io_reading(board_shift_reading_out),
      .io_writing(board_shift_writing_out),
      .io_boardRowDataOut(board_shift_board_row_data_out),
      .io_rowIndex(board_shift_row_index_out),
      .io_done(board_shifter_state_done)
  );
`else
  TetrisShiftTheBoard #(
      .ColorBitsPerBlock(ColorBitsPerBlock),
      .BoardWidthInBlocks(BoardWidthInBlocks),
      .BoardHeightInBlocks(BoardHeightInBlocks),
      .RowLenInBits(RowLenInBits)
  ) shift_the_board (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .start_i(board_shifter_state_start),
      .board_row_data_i(board_row_data_i),

      .reading_o(board_shift_reading_out),
      .writing_o(board_shift_writing_out),
      .board_row_data_o(board_shift_board_row_data_out),
      .row_index_o(board_shift_row_index_out),
      .increment_score_o(increment_score),
      .done_o(board_shifter_state_done)
  );
`endif  // USE_CHISEL_GENERATED_MODULES

  logic shape_drop_timer_saturated;
  assign shape_drop_timer_saturated = !(shape_drop_timer_q < (down_button_active_i ? ShapeDropTimerFastMax : ShapeDropTimerNormalMax));

  always_comb begin
    add_subb_in_a = shape_state_q.pos_y;
    add_subb_in_b = ($bits(shape_state_q.pos_y))'(1);
    add_subb_subtract = in_check_if_shape_stopped_moving_state | in_check_if_game_over_step_1_state;
  end

  always_comb begin
    shape_state_d = shape_state_q;

    state_d = state_q;
    shape_drop_timer_d = shape_drop_timer_q;
    add_remove_shape_state.start = start_i;
    add_remove_shape_state.clear_shape = start_i;
    check_move_allowed_state.start = '0;
    board_shifter_state_start = '0;
    gen_random_num = ~(in_idle_state | in_init_state);
    game_over_reset_happened_d = game_over_reset_happened_q;

    if (game_over_reset_happened_q == '0) begin
      game_over_reset_happened_d = game_over_reset;
    end

    if (shape_drop_timer_saturated & done_o) begin
      shape_drop_timer_d = '0;
    end else begin
      shape_drop_timer_d = shape_drop_timer_q + $bits(shape_drop_timer_q)'(start_i);
    end

    unique0 case (1'b1)
      in_perform_initial_board_clear_state: begin
        if (start_i) begin
          state_d = ST_INITIAL_CLEAR_BOARD;
        end
      end

      (in_idle_state | in_init_state): begin
        if (start_i) begin
          if (game_over_o) begin
            state_d = ST_DONE;
          end else if (game_over_reset_happened_q) begin
            game_over_reset_happened_d = '0;
            shape_state_d.pos_y = '0;
            state_d = ST_CLEAR_BOARD;
          end else begin
            if (in_init_state) begin
              shape_state_d.pos_x = shape_start_pos_x_i;
              shape_state_d.pos_y = shape_start_pos_y_i;
              shape_state_d.shape_type = shape_start_type_i;
            end
            state_d = ST_REMOVE_SHAPE_FROM_THE_BOARD;
          end
        end
      end

      in_remove_shape_from_the_board_state: begin
        if (add_remove_shape_state.done) begin
          state_d = ST_GET_INPUT;
        end
      end

      in_get_input_state: begin
        if (rotate_button_active_i) begin
          if (shape_state_q.rotation < current_shape_last_rotation_id) begin
            shape_state_d.rotation = shape_state_q.rotation + ($bits(shape_state_q.rotation))'(1);
          end else begin
            shape_state_d.rotation = '0;
          end
          check_move_allowed_state.start = 1'b1;
          state_d = ST_ROTATE_IS_ALLOWED;
        end else if (left_button_active_i && (shape_state_q.pos_x != '0)) begin
          shape_state_d.pos_x = shape_state_q.pos_x - ($bits(shape_state_q.pos_x))'(1);
          check_move_allowed_state.start = 1'b1;
          state_d = ST_MOVE_LEFT_IF_ALLOWED;
        end else if (right_button_active_i && (shape_state_q.pos_x != ($bits(shape_state_q.pos_x))'(BoardWidthInBlocks - 1))) begin
          shape_state_d.pos_x = shape_state_q.pos_x + ($bits(shape_state_q.pos_x))'(1);
          check_move_allowed_state.start = 1'b1;
          state_d = ST_MOVE_RIGHT_IF_ALLOWED;
        end else begin
          state_d = ST_MOVE_SHAPE_DOWN_STEP_0;
        end
      end

      in_rotate_is_allowed_state: begin
        if (check_move_allowed_state.done) begin
          if (!check_move_allowed_state.move_allowed) begin
            if (shape_state_q.rotation == '0) begin
              shape_state_d.rotation = current_shape_last_rotation_id;
            end else begin
              shape_state_d.rotation = shape_state_q.rotation - ($bits(shape_state_q.rotation))'(1);
            end
          end
          state_d = ST_MOVE_SHAPE_DOWN_STEP_0;
        end
      end

      in_move_left_if_allowed_state: begin
        if (check_move_allowed_state.done) begin
          if (!check_move_allowed_state.move_allowed) begin
            shape_state_d.pos_x = shape_state_q.pos_x + ($bits(shape_state_q.pos_x))'(1);
          end
          state_d = ST_MOVE_SHAPE_DOWN_STEP_0;
        end
      end

      in_move_right_if_allowed_state: begin
        if (check_move_allowed_state.done) begin
          if (!check_move_allowed_state.move_allowed) begin
            shape_state_d.pos_x = shape_state_q.pos_x - ($bits(shape_state_q.pos_x))'(1);
          end
          state_d = ST_MOVE_SHAPE_DOWN_STEP_0;
        end
      end

      in_move_shape_down_state_step_0: begin
        if (shape_drop_timer_saturated) begin
          state_d = ST_MOVE_SHAPE_DOWN_STEP_1;
          check_move_allowed_state.start = 1'b1;

          // Y + 1
          shape_state_d.pos_y = add_subb_res;
        end else begin
          add_remove_shape_state.start = 1'b1;
          state_d = ST_ADD_SHAPE_TO_THE_BOARD_AND_DONE;
        end
      end

      in_move_shape_down_state_step_1: begin
        if (check_move_allowed_state.done) begin
          if (check_move_allowed_state.move_allowed) begin
            // Y + 1
            shape_state_d.pos_y = add_subb_res;
          end
          check_move_allowed_state.start = 1'b1;
          state_d = ST_CHECK_IF_SHAPE_STOPPED_MOVING;
        end
      end

      in_check_if_shape_stopped_moving_state: begin
        if (check_move_allowed_state.done) begin
          // Y - 1
          shape_state_d.pos_y = add_subb_res;

          add_remove_shape_state.start = 1'b1;
          if (!check_move_allowed_state.move_allowed) begin
            state_d = ST_ADD_SHAPE_TO_THE_BOARD;
          end else begin
            state_d = ST_ADD_SHAPE_TO_THE_BOARD_AND_DONE;
          end
        end
      end

      (in_add_shape_to_the_board_state | in_add_shape_to_the_board_and_done_state): begin
        if (add_remove_shape_state.done) begin
          if (in_add_shape_to_the_board_and_done_state) begin
            state_d = ST_DONE;
          end else begin
            board_shifter_state_start = 1'b1;
            state_d = ST_SHIFT_BOARD;
          end
        end
      end

      in_shift_board_state: begin
        if (board_shifter_state_done) begin
          state_d = ST_GET_NEXT_SHAPE;
        end
      end

      in_get_next_shape_state: begin
        shape_state_d.shape_type = random_num_0_to_6;
        shape_state_d.pos_x = shape_start_pos_x_i;
        shape_state_d.pos_y = shape_start_pos_y_i;
        shape_state_d.rotation = '0;
        check_move_allowed_state.start = 1'b1;
        state_d = ST_CHECK_IF_GAME_OVER_STEP_0;
      end

      in_check_if_game_over_step_0_state: begin
        if (check_move_allowed_state.done) begin
          if (!check_move_allowed_state.move_allowed) begin
            shape_state_d.pos_x = shape_start_pos_x_i;
            shape_state_d.pos_y = '0;
            shape_state_d.shape_type = '0;
            state_d = ST_DONE_WITH_GAME_OVER;
          end else begin
            // Y + 1
            shape_state_d.pos_y = add_subb_res;

            check_move_allowed_state.start = 1'b1;
            state_d = ST_CHECK_IF_GAME_OVER_STEP_1;
          end
        end
      end

      in_check_if_game_over_step_1_state: begin
        if (check_move_allowed_state.done) begin
          // Y - 1
          shape_state_d.pos_y = add_subb_res;

          if (!check_move_allowed_state.move_allowed) begin
            shape_state_d.pos_x = shape_start_pos_x_i;
            shape_state_d.pos_y = '0;
            shape_state_d.shape_type = '0;
            state_d = ST_DONE_WITH_GAME_OVER;
          end else begin
            state_d = ST_DONE;
          end
        end
      end

      in_clear_board_state | in_initial_clear_board_state: begin
        if (shape_y_coord_last_index) begin
          shape_state_d.pos_y = 0;
          state_d = in_initial_clear_board_state ? ST_DONE_AFTER_INITIAL_BOARD_CLEAR : ST_DONE;
        end else begin
          // Y + 1
          shape_state_d.pos_y = add_subb_res;
        end
      end

      in_done_with_game_over_state: begin
        state_d = ST_IDLE;
      end

      in_done_after_initial_board_clear_state: begin
        state_d = ST_INIT_STATE;
      end

      in_done_state: begin
        state_d = (always_start_in_init_state_i ? ST_INIT_STATE : ST_IDLE);
      end

      default;
    endcase
  end
endmodule

