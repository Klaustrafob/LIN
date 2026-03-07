onerror {resume}
quietly WaveActivateNextPane {} 0
quietly set DefaultRadix {unsigned}

add wave -group TB /lin_tb/*

add wave -group LIN_NODE   /lin_tb/lin_node0/*
add wave -group -expand LIN_RX  /lin_tb/lin_node0/lin_rx0/*
add wave -group -expand LIN_TX  /lin_tb/lin_node0/lin_tx0/*

radix signal /lin_tb/lin_node0/lin_rx0/data_buffer 			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/data_out    			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/shift_reg   			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/crc					-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/crc_ff				-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/classic_crc			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_rx0/classic_crc_ff		-hexadecimal -showbase



radix signal /lin_tb/lin_node0/lin_tx0/data_reg     -hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_tx0/data         -hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_tx0/crc			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_tx0/crc_ff		-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_tx0/pid			-hexadecimal -showbase
radix signal /lin_tb/lin_node0/lin_tx0/pid_adrs_reg	-hexadecimal -showbase


#TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 400
configure wave -timelineunits us