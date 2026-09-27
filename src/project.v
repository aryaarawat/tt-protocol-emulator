`default_nettype none

// Pinout:
//   ui_in[7:0]  SPI byte to transmit
//   uo_out[7:0] SPI byte last received
//   uio[0] in   SPI start (rising edge starts one transfer)
//   uio[1] in   SPI CPOL
//   uio[2] in   SPI CPHA
//   uio[3] in   SPI MISO
//   uio[4] out  SPI SCLK
//   uio[5] out  SPI MOSI
//   uio[6] out  SPI CS_N (low while a transfer is in progress)
//   uio[7] out  UART TX
module tt_um_example #(
    // Defaults are for the ASIC; the FPGA wrapper overrides them for 100 MHz
    parameter integer CLKS_PER_BIT = 8,  // UART: clk cycles per bit
    parameter integer SPI_CLK_DIV  = 4   // SPI: SCLK = clk / (2 * SPI_CLK_DIV)
) (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // ---------------------------------------------------------------------------
  // UART transmitter
  // ---------------------------------------------------------------------------

  reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
  reg [3:0] bit_index;
  reg [9:0] tx_pattern;      // <-- the protocol, now in memory
  wire      tx_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_count  <= 0;
      bit_index  <= 0;
      // stop=1, then 0x55 LSB-first (1,0,1,0,1,0,1,0), then start=0
      tx_pattern <= 10'b1_01010101_0;
    end else if (clk_count == CLKS_PER_BIT - 1) begin
      clk_count <= 0;
      bit_index <= (bit_index == 9) ? 4'd0 : bit_index + 4'd1;
    end else begin
      clk_count <= clk_count + 1'b1;
    end
  end

  assign tx_reg  = tx_pattern[bit_index];   // <-- fetch, not decode

  // ---------------------------------------------------------------------------
  // SPI controller
  // ---------------------------------------------------------------------------

  // The start pin is asynchronous to clk: synchronize it, then turn its rising
  // edge into a one-cycle pulse so holding it high starts only one transfer.
  reg [2:0] start_sync;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_sync <= 3'b000;
    else        start_sync <= {start_sync[1:0], uio_in[0]};
  end

  wire       spi_start = start_sync[1] & ~start_sync[2];
  wire [7:0] spi_rx_data;
  wire       spi_sclk, spi_mosi, spi_cs_n;
  wire       spi_busy, spi_done;

  spi_controller #(
      .DATA_WIDTH(8),
      .CLK_DIV   (SPI_CLK_DIV)
  ) spi (
      .clk    (clk),
      .rst_n  (rst_n),
      .cpol   (uio_in[1]),
      .cpha   (uio_in[2]),
      .start  (spi_start),
      .tx_data(ui_in),
      .rx_data(spi_rx_data),
      .busy   (spi_busy),
      .done   (spi_done),
      .sclk   (spi_sclk),
      .mosi   (spi_mosi),
      .cs_n   (spi_cs_n),
      .miso   (uio_in[3])
  );

  assign uo_out  = spi_rx_data;
  assign uio_out = {tx_reg, spi_cs_n, spi_mosi, spi_sclk, 4'b0000};
  assign uio_oe  = 8'b1111_0000;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in[7:4], spi_busy, spi_done, 1'b0};

endmodule
