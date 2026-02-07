## Generated SDC file "Lin10M08EVK.sdc"

## Copyright (C) 2019  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 19.1.0 Build 670 09/22/2019 SJ Standard Edition"

## DATE    "Mon Jul 20 12:17:02 2020"

##
## DEVICE  "10M04DCF256I7G"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3


#**************************************************************
# Create Clock     
#**************************************************************
create_clock -name {F50} -period 20  [get_ports clk_50m]
#create_clock -name {bit_clk} -period 100000 [get_pins {lin_node0|lin_rx0|bit_counter[1]|combout}]
#create_clock -name {stat_clk} -period 100000 [get_pins {lin_node0|lin_rx0|state.IDLE_4509|combout}]

# 1. Create a clock for the TCK port (typically 10-25MHz)
# create_clock -name {altera_reserved_tck} -period 40.000 [get_ports altera_reserved_tck]

# 2. Cut JTAG paths to/from the main design (prevents timing failures in core logic)
# set_clock_groups -asynchronous -group [get_clocks altera_reserved_tck]

# 3. Constrain the Input Ports (TMS, TDI)
set_input_delay -clock {altera_reserved_tck} -clock_fall 1 [get_ports altera_reserved_tms]
set_input_delay -clock {altera_reserved_tck} -clock_fall 1 [get_ports altera_reserved_tdi]

# 4. Constrain the Output Port (TDO)
set_output_delay -clock {altera_reserved_tck} -clock_fall 1 [get_ports altera_reserved_tdo]


#**************************************************************
# Create Generated Clock
#**************************************************************
create_generated_clock -name clk1MHz -source [get_pins {clk_pll|altpll_component|auto_generated|pll1|inclk[0]}] -divide_by 50 [get_pins {clk_pll|altpll_component|auto_generated|pll1|clk[0]}]

#derive_pll_clocks

#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty

#**************************************************************
# Set Input Delay
#**************************************************************

set in_delay 2
set in_uncertainty 1
set min_delay [expr $in_delay - $in_uncertainty]
set max_delay [expr $in_delay + $in_uncertainty]

set_input_delay -clock {altera_reserved_tck} -clock_fall 2.0 [get_ports {altera_reserved_tms}]
set_input_delay -clock {altera_reserved_tck} -clock_fall 2.0 [get_ports {altera_reserved_tdi}]


set_input_delay -clock clk1MHz -min $min_delay [get_ports {rxd}]
set_input_delay -clock clk1MHz -max $max_delay [get_ports {rxd}]


#**************************************************************
# Set Output Delay
#**************************************************************
set out_delay 2
set out_uncertainty 1
set min_delay [expr $out_delay - $out_uncertainty]
set max_delay [expr $out_delay + $out_uncertainty]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {led[*]}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {led[*]}]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {txd}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {txd}]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {slpn}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {slpn}]

set_output_delay -clock {altera_reserved_tck} -clock_fall 2.0 [get_ports {altera_reserved_tdo}]

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -exclusive\
  -group [get_clocks {F50 clk1MHz}]\
  -group [get_clocks altera_reserved_tck]
#  -group [get_clocks {bit_clk}]\
#  -group [get_clocks {stat_clk}]

#**************************************************************
# Set False Path
#**************************************************************
#set_false_path -from [get_ports {RESET_N}]
set_false_path -to [get_ports {test[*]}]
#**************************************************************
# Set Multicycle Path
#**************************************************************


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************