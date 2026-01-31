# ###########################################
#                 Questasim
# ###########################################
cd $env(DOPATH)
wm state . zoomed
# -------------------------------------------
# variables
# -------------------------------------------
#set APLP			"$env(QUESTASIM_ALTERALIBDIR)/qpp_20_1_0/verilog_libs"
set ASLP			"C:/Work/verilog_libs"
set PRJ				{lin}
set TS				{1ns/1ps}

# puts "\" before special symbol, as "space" or "$"
#set DEF_PRJ 	+define+ADC_MARK="AD71124_SP0"+RBUS_DISABLE+INIT_SKIP+REVISION="P1"+SENSOR_TYPE="BOE"+AFE2256+INTENDED_DEVICE_FAMILY="Cyclone_10_LP"
#set DEF_PRJ	+define+ADC_MARK="AD71124_SP0"+RBUS_DISABLE+INIT_SKIP+REVISION="P1"+SENSOR_TYPE="BOE"+INTENDED_DEVICE_FAMILY="Cyclone_10_LP"
#set DEF_BENCH	+define+SENSOR_TYPE="BOE"+AFE2256
#set DEF_BENCH	+define+SENSOR_TYPE="INNOLUX"

if { [file exists vsim.wlf] == 1} {
	wlfrecover "vsim.wlf"
}
# -------------------------------------------
# optimization
# -------------------------------------------

set FULL_DEBUG			1
if {$FULL_DEBUG} {
	set DEBUG_PARAM		{+acc}
} else {
	set DEBUG_PARAM		{-nodebug}
}

# need delete already exist work library
set NEED_REMAKE_LIB		1
if {$NEED_REMAKE_LIB} {
	if {[file exists work]} {
			vdel -lib work -all
	}
}

vlib work
vmap work work

# -------------------------------------------
# compiling readout project`s files
# -------------------------------------------
vlog -incr -work work -sv 					\
../pll1MHz.v								\
../crcd64_o8.v								\
../lin_rx.sv                     	        \
../lin_node.sv		                     	\
../sinfo.sv									\
-timescale ${TS}


# -------------------------------------------
# compiling Testbench
# -------------------------------------------
vlog -incr -work work -sv			 	\
../lin_tx.sv							\
${PRJ}_tb.sv 							\
-timescale ${TS}

# -------------------------------------------
# 3. optimize design
# -------------------------------------------
vopt -work work ${DEBUG_PARAM} \
-L work \
-L ${ASLP}/altera_mf_ver \
-L ${ASLP}/altera_ver \
-L ${ASLP}/lpm_ver \
-L ${ASLP}/sgate_ver \
-L ${ASLP}/altera_lnsim_ver \
-L ${ASLP}/fiftyfivenm_ver \
${PRJ}_tb -o ${PRJ}_tb_opt

# 4. simulation
vsim -L work work.${PRJ}_tb_opt

# 5. create wave
view -undock wave
wm state .main_pane.wave zoomed
do wave_${PRJ}.do

run 16 ms
WaveRestoreZoom {600us} {8000us}
puts "*------------------SIMULATION DONE!------------------*"
