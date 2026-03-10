`default_nettype none  // Don't allow undeclared nets

// Generates pseudo-random numbers using Fibonacci LFSR
module TetrisLFSRPseudoRandomNumGen #(
    parameter int MaxNum = 6,
    parameter int RandomNumBitCount = $clog2(MaxNum)
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,
    input  logic                         enable_i,  // Advance LFSR when high
    output logic [RandomNumBitCount-1:0] random_o   // Random value 0-6 for shape selection
);
  // 16-bit Fibonacci LFSR (x^16 + x^14 + x^13 + x^11 + 1)
  localparam int LFSTBitCount = 16;
  logic [LFSTBitCount-1:0] lfsr_q, lfsr_d;

  localparam logic [LFSTBitCount-1:0] SeedValue = 16'hACE1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lfsr_q <= SeedValue;
    end else begin
      lfsr_q <= lfsr_d;
    end
  end

  always_comb begin
    lfsr_d = lfsr_q;

    if (enable_i) begin
      // Feedback from taps at positions 16, 14, 13, 11
      lfsr_d = {lfsr_q[14:0], ((lfsr_q[15] ^ lfsr_q[13]) ^ lfsr_q[12]) ^ lfsr_q[10]};
    end
  end



  // Map LFSR bits to shape range 0-MaxNum
  localparam logic [RandomNumBitCount-1:0] MaxNumVal = (RandomNumBitCount)'(MaxNum);
  logic [RandomNumBitCount-1:0] raw_value;
  assign raw_value = lfsr_q[RandomNumBitCount-1:0];
  assign random_o  = (raw_value > MaxNumVal) ? MaxNumVal : raw_value;

endmodule
