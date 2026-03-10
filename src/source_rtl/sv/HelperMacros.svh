
`ifndef HELPER_MACROS_H_INCLUDED
`define HELPER_MACROS_H_INCLUDED

`ifndef PERFORMING_SYNTHESIS
`define ASSERT(cond, msg) if (~|(cond)) $error(msg)
`else
`define ASSERT(cond, msg)
`endif  // PERFORMING_SYNTHESIS

`define IS_POW2(v) (|(v) & ~(|((v) & ((v) - 1))))
`define DIVISIBLE_BY(v, divider) (|((((v) / (divider))*(divider)) == (v)))

`endif  // HELPER_MACROS_H_INCLUDED
