`default_nettype none

`include "HelperMacros.svh"

module TetrisBoardMemory #(
    parameter int ColorBitsPerBlock = 2,
    parameter int BoardHeightInBlocks = 20,
    parameter int RowLenInBits = 20
) (
    input logic clk_i,
    input logic rst_ni,
    input logic wen_i,
    input logic ren_i,
    input logic [$clog2(BoardHeightInBlocks)-1:0] read_y_coord_i,
    input logic [$clog2(BoardHeightInBlocks)-1:0] write_y_coord_i,
    input logic [(RowLenInBits - 1):0] write_row_data_i,
    output logic [(RowLenInBits - 1):0] read_row_data_o
);
  logic [RowLenInBits-1:0] board[BoardHeightInBlocks];

  always_comb begin
    `ASSERT(ColorBitsPerBlock <= 3, "ColorBitsPerBlock is expected to be <= 3 bits");
    `ASSERT(RowLenInBits <= 32, "RowLenInBits with more than 32 bits not supported");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
    end else begin
      if (wen_i) begin
        board[write_y_coord_i] <= write_row_data_i;
      end
    end
  end

  assign read_row_data_o = ren_i ? board[read_y_coord_i] : '0;
endmodule
