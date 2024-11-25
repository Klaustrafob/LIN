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


#**************************************************************
# Create Generated Clock
#**************************************************************
create_generated_clock -name clk1MHz -source [get_pins {lin_node0|clk_pll|altpll_component|auto_generated|pll1|inclk[0]}] -divide_by 50 [get_pins {lin_node0|clk_pll|altpll_component|auto_generated|pll1|clk[0]}]

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

set in_delay 0.000
set in_uncertainty 0.000
set min_delay [expr $in_delay - $in_uncertainty]
set max_delay [expr $in_delay + $in_uncertainty]
set_input_delay -clock clk1MHz -min $min_delay [get_ports {rxd}]
set_input_delay -clock clk1MHz -max $max_delay [get_ports {rxd}]


#**************************************************************
# Set Output Delay
#**************************************************************
set out_delay 0.000
set out_uncertainty 0.000
set min_delay [expr $out_delay - $out_uncertainty]
set max_delay [expr $out_delay + $out_uncertainty]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {led[*]}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {led[*]}]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {txd}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {txd}]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {slpn}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {slpn}]
set_output_delay -clock clk1MHz -min $min_delay [get_ports {pump[*]}]
set_output_delay -clock clk1MHz -max $max_delay [get_ports {pump[*]}]

#**************************************************************
# Set Clock Groups
#**************************************************************
#set_clock_groups -exclusive\
#  -group [get_clocks {F50 clk1MHz}]\
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