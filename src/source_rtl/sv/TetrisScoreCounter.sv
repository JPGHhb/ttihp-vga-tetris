`default_nettype none  // Don't allow undeclared nets

module TetrisScoreCounter (
    input logic clk_i,
    input logic rst_ni,

    input logic increment_score_i,
    input logic reset_to_zero_i,

    output TetrisTypes::score_t score_o
);
  import TetrisTypes::score_t;
  import TetrisTypes::score_digit_t;

  score_t score_q;
  score_t score_d;
  score_t adder_score_output;
  localparam int DigitCount = $size(score_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < $size(score_q); i++) begin
        score_q[i] <= '0;
      end
    end else begin
      for (int i = 0; i < $size(score_q); i++) begin
        score_q[i] <= score_d[i];
      end
    end
  end

  logic max_score_reached;
  logic [3:0] carry;
  logic increment;

  assign max_score_reached = (score_q[DigitCount-1] == score_digit_t'(9));
  assign increment = (increment_score_i & ~max_score_reached);

  for (genvar i = 0; i < DigitCount; i++) begin : gen_digit
    BCDAdder bcd_adder (
        .a_i(score_q[i]),
        .b_i(4'd0),
        .cin_i(i == 0 ? increment : carry[i-1]),
        .sum_o(adder_score_output[i]),
        .cout_o(carry[i])
    );
  end

  assign score_o = score_q;

  always_comb begin
    score_d = adder_score_output;
    if (reset_to_zero_i) begin
      for (int i = 0; i < DigitCount; i++) begin
        score_d[i] = '0;
      end
    end
  end
endmodule
