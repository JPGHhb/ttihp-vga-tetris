`default_nettype none  // Don't allow undeclared nets

`include "HelperMacros.svh"

module TetrisShiftTheBoard #(
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardWidthInBlocks = 10,
    parameter int BoardHeightInBlocks = 20,
    parameter int RowLenInBits = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic start_i,
    input logic [(RowLenInBits - 1):0] board_row_data_i,

    output logic reading_o,
    output logic writing_o,
    output logic [(RowLenInBits - 1):0] board_row_data_o,
    output logic [$clog2(BoardHeightInBlocks)-1:0] row_index_o,

    output logic increment_score_o,

    output logic done_o
);
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_COUNTING_ROWS_TO_SHIFT,
    ST_SHIFTING_ROWS_READING,
    ST_SHIFTING_ROWS_WRITING,
    ST_CLEARING_ROWS,
    ST_REPEAT,
    ST_DONE
  } state_e;

  state_e state_q, state_d;

  logic [(RowLenInBits - 1):0] board_row_data_q;
  logic [(RowLenInBits - 1):0] board_row_data_d;

  logic [$bits(row_index_o)-1:0] row_index_q;
  logic [$bits(row_index_q)-1:0] row_index_d;
  logic [$bits(row_index_q)-1:0] lines_to_shift_q;
  logic [$bits(row_index_q)-1:0] lines_to_shift_d;
  logic operation_is_running_q;
  logic operation_is_running_d;
  logic [$clog2(BoardHeightInBlocks)-1:0] shift_start_pos_q;
  logic [$bits(shift_start_pos_q)-1:0] shift_start_pos_d;

  logic internal_start_trigger_q;
  logic internal_start_trigger_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      row_index_q <= '0;
      lines_to_shift_q <= '0;
      shift_start_pos_q <= '0;
      operation_is_running_q <= '0;
      state_q <= ST_IDLE;
      board_row_data_q <= '0;
      internal_start_trigger_q <= '0;
    end else begin
      row_index_q <= row_index_d;
      lines_to_shift_q <= lines_to_shift_d;
      shift_start_pos_q <= shift_start_pos_d;
      operation_is_running_q <= operation_is_running_d;
      state_q <= state_d;
      board_row_data_q <= board_row_data_d;
      internal_start_trigger_q <= internal_start_trigger_d;
    end
  end

  logic in_counting_rows_to_shift_state;
  logic in_shifting_rows_reading_state;
  logic in_shifting_rows_writing_state;
  logic in_clearing_rows_state;
  logic in_repeat_state;
  logic in_done_state;

  assign in_counting_rows_to_shift_state = (state_q == ST_COUNTING_ROWS_TO_SHIFT);

  assign in_shifting_rows_reading_state = (state_q == ST_SHIFTING_ROWS_READING);
  assign in_shifting_rows_writing_state = (state_q == ST_SHIFTING_ROWS_WRITING);
  assign in_clearing_rows_state = (state_q == ST_CLEARING_ROWS);
  assign in_repeat_state = (state_q == ST_REPEAT);
  assign in_done_state = (state_q == ST_DONE);

  assign operation_is_running_d = start_i ? 1'b1 : (in_done_state ? 1'b0 : operation_is_running_q);

  assign reading_o = in_counting_rows_to_shift_state || in_shifting_rows_reading_state;
  assign writing_o = (in_shifting_rows_writing_state || in_clearing_rows_state);
  assign board_row_data_o = in_clearing_rows_state ? '0 : board_row_data_q;

  assign row_index_o = in_clearing_rows_state ? lines_to_shift_q : (writing_o ? shift_start_pos_q : row_index_q);

  localparam logic [$bits(shift_start_pos_q)-1:0] InvalidShiftPos = {$bits(shift_start_pos_q) {1'b1}};

  logic start_shift_pos_is_invalid;
  logic start_triggered;
  logic [(BoardWidthInBlocks - 1):0] compressed_board_row;
  localparam logic [$bits(compressed_board_row)-1:0] FullRow = {$bits(compressed_board_row) {1'b1}};

  assign start_shift_pos_is_invalid = (shift_start_pos_q == InvalidShiftPos);
  assign start_triggered = start_i | internal_start_trigger_q;

  assign done_o = in_done_state;

  always_comb begin
    `ASSERT((BoardWidthInBlocks * ColorBitsPerBlock) <= RowLenInBits, "Inconsistent configuration");

    row_index_d = row_index_q;
    lines_to_shift_d = lines_to_shift_q;
    state_d = state_q;
    board_row_data_d = board_row_data_q;
    shift_start_pos_d = shift_start_pos_q;
    internal_start_trigger_d = internal_start_trigger_q;

    increment_score_o = '0;

    for (int i = 0; i < BoardWidthInBlocks; i++) begin
      compressed_board_row[i+:1] = |board_row_data_i[(i*ColorBitsPerBlock)+:ColorBitsPerBlock];
    end

    if (start_triggered) begin
      state_d = ST_COUNTING_ROWS_TO_SHIFT;
      row_index_d = $bits(row_index_d)'(BoardHeightInBlocks - 1);
      shift_start_pos_d = InvalidShiftPos;
      internal_start_trigger_d = '0;
    end

    if (operation_is_running_q) begin
      unique0 case (1'b1)
        in_counting_rows_to_shift_state: begin
          if (compressed_board_row == FullRow) begin
            increment_score_o = 1'b1;
            if (start_shift_pos_is_invalid) begin
              shift_start_pos_d = row_index_q;
            end
          end else if (!start_shift_pos_is_invalid) begin
            state_d = ST_SHIFTING_ROWS_READING;
            lines_to_shift_d = (shift_start_pos_q - row_index_q);
          end

          if (row_index_q == '0) begin
            state_d = (start_shift_pos_is_invalid ? ST_DONE : ST_SHIFTING_ROWS_READING);
            lines_to_shift_d = (shift_start_pos_q - row_index_q);
          end else begin
            if (state_d != ST_SHIFTING_ROWS_READING) begin
              row_index_d = (row_index_q - $bits(row_index_q)'(1'd1));
            end
          end
        end

        in_shifting_rows_reading_state: begin
          board_row_data_d = board_row_data_i;
          state_d = ST_SHIFTING_ROWS_WRITING;
        end

        in_shifting_rows_writing_state: begin
          if (row_index_q == '0) begin
            state_d = ST_CLEARING_ROWS;
            lines_to_shift_d = (lines_to_shift_q - $bits(lines_to_shift_q)'(1'b1));
          end else begin
            row_index_d = (row_index_q - $bits(row_index_q)'(1'd1));
            shift_start_pos_d = (shift_start_pos_q - $bits(shift_start_pos_q)'(1'b1));
            state_d = ST_SHIFTING_ROWS_READING;
          end
        end

        in_clearing_rows_state: begin
          if (lines_to_shift_q == '0) begin
            state_d = ST_REPEAT;
          end else begin
            lines_to_shift_d = (lines_to_shift_q - $bits(lines_to_shift_q)'(1'b1));
          end
        end

        in_repeat_state: begin
          internal_start_trigger_d = 1'b1;
          state_d = ST_IDLE;
        end

        in_done_state: begin
          state_d = ST_IDLE;
        end

        default: ;
      endcase
    end
  end
endmodule
