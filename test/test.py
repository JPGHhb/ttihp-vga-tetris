# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def get_bit(signal, bit):
    return (signal.value.to_unsigned() >> bit) & 1

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0xF
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 100)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    # Red Color
    assert get_bit(dut.uo_out, 4) == 1
    assert get_bit(dut.uo_out, 0) == 1
    
    # VGA VSync
    assert get_bit(dut.uo_out, 3) == 1

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
