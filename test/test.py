# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

# Must match the localparams in src/project.v
CLKS_PER_BIT = 8
TX_BYTE = 0x55


# uio pin assignments (see src/project.v)
SPI_START, SPI_CPOL, SPI_CPHA, SPI_MISO = 0, 1, 2, 3
SPI_SCLK, SPI_MOSI, SPI_CS_N, UART_TX = 4, 5, 6, 7


def uio_bit(dut, n):
    return (int(dut.uio_out.value) >> n) & 1


def tx_pin(dut):
    """Read the UART TX line (uio_out[7])."""
    return uio_bit(dut, UART_TX)


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


async def reset(dut):
    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


@cocotb.test()
async def test_uart_tx(dut):
    dut._log.info("Start")
    await reset(dut)

    dut._log.info("Decoding UART frames from uo_out[0]")

    # The design transmits TX_BYTE continuously, back-to-back. Decode a
    # few frames and check each one matches the fixed byte.
    for frame in range(3):
        byte = await receive_uart_frame(dut)
        dut._log.info(f"Frame {frame}: received 0x{byte:02X}")
        assert byte == TX_BYTE, f"expected 0x{TX_BYTE:02X}, got 0x{byte:02X}"


async def spi_transfer(dut, cpol, cpha, tx_byte, periph_byte):
    """Run one SPI transfer against a peripheral model.

    Returns (byte the controller received, byte the peripheral received,
    number of SCLK edges seen).
    """
    # Build uio_in locally: cocotb writes land later in the timestep, so
    # read-modify-write on dut.uio_in would read stale values.
    mode_bits = (cpol << SPI_CPOL) | (cpha << SPI_CPHA)
    miso = 0

    def drive(start):
        dut.uio_in.value = mode_bits | (start << SPI_START) | (miso << SPI_MISO)

    drive(start=0)
    dut.ui_in.value = tx_byte
    await ClockCycles(dut.clk, 5)

    drive(start=1)

    # Peripheral model. The design only changes outputs on rising clk edges,
    # so watching on falling edges sees every change exactly once.
    shift_out = periph_byte
    received = 0
    edges = 0
    prev_sclk = cpol
    prev_cs_n = 1
    while True:
        await FallingEdge(dut.clk)
        cs_n = uio_bit(dut, SPI_CS_N)
        sclk = uio_bit(dut, SPI_SCLK)

        if prev_cs_n and not cs_n:  # transfer begins
            assert sclk == cpol, "SCLK not at idle level when CS asserted"
            miso = (shift_out >> 7) & 1
            drive(start=1)
        elif not prev_cs_n and cs_n:  # transfer ends
            assert sclk == cpol, "SCLK not back at idle level when CS released"
            break
        elif not cs_n and sclk != prev_sclk:
            edges += 1
            leading = sclk != cpol
            if leading != bool(cpha):  # sample edge
                received = ((received << 1) | uio_bit(dut, SPI_MOSI)) & 0xFF
            elif not (cpha and edges == 1):  # change edge (MSB already out)
                shift_out = (shift_out << 1) & 0xFF
                miso = (shift_out >> 7) & 1
                drive(start=1)

        prev_cs_n = cs_n
        prev_sclk = sclk

    drive(start=0)
    await ClockCycles(dut.clk, 2)
    return int(dut.uo_out.value), received, edges


@cocotb.test()
async def test_spi_controller(dut):
    dut._log.info("Start")
    await reset(dut)

    rng = random.Random(1234)
    for mode in range(4):
        cpol, cpha = mode >> 1, mode & 1
        for _ in range(4):
            tx_byte = rng.randrange(256)
            periph_byte = rng.randrange(256)
            rx, periph_rx, edges = await spi_transfer(dut, cpol, cpha, tx_byte, periph_byte)
            dut._log.info(
                f"Mode {mode}: sent 0x{tx_byte:02X} got 0x{rx:02X}, "
                f"peripheral sent 0x{periph_byte:02X} got 0x{periph_rx:02X}"
            )
            assert edges == 16, f"mode {mode}: expected 16 SCLK edges, saw {edges}"
            assert periph_rx == tx_byte, f"mode {mode}: peripheral got 0x{periph_rx:02X}, expected 0x{tx_byte:02X}"
            assert rx == periph_byte, f"mode {mode}: controller got 0x{rx:02X}, expected 0x{periph_byte:02X}"
