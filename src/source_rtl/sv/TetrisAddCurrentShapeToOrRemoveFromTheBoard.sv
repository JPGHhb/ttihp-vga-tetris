`default_nettype none  // Don't allow undeclared nets

`include "HelperMacros.svh"

module TetrisAddCurrentShapeToOrRemoveFromTheBoard #(
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardWidthInBlocks = 10,
    parameter int RowLenInBits = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic start_i,
    input logic clear_shape_i,
    input logic [3:0] shape_row_data_i,
    input logic [(ColorBitsPerBlock-1):0] shape_color_i,
    input logic [(RowLenInBits - 1):0] board_row_data_i,
    input logic [HelperFunctions::flog2(BoardWidthInBlocks):0] shape_x_coord_i,

    output logic reading_o,
    output logic writing_o,
    output logic [(RowLenInBits - 1):0] board_row_data_o,
    output logic [1:0] row_index_o,
    output logic done_o
);
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_READING,
    ST_WRITING
  } read_write_state_e;

  read_write_state_e state_q, state_d;

  localparam int ShapeRowWidth = $bits(shape_row_data_i);
  localparam int ExendedRowLenInBits = (RowLenInBits + 1);

  typedef logic [(ExendedRowLenInBits - 1):0] extended_row_t;

  extended_row_t board_row_data_q;
  extended_row_t board_row_data_d;

  logic [1:0] row_index_q;
  logic [$bits(row_index_q)-1:0] row_index_d;
  logic done_q;
  logic done_d;
  logic clearing_q;
  logic clearing_d;

  assign row_index_o = row_index_q[1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      row_index_q <= '0;
      done_q <= '0;
      clearing_q <= '0;
      state_q <= ST_IDLE;
      board_row_data_q <= '0;
    end else begin
      row_index_q <= row_index_d;
      done_q <= done_d;
      clearing_q <= clearing_d;
      state_q <= state_d;
      board_row_data_q <= board_row_data_d;
    end
  end

  localparam int NumBlocksInABoardRow = BoardWidthInBlocks;
  localparam int unsigned ShapeXCoordBits = $bits(shape_x_coord_i);
  localparam int unsigned BoardXCoordBits = $clog2($bits(board_row_data_q));

  typedef logic [BoardXCoordBits-1:0] board_x_coord_t;

  logic [ShapeXCoordBits-1:0] shape_x_logical_coord;
  board_x_coord_t shape_x_coord;

  logic shape_x_coord_outside_the_range;

  logic in_idle_state;
  logic in_reading_state;
  logic in_writing_state;

  assign in_idle_state = (state_q == ST_IDLE);
  assign in_reading_state = (state_q == ST_READING);
  assign in_writing_state = (state_q == ST_WRITING);

  assign shape_x_logical_coord = (shape_x_coord_i + ShapeXCoordBits'(1));
  assign shape_x_coord_outside_the_range = shape_x_logical_coord > ShapeXCoordBits'(NumBlocksInABoardRow);

  localparam board_x_coord_t MaxBoardXCoord = BoardXCoordBits'(NumBlocksInABoardRow);

  assign done_o = done_q;

  assign reading_o = in_reading_state;
  assign writing_o = in_writing_state;
  assign board_row_data_o = board_row_data_q[(RowLenInBits-1):0];

  logic [$bits(shape_x_coord)-1:0] board_block_index[ShapeRowWidth];
  logic shape_block_valid[ShapeRowWidth];

  extended_row_t board_extended_row_data_in;

  assign board_extended_row_data_in = {1'b0, board_row_data_i};

  always_comb begin
    `ASSERT(ColorBitsPerBlock == 3 || ColorBitsPerBlock == 2,
            "ColorBitsPerBlock != 3 && ColorBitsPerBlock != 2, please change calculation of the shape_x_coord");

    if (ColorBitsPerBlock == 3) begin : gen_label_0
      shape_x_coord = shape_x_coord_outside_the_range ? MaxBoardXCoord : (BoardXCoordBits'(shape_x_coord_i) << 1) + BoardXCoordBits'(shape_x_coord_i);
    end else if (ColorBitsPerBlock == 2) begin : gen_label_1
      shape_x_coord = shape_x_coord_outside_the_range ? MaxBoardXCoord : (BoardXCoordBits'(shape_x_coord_i) << 1);
    end

    row_index_d = row_index_q;
    done_d = '0;
    state_d = state_q;
    clearing_d = done_q ? '0 : clearing_q;
    for (int i = 0, j = 0; i < ShapeRowWidth; i++, j += ColorBitsPerBlock) begin
      board_block_index[i] = shape_x_coord + $bits(shape_x_coord)'(j);
      shape_block_valid[i] = shape_row_data_i[i+:1];
    end
    board_row_data_d = board_row_data_q;

    if (start_i) begin
      state_d = ST_READING;
      row_index_d = '0;
      clearing_d = clear_shape_i;
    end

    if (!in_idle_state) begin
      unique0 case (1'b1)
        in_reading_state: begin
          board_row_data_d = board_extended_row_data_in;

          for (int i = 0, j = 0; i < ShapeRowWidth; i++, j += ColorBitsPerBlock) begin
            board_row_data_d[board_block_index[i]+:ColorBitsPerBlock] =
            shape_block_valid[i] ? (clearing_q ? ColorBitsPerBlock'('0) : shape_color_i) : board_extended_row_data_in[board_block_index[i]+:ColorBitsPerBlock];
          end

          state_d = ST_WRITING;
        end

        in_writing_state: begin
          done_d = (row_index_q == 2'd3);

          if (done_d) begin
            state_d = ST_IDLE;
          end else begin
            state_d = ST_READING;
            row_index_d = row_index_q + 2'd1;
          end
        end

        default: ;
      endcase
    end
  end
endmodule
