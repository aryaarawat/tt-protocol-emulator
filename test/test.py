# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# Must match the localparams in src/project.v
CLKS_PER_BIT = 8
TX_BYTE = 0x55


def tx_pin(dut):
    """Read the UART TX line (uo_out[0])."""
    return int(dut.uo_out.value) & 1


async def receive_uart_frame(dut):
    """Synchronize to a start bit and decode one 8N1 UART frame (LSB first)."""
    # Wait for a falling edge (1 -> 0) on the TX line, which marks the
    # beginning of a start bit.
    prev = tx_pin(dut)
    while True:
        await RisingEdge(dut.clk)
        cur = tx_pin(dut)
        if prev == 1 and cur == 0:
            break
        prev = cur

    # One cycle of the start bit has already elapsed; move to the middle
    # of the bit period before sampling, to avoid transition edges.
    await ClockCycles(dut.clk, CLKS_PER_BIT // 2)
    assert tx_pin(dut) == 0, "expected start bit low at mid-bit sample"

    data = 0
    for i in range(8):
        await ClockCycles(dut.clk, CLKS_PER_BIT)
        bit = tx_pin(dut)
        data |= (bit << i)

    await ClockCycles(dut.clk, CLKS_PER_BIT)
    assert tx_pin(dut) == 1, "expected stop bit high"

    return data


@cocotb.test()
async def test_uart_tx(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Decoding UART frames from uo_out[0]")

    # The design transmits TX_BYTE continuously, back-to-back. Decode a
    # few frames and check each one matches the fixed byte.
    for frame in range(3):
        byte = await receive_uart_frame(dut)
        dut._log.info(f"Frame {frame}: received 0x{byte:02X}")
        assert byte == TX_BYTE, f"expected 0x{TX_BYTE:02X}, got 0x{byte:02X}"
