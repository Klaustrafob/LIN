`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Sudhee
//
// Create Date: 16.05.2023 18:44:26
// Design Name: LIN Testbench
// Module Name: lin_top_tb
// Project Name: LIN Protocol
// Target Devices: Zynq 7020
// Tool Versions: Vivado
// Description: Testbench to simulate LIN Protocol.
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module lin_tb();
	logic clk_50m		 			;
    logic sys_clk        			;
    logic rstn           			;
	logic start			 			;
    logic [5:0] pid      			;
    logic [63:0] data    			;
    logic txd, rxd, slpn,data_valid ;
    logic [33:0] frame_header_out  	;
	logic [89:0] response_out      	;
    logic comm_tx_done             	;
    logic resp_tx_done = 0         	;
	logic resp_busy				   	;
	logic lin_busy 				   	;
	logic inter_tx_delay    		;//inter transmission delay
		
	parameter int
		f50m  = 50000000			, // 50MHz
		t50m  = 1000000000/f50m		, // 20ns
		bRATE = 19200				, // 19200 Hz
		fSYS  = 1000000				, // 1MHz
		tSYS  = 1000000000/fSYS 	  //52us 19200Hz		   	
	;

	logic [63:0] data_in = '0, data_out;
	
	lin_node #(
		f50m,
		bRATE
		) lin_node0 (
		.clk_50m	(clk_50m),
		.rxd		(txd),
		.txd		(rxd),
		.slpn		(slpn),
		.data_valid	(data_valid),
		.data_in	(data_in),
		.data_out	(data_out)	 
	);
	
	
	lin_tx #(
		fSYS,
		bRATE
	)lin_tx1(
		.clk    (sys_clk ) , //system clock
		.rst    (~rstn   ) , //reset
		.master	(1'b1    ) ,
		.start  (start   ) , //start
		.pid    (pid     ) , //id or address
		.data   (data    ) , //
		.sdo	(txd     ) , //serial data out
		.busy	()	   
    );

    initial begin
		clk_50m = 0;
        sys_clk = 0;
        rstn    = 0;
		start   = 0;
        pid     = 0;
        data    = 0;
        #tSYS;
        rstn    = 1;
		start   = 1;
        pid     = 6'h2e;
        data    = 64'h0807060504030201;
		#tSYS
		start   = 0;
    end

	always #(t50m/2)  clk_50m = ~clk_50m;
    always #(tSYS/2)  sys_clk = ~sys_clk;

endmodule
