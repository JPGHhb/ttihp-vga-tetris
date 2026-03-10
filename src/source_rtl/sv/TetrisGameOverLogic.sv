`default_nettype none  // Don't allow undeclared nets

module TetrisGameOverLogic #(
    parameter int ButtonPressCountForReset = 2
) (
    input logic clk_i,
    input logic rst_ni,

    input logic enter_game_over_state_i,
    input logic down_button_active_i,

    output logic in_game_over_state_o,
    output logic game_over_reset_o
);
  logic in_game_over_state_q;
  logic in_game_over_state_d;

  logic [HelperFunctions::flog2(ButtonPressCountForReset):0] button_presses_counter_q;
  logic [$bits(button_presses_counter_q)-1:0] button_presses_counter_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      in_game_over_state_q <= '0;
      button_presses_counter_q <= '0;
    end else begin
      in_game_over_state_q <= in_game_over_state_d;
      button_presses_counter_q <= button_presses_counter_d;
    end
  end

  assign in_game_over_state_o = in_game_over_state_q;
  assign game_over_reset_o = (in_game_over_state_q & ~in_game_over_state_d);

  always_comb begin
    in_game_over_state_d = in_game_over_state_q;
    button_presses_counter_d = button_presses_counter_q;

    if (enter_game_over_state_i) begin
      in_game_over_state_d = 1'b1;
      button_presses_counter_d = '0;
    end else if (in_game_over_state_q) begin
      button_presses_counter_d = button_presses_counter_q + $bits(button_presses_counter_q)'(down_button_active_i);
      if (button_presses_counter_q == $bits(button_presses_counter_q)'(ButtonPressCountForReset - 1)) begin
        in_game_over_state_d = '0;
      end
    end
  end
endmodule
