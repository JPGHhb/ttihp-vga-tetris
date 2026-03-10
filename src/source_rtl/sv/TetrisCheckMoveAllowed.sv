`default_nettype none  // Don't allow undeclared nets

`include "HelperMacros.svh"

module TetrisCheckMoveAllowed #(
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardWidthInBlocks = 20,
    parameter int RowLenInBits = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic start_check_i,
    input logic [3:0] shape_row_data_i,
    input logic [(RowLenInBits - 1):0] board_row_data_i,
    input logic [$clog2(RowLenInBits / ColorBitsPerBlock)-1:0] shape_x_coord_i,
    input logic row_index_is_out_of_range_i,

    output logic [1:0] row_index_o,
    output logic move_allowed_o,
    output logic check_done_o
);
  logic [1:0] row_index_q;
  logic [$bits(row_index_q)-1:0] row_index_d;
  logic check_is_running_q;
  logic check_is_running_d;
  logic done_q;
  logic done_d;

  assign row_index_o = row_index_q[1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      row_index_q <= '0;
      check_is_running_q <= '0;
      done_q <= '0;
    end else begin
      row_index_q <= row_index_d;
      check_is_running_q <= check_is_running_d;
      done_q <= done_d;
    end
  end

  localparam int ShapeRowBits = $bits(shape_row_data_i);

  logic [(BoardWidthInBlocks + ShapeRowBits) - 1:0] compressed_board_row;
  logic [ShapeRowBits-1:0] board_bits_window;

  logic [$clog2(BoardWidthInBlocks)-1:0] shape_x_coord;

  localparam int unsigned ShapeXCoordBits = $bits(shape_x_coord_i);

  logic shape_x_coord_outside_the_range;
  assign shape_x_coord_outside_the_range = (shape_x_coord_i + ShapeXCoordBits'(ShapeRowBits)) > ShapeXCoordBits'($bits(compressed_board_row));

  assign shape_x_coord = (shape_x_coord_outside_the_range ? '0 : shape_x_coord_i);

  logic running_or_asserting_done;
  assign running_or_asserting_done = check_is_running_q || done_q;

  localparam logic [ShapeRowBits-1:0] FullShapeRow = {ShapeRowBits{1'b1}};

  assign check_is_running_d = start_check_i ? 1'b1 : (done_d ? 1'b0 : check_is_running_q);
  assign board_bits_window = running_or_asserting_done & ~row_index_is_out_of_range_i ? compressed_board_row[shape_x_coord+:ShapeRowBits] : FullShapeRow;
  assign move_allowed_o = running_or_asserting_done ? ~shape_x_coord_outside_the_range & ~|(board_bits_window & shape_row_data_i) : '0;

  assign check_done_o = done_q;

  always_comb begin
    `ASSERT((BoardWidthInBlocks * ColorBitsPerBlock) <= RowLenInBits, "Inconsistent configuration");

    row_index_d = check_is_running_q ? row_index_q : '0;
    done_d = '0;

    for (int i = 0; i < BoardWidthInBlocks; i++) begin
      compressed_board_row[i+:1] = |board_row_data_i[(i*ColorBitsPerBlock)+:ColorBitsPerBlock];
    end
    for (int i = BoardWidthInBlocks; i < $bits(compressed_board_row); i++) begin
      compressed_board_row[i+:1] = 1'b1;
    end

    if (check_is_running_q) begin
      done_d = (row_index_q == 2'd3) || !move_allowed_o;

      if (!done_d) begin
        row_index_d = row_index_q + 2'd1;
      end
    end
  end
endmodule
