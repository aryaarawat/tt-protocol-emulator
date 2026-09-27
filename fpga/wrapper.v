`default_nettype none

// FPGA top for the RealDigital Urbana board (100 MHz clock).
//
//   BTN[0]     reset (active-high pushbutton)
//   BTN[1]     start one SPI transfer
//   SW[7:0]    SPI byte to transmit
//   SW[8]      SPI CPOL
//   SW[9]      SPI CPHA
//   LED[7:0]   SPI byte last received
//   LED[8]     SPI transfer in progress (CS asserted)
//   PMOD A     SCLK / MOSI / CS_N / MISO (see urbana.xdc)
//   UART TX    USB-UART bridge, 115200 baud 8N1, sends 'U' (0x55) forever
module fpga_top (
    input  wire        clk_100mhz,
    input  wire [1:0]  btn,
    input  wire [9:0]  sw,
    output wire [8:0]  led,
    output wire        uart_tx,
    output wire        spi_sclk,
    output wire        spi_mosi,
    output wire        spi_cs_n,
    input  wire        spi_miso
);

  // Reset: assert immediately on button press, release synchronously.
  reg [1:0] rst_sync = 2'b00;
  always @(posedge clk_100mhz or posedge btn[0]) begin
    if (btn[0]) rst_sync <= 2'b00;
    else        rst_sync <= {rst_sync[0], 1'b1};
  end
  wire rst_n = rst_sync[1];

  // Debounce the start button: only accept a new level once it has been
  // stable for 2^20 clocks (~10 ms), so one press starts one transfer.
  reg [1:0]  start_sync = 2'b00;
  reg        start_btn  = 1'b0;
  reg [19:0] start_cnt  = 20'd0;
  always @(posedge clk_100mhz) begin
    start_sync <= {start_sync[0], btn[1]};
    if (start_sync[1] == start_btn) begin
      start_cnt <= 20'd0;
    end else begin
      start_cnt <= start_cnt + 1'b1;
      if (&start_cnt) start_btn <= start_sync[1];
    end
  end

  wire [7:0] uo_out;
  wire [7:0] uio_out;

  tt_um_example #(
      .CLKS_PER_BIT(868),  // 100 MHz / 868 = 115200 baud
      .SPI_CLK_DIV (50)    // 100 MHz / (2 * 50) = 1 MHz SCLK
  ) dut (
      .ui_in   (sw[7:0]),
      .uo_out  (uo_out),
      .uio_in  ({4'b0000, spi_miso, sw[9], sw[8], start_btn}),
      .uio_out (uio_out),
      .uio_oe  (),
      .ena     (1'b1),
      .clk     (clk_100mhz),
      .rst_n   (rst_n)
  );

  assign led[7:0] = uo_out;
  assign led[8]   = ~uio_out[6];
  assign spi_sclk = uio_out[4];
  assign spi_mosi = uio_out[5];
  assign spi_cs_n = uio_out[6];
  assign uart_tx  = uio_out[7];

endmodule
