module BCDAdder (
    input logic [3:0] a_i,   // BCD digit (0-9)
    input logic [3:0] b_i,   // BCD digit (0-9)
    input logic       cin_i, // carry in

    output logic [3:0] sum_o,  // BCD sum digit
    output logic       cout_o  // carry out
);
  logic [4:0] binary_sum;

  always_comb begin
    binary_sum = {1'b0, a_i} + {1'b0, b_i} + {4'b0, cin_i};

    // If sum > 9, add 6 to correct back to BCD
    if (binary_sum > 9) begin
      sum_o  = binary_sum[3:0] + 4'd6;
      cout_o = 1'b1;
    end else begin
      sum_o  = binary_sum[3:0];
      cout_o = 1'b0;
    end
  end
endmodule
