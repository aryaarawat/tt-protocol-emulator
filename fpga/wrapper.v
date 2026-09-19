`default_nettype none

module fpga_top (
    input  wire clk_100mhz,
    input  wire btn_reset_n,
    output wire uart_tx
);

  wire [7:0] uo_out;

  tt_um_example dut (
      .ui_in   (8'b0),
      .uo_out  (uo_out),
      .uio_in  (8'b0),
      .uio_out (),
      .uio_oe  (),
      .ena     (1'b1),
      .clk     (clk_100mhz),
      .rst_n   (btn_reset_n)
  );

  assign uart_tx = uo_out[0];

endmodule