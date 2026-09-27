/*
 * SPI controller (master)
 * SPDX-License-Identifier: Apache-2.0
 *
 * Full-duplex, MSB-first transfers of DATA_WIDTH bits. Supports all four SPI
 * modes, selected per transfer by cpol/cpha (sampled when start is accepted).
 * SCLK frequency = clk / (2 * CLK_DIV).
 */

`default_nettype none

module spi_controller #(
    parameter int DATA_WIDTH = 8,  // bits per transfer (>= 2)
    parameter int CLK_DIV    = 4   // system clocks per SCLK half-period (>= 1)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // SPI mode: cpol = SCLK idle level, cpha = 0 sample on leading edge,
    //                                           1 sample on trailing edge
    input  logic                  cpol,
    input  logic                  cpha,

    // User interface
    input  logic                  start,    // pulse high for one cycle while !busy
    input  logic [DATA_WIDTH-1:0] tx_data,  // byte to send, captured on start
    output logic [DATA_WIDTH-1:0] rx_data,  // byte received, valid when done
    output logic                  busy,     // high for the whole transfer
    output logic                  done,     // one-cycle pulse at end of transfer

    // SPI bus
    output logic                  sclk,
    output logic                  mosi,
    output logic                  cs_n,
    input  logic                  miso
);

  typedef enum logic {
    IDLE,
    TRANSFER
  } state_t;

  localparam int DIV_W  = (CLK_DIV > 1) ? $clog2(CLK_DIV) : 1;
  localparam int EDGES  = 2 * DATA_WIDTH;  // SCLK edges per transfer
  localparam int EDGE_W = $clog2(EDGES + 1);

  state_t                state;
  logic [DIV_W-1:0]      div_cnt;   // counts clk cycles within a half-period
  logic [EDGE_W-1:0]     edge_cnt;  // which SCLK edge comes next (0..EDGES)
  logic [DATA_WIDTH-1:0] tx_shift;  // outgoing bits, MSB drives MOSI
  logic [DATA_WIDTH-1:0] rx_shift;  // incoming bits, shifted in at LSB
  logic                  cpha_q;    // cpha latched for the current transfer

  logic tick;         // a half-period has elapsed
  logic last_tick;    // final half-period (CS hold time), no SCLK edge
  logic leading;      // next edge is a leading edge (idle -> active level)
  logic sample_edge;  // this tick samples MISO
  logic shift_edge;   // this tick moves the next bit onto MOSI

  assign leading = ~edge_cnt[0];

  always_comb begin
    tick        = (state == TRANSFER) && (div_cnt == CLK_DIV - 1);
    last_tick   = tick && (edge_cnt == EDGES);
    // CPHA=0: sample on leading, shift on trailing.
    // CPHA=1: shift on leading, sample on trailing. The first leading edge
    // needs no shift because the MSB is already on MOSI.
    sample_edge = tick && !last_tick && (leading ^ cpha_q);
    shift_edge  = tick && !last_tick && !(leading ^ cpha_q) && (edge_cnt != 0);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      div_cnt  <= '0;
      edge_cnt <= '0;
      tx_shift <= '0;
      rx_shift <= '0;
      rx_data  <= '0;
      cpha_q   <= 1'b0;
      sclk     <= 1'b0;
      cs_n     <= 1'b1;
      done     <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          sclk <= cpol;
          if (start) begin
            tx_shift <= tx_data;
            cpha_q   <= cpha;
            div_cnt  <= '0;
            edge_cnt <= '0;
            cs_n     <= 1'b0;
            state    <= TRANSFER;
          end
        end

        TRANSFER: begin
          if (tick) begin
            div_cnt  <= '0;
            edge_cnt <= edge_cnt + 1'b1;
            if (last_tick) begin
              cs_n    <= 1'b1;
              rx_data <= rx_shift;
              done    <= 1'b1;
              state   <= IDLE;
            end else begin
              sclk <= ~sclk;
            end
          end else begin
            div_cnt <= div_cnt + 1'b1;
          end

          if (sample_edge) rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
          if (shift_edge)  tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
        end

        default: state <= IDLE;
      endcase
    end
  end

  assign mosi = tx_shift[DATA_WIDTH-1];
  assign busy = (state != IDLE);

endmodule
