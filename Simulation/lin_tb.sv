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
    logic txd, rxd, slpn, data_valid;
    logic tx_busy, rx_busy  		;
	logic [63:0] data_in = '0, data_out;
		
	parameter int
		f50m  	= 50000000				, // 50MHz
		t50m  	= 1000000000/f50m		, // 20ns
		bRATE 	= 19200					, // 19200 Hz
		tBAUD 	= 1000000000/bRATE		, // 52us 19200Hz
		fSYS  	= 1000000				, // 1MHz
		tSYS  	= 1000000000/fSYS 		, // 1000ns
		tBREAK 	= 13*tBAUD			  	  // 676us
	;

	assign rxd = txd;
	
	lin_node #(
		fSYS,
		bRATE
		) lin_node0 (
		.clock		(sys_clk	),
		.reset		(~rstn		),
		.rxd		(rxd		),
		.tx_start	(start		),
		.data_in	(data_in	),
		.pid		(pid		),
		.txd		(txd		),
		.data_valid	(data_valid	),
		.tx_busy	(tx_busy	),
		.rx_busy 	(rx_busy	),		
		.data_out	(data_out	),
		.test		(			)	
	);
		
    initial begin
		clk_50m 	= 0;
        sys_clk 	= 0;
        rstn    	= 0;
		start   	= 0;
        pid     	= 0;
        data_in    	= 0;
		#tBREAK    	   ;
		rstn		= 1;
		forever if(!tx_busy && !rx_busy) begin
			start   	= 1;
			pid     	= 6'h2e;
			data_in    	= 64'h0807060504030201;
			#tSYS;
			start   	= 0;
			while (tx_busy)   #tSYS;
			#tBREAK;
		end
    end

	always #(t50m/2)  clk_50m = ~clk_50m;
    always #(tSYS/2)  sys_clk = ~sys_clk;

endmodule
