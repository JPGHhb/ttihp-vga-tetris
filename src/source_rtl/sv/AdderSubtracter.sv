
//
// Add or subtract two Two's Complement numbers
//

`default_nettype none  // Don't allow undeclared nets

module AdderSubtracter #(
    parameter int Width = 32
) (
    input logic [Width-1:0] a_i,
    input logic [Width-1:0] b_i,

    // If set to 1 perform subtraction, otherwise perform addition
    input logic subtract_i,

    // Set if a_i == b_i (Note: Only valid if subtract_i is set)
    output logic is_zero_result_o,

    // Set if a_i < b_i (Note: Only valid if subtract_i is set and both a_i and b_i are signed values)
    output logic signed_is_lower_than_o,

    output logic [Width-1:0] result_o
);
  logic [Width:0] input0, input1, negated_input_1;
  logic [Width:0] adder_res;

  //
  // How subtraction is done
  //
  // (a - b) == (a + (-b))
  //
  // Assuming Twos' Complement number format: Negation of a number is -N == (~N + 1),
  // hence (a + (-b)) == (a + (~b + 1))
  //
  // The "+1" in the below code is done by adding 1'b1 to the right side of both of the input
  // numbers and then letting the carry logic do the rest
  //
  assign input0 = {a_i, 1'b1};
  assign negated_input_1 = {~b_i, 1'b1};
  assign input1 = (subtract_i ? negated_input_1 : {b_i, 1'b0});

  assign adder_res = $unsigned(input0) + $unsigned(input1);

  assign result_o = adder_res[Width:1];

  assign is_zero_result_o = (result_o == '0);


  logic a_sign_bit;
  logic b_sign_bit;
  logic signed_is_greater_equal;
  logic both_inputs_are_negative;
  logic result_is_positive;

  assign a_sign_bit = a_i[Width-1];
  assign b_sign_bit = b_i[Width-1];

  assign both_inputs_are_negative = ((a_sign_bit ^ b_sign_bit) == 1'b0);
  assign result_is_positive = (result_o[Width-1] == 1'b0);

  assign signed_is_greater_equal = (both_inputs_are_negative ? result_is_positive : (a_sign_bit ^ 1'b1));
  assign signed_is_lower_than_o = ~signed_is_greater_equal;

  //assign unsigned_is_greater_equal = (both_inputs_are_negative ? result_is_positive : (a_sign_bit ^ 1'b0));
  //assign unsigned_is_lower_than_o = ~unsigned_is_greater_equal;

  /* verilator lint_off UNUSED */
  logic unused;
  assign unused = adder_res[0];
  /* verilator lint_on UNUSED */
endmodule
