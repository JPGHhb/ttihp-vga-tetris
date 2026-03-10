`default_nettype none  // Don't allow undeclared nets

module MillisecondTimer #(
    parameter real ClockRateInMHz = 21.181
) (
    input logic clk_i,
    input logic rst_ni,

    output logic tick_o
);

  localparam int ClockTicksPerMs = int'(ClockRateInMHz * 1000.0);
  typedef logic [$clog2(ClockTicksPerMs)-1:0] ms_timer_t;
  localparam ms_timer_t MsTimerTick = ms_timer_t'(1'b1);

  ms_timer_t ms_timer_q;
  ms_timer_t ms_timer_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ms_timer_q <= '0;
    end else begin
      ms_timer_q <= ms_timer_d;
    end
  end

  assign ms_timer_d = (ms_timer_q < ms_timer_t'(ClockTicksPerMs)) ? (ms_timer_q + MsTimerTick) : '0;
  assign tick_o = (ms_timer_q == ms_timer_t'(ClockTicksPerMs));

endmodule

