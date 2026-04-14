Data Link Layer of the LIN interface. Supports master/slave mode, classic checksum, and enhanced checksum.
Baud Rate 19200
Mode - Master/Slave
CRC  - Classic, Enhanced
FPGA - Altera_10M08S_E144_eval_Kit
PHY  - TJA1029

Quartus
  Lin10M08EVK.qpf
  Lin10M08EVK.qsf
  Lin10M08EVK.sdc
RTL
  Lin10M08EVK.sv  - Top
  lin_node.sv
  lin_rx.sv
  lin_tx.sv
  sinfo.sv - serial test output
Sim (Questasim and compiled Verilog libraries)
  sim.bat
  lin.do
  wave_lin.do
  lin_tb.sv
Run  \Simulation\sim.bat to run the simulation
