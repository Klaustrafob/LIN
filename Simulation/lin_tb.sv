`timescale 1ns / 1ps
module lin_tb();
	logic clk_50m		 						;
    logic sys_clk        						;
    logic rstn           						;
	logic lin_start		 						;
	logic lin_master							;
    logic [63:0] data    						;
    logic txd, rxd, slpn, data_valid			;
    logic tx_busy, rx_busy, classic, lin_err	;
	logic [63:0] data_in = 64'h0807060504030201, data_out			;
		
	parameter int
		f50m  	= 50000000				, // 50MHz
		t50m  	= 1000000000/f50m		, // 20ns
		bRATE 	= 19200					, // 19200 Hz
		tBAUD 	= 1000000000/bRATE		, // 52us 19200Hz
		fSYS  	= 1000000				, // 1MHz
		tSYS  	= 1000000000/fSYS 		, // 1000ns
		tBREAK 	= 13*tBAUD				, // 676us
		PID		= 6'h2e
	;

	assign rxd = txd;
	
	lin_node #(
		fSYS,
		bRATE,
		PID
		) lin_node0 (
		.clock		(sys_clk	),
		.reset		(~rstn		),
		.rxd		(rxd		),
		.classic	(1'b1		),
		.rx_classic	(rx_classic ),
		.data_in	(data_in	),
//		.pid		(pid		),
		.txd		(txd		),
		.master		(lin_master	),
		.start		(lin_start  ),
		.data_valid	(data_valid	),
		.tx_busy	(tx_busy	),
		.rx_busy 	(rx_busy	),
		.err		(lin_err	),		
		.data_out	(data_out	),
		.test		(			)	
	);
		
    initial begin
		clk_50m 				= 0;
        sys_clk 				= 0;
        rstn    				= 0;
		lin_master				= 1;
		lin_start			   	= 0;
		#tBREAK    				   ;
		rstn					= 1;
		forever if(!rx_busy) begin
			lin_start			= 1;
//			pid     			= 6'h2e;
			data_in    			= data_in + 1;
			#tSYS;
			lin_start			= 0;
			while (tx_busy)		#tSYS;
			lin_master			= 0;
			#tBREAK;
			lin_start			= 1;
			data_in    			= data_in + 2;						
			#tSYS;
			lin_start			= 0;
			while (tx_busy)		#tSYS;
			lin_master			= 1;
			#tBREAK;
		end
    end

	always #(t50m/2)  clk_50m = ~clk_50m;
    always #(tSYS/2)  sys_clk = ~sys_clk;

endmodule
