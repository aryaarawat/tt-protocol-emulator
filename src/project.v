/*
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // UART transmitter: continuously sends a fixed byte at a fixed baud rate.
  // Frame format is 8N1 (1 start bit, 8 data bits LSB-first, 1 stop bit),
  // repeated back-to-back with no idle gap between frames.
  localparam [7:0] TX_BYTE       = 8'h55;  // fixed byte to transmit
  localparam integer CLKS_PER_BIT = 8;     // clock cycles per UART bit (fixed baud rate)

  reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
  reg [3:0] bit_index;  // 0 = start bit, 1-8 = data bits, 9 = stop bit
  reg       tx_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_count <= 0;
      bit_index <= 0;
    end else if (clk_count == CLKS_PER_BIT - 1) begin
      clk_count <= 0;
      bit_index <= (bit_index == 9) ? 4'd0 : bit_index + 4'd1;
    end else begin
      clk_count <= clk_count + 1'b1;
    end
  end

  always @(*) begin
    case (bit_index)
      4'd0:    tx_reg = 1'b0;          // start bit
      4'd1:    tx_reg = TX_BYTE[0];
      4'd2:    tx_reg = TX_BYTE[1];
      4'd3:    tx_reg = TX_BYTE[2];
      4'd4:    tx_reg = TX_BYTE[3];
      4'd5:    tx_reg = TX_BYTE[4];
      4'd6:    tx_reg = TX_BYTE[5];
      4'd7:    tx_reg = TX_BYTE[6];
      4'd8:    tx_reg = TX_BYTE[7];
      4'd9:    tx_reg = 1'b1;          // stop bit
      default: tx_reg = 1'b1;
    endcase
  end

  assign uo_out  = {7'b0, tx_reg};  // uo_out[0] is the UART TX line
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
