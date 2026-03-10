
`ifndef HELPER_FUNCTIONS_H_INCLUDED
`define HELPER_FUNCTIONS_H_INCLUDED

package HelperFunctions;

  //
  // Calculate floor(log2(a)) of a given value.
  // For example whereas $clog2(63) returns 6, the flog2(63)
  // returns 5.
  //
  function automatic int flog2(input int a);
    begin
      int ret_val;
      a = a >> 1;
      for (ret_val = 0; a > 0; ret_val = ret_val + 1) a = a >> 1;
      return ret_val;
    end
  endfunction

  // Given 9999 returns 4
  function automatic int digit_count(input int a);
    begin
      int ret_val;
      for (ret_val = 0; a > 0; ret_val = ret_val + 1) a = a / 10;
      return ret_val;
    end
  endfunction

endpackage

`endif  // HELPER_FUNCTIONS_H_INCLUDED
