`default_nettype none  // Don't allow undeclared nets

module TetrisInputs #(
    parameter int ButtonStateHoldingIntervalsInMs[4] = '{100, 100, 100, 1}
) (
    input logic clk_i,
    input logic rst_ni,

    input logic millisecond_timer_tick_i,
    input logic clear_i,

    input logic rotate_button_pressed_i,
    input logic left_button_pressed_i,
    input logic right_button_pressed_i,
    input logic down_button_pressed_i,

    output logic rotate_button_active_o,
    output logic left_button_active_o,
    output logic right_button_active_o,
    output logic down_button_active_o
);
  localparam int ButtonCount = 4;
  localparam int LargestValue = ButtonStateHoldingIntervalsInMs[0] > ButtonStateHoldingIntervalsInMs[1] ?
                                ButtonStateHoldingIntervalsInMs[0] : ButtonStateHoldingIntervalsInMs[1] > ButtonStateHoldingIntervalsInMs[2] ?
                                ButtonStateHoldingIntervalsInMs[1] : ButtonStateHoldingIntervalsInMs[2] > ButtonStateHoldingIntervalsInMs[3] ?
                                ButtonStateHoldingIntervalsInMs[2] : ButtonStateHoldingIntervalsInMs[3];

  typedef logic [$clog2(LargestValue):0] button_timer_t;

  logic button_pressed[ButtonCount];
  button_timer_t button_timer_q[ButtonCount];
  button_timer_t button_timer_d[ButtonCount];
  logic button_active_q[ButtonCount];
  logic button_active_d[ButtonCount];

  assign button_pressed[0] = rotate_button_pressed_i;
  assign button_pressed[1] = left_button_pressed_i;
  assign button_pressed[2] = right_button_pressed_i;
  assign button_pressed[3] = down_button_pressed_i;

  assign rotate_button_active_o = button_active_q[0];
  assign left_button_active_o = button_active_q[1];
  assign right_button_active_o = button_active_q[2];
  assign down_button_active_o = button_active_q[3];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < ButtonCount; i++) begin
        button_timer_q[i]  <= '0;
        button_active_q[i] <= '0;
      end
    end else begin
      for (int i = 0; i < ButtonCount; i++) begin
        button_timer_q[i]  <= button_timer_d[i];
        button_active_q[i] <= button_active_d[i];
      end
    end
  end

  always_comb begin
    for (int i = 0; i < ButtonCount; i++) begin
      button_timer_d[i] = button_timer_q[i];

      // Timer: count milliseconds while button is held, reset when released
      if (!button_pressed[i] | (button_active_q[i] & clear_i)) begin
        button_timer_d[i] = '0;
      end else if (millisecond_timer_tick_i && !button_active_q[i]) begin
        button_timer_d[i] = button_timer_q[i] + button_timer_t'(1);
      end

      // Active latch: set when debounce threshold reached, clear on clear_i
      if (!button_active_q[i]) begin
        button_active_d[i] = button_pressed[i] & (button_timer_d[i] >= button_timer_t'(ButtonStateHoldingIntervalsInMs[i]));
      end else begin
        button_active_d[i] = !clear_i;
      end
    end
  end
endmodule
