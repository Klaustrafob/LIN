onerror {resume}
quietly WaveActivateNextPane {} 0
quietly set DefaultRadix {unsigned}

add wave -group TB /lin_tb/*

add wave -group LIN_NODE   /lin_tb/lin_node0/*
add wave -group -expand LIN_RX  /lin_tb/lin_node0/lin_rx0/*
add wave -group -expand LIN_TX  /lin_tb/lin_tx1/*




#TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 400
configure wave -timelineunits us