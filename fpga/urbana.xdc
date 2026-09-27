# Xilinx Design Constraints for the RealDigital Urbana board (Spartan-7 XC7S50-CSGA324)
# used in UIUC ECE 385. Pin numbers taken from Real Digital's published Urbana
# master constraints file (V2I1 1/3/2023).

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz onboard oscillator
set_property -dict { PACKAGE_PIN N15  IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports { clk_100mhz }]

## Pushbuttons (active-high: 0 idle, 1 while pressed)
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS25 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS25 } [get_ports { btn[1] }]

## Slide switches
set_property -dict { PACKAGE_PIN G1   IOSTANDARD LVCMOS25 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN F2   IOSTANDARD LVCMOS25 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN F1   IOSTANDARD LVCMOS25 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN E2   IOSTANDARD LVCMOS25 } [get_ports { sw[3] }]
set_property -dict { PACKAGE_PIN E1   IOSTANDARD LVCMOS25 } [get_ports { sw[4] }]
set_property -dict { PACKAGE_PIN D2   IOSTANDARD LVCMOS25 } [get_ports { sw[5] }]
set_property -dict { PACKAGE_PIN D1   IOSTANDARD LVCMOS25 } [get_ports { sw[6] }]
set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS25 } [get_ports { sw[7] }]
set_property -dict { PACKAGE_PIN B2   IOSTANDARD LVCMOS25 } [get_ports { sw[8] }]
set_property -dict { PACKAGE_PIN A4   IOSTANDARD LVCMOS25 } [get_ports { sw[9] }]

## LEDs
set_property -dict { PACKAGE_PIN C13  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN C14  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN D14  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN D15  IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN D16  IOSTANDARD LVCMOS33 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN F18  IOSTANDARD LVCMOS33 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN E17  IOSTANDARD LVCMOS33 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN D17  IOSTANDARD LVCMOS33 } [get_ports { led[7] }]
set_property -dict { PACKAGE_PIN C17  IOSTANDARD LVCMOS33 } [get_ports { led[8] }]

## UART TX -> onboard USB-UART bridge -> PC COM port
set_property -dict { PACKAGE_PIN B16  IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]

## SPI on PMOD A. JA2 is skipped because the master file lists the same
## package pins (H13/H14) for both JA2 and JB2.
set_property -dict { PACKAGE_PIN F14  IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }]
set_property -dict { PACKAGE_PIN F15  IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]
set_property -dict { PACKAGE_PIN J13  IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }]
set_property -dict { PACKAGE_PIN J14  IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]
