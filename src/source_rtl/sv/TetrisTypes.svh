
`ifndef TETRIS_TYPES_H_INCLUDED
`define TETRIS_TYPES_H_INCLUDED

package TetrisTypes;

  typedef logic [HelperFunctions::flog2(TetrisParameters::ShapeCount):0] shape_type_t;
  typedef logic [1:0] shape_rotation_t;

  localparam int MaxScore = 9999;
  localparam int ScoreDigitCount = HelperFunctions::digit_count(MaxScore);

  typedef logic [3:0] score_digit_t;
  typedef score_digit_t score_t[ScoreDigitCount];

endpackage


`endif  // TETRIS_TYPES_H_INCLUDED
