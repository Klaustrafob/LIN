
module lin_node #(
 parameter
	CLK_FREQ	, 		//1MHz
	BAUD_RATE	,  		// 19200 UART rate
	PID
) (
    input
		clock, reset, rxd, master, start,
	input [63:0] 
		data_in,
    output 
		txd, classic,data_valid,tx_busy,rx_busy,err,
	output	[63:0] 
		data_out,
	output	[4:0] 
		test
);

	wire rx_err, request; 
	reg  tx_start = '0;
	wire [4:0]rx_test;
	wire [5:0]rx_pid;
    lin_rx #(
		CLK_FREQ,
		BAUD_RATE
	) lin_rx0 (
        .clk       	(clock   	),
        .rst       	(reset     	),
        .rx        	(`ifdef ALTERA_RESERVED_QIS tx_busy ? 1'b1 : rxd  `else rxd     `endif),
		.master		(`ifdef ALTERA_RESERVED_QIS master                `else ~master `endif),		
		.classic	(classic	),
        .data_out  	(data_out  	),
        .data_valid	(data_valid	),
		.busy	   	(rx_busy   	),
		.pid		(rx_pid		),
		.req		(request	),
		.err	   	(rx_err		),
		.test	   	(rx_test   	)
    );
	

	always @(posedge clock) begin tx_start <= ~tx_busy & (start | request); end


	lin_tx #(
		CLK_FREQ,
		BAUD_RATE
	)lin_tx0(
		.clk    (clock 	 ) , //system clock
		.rst    (reset   ) , //reset
		.master	(master  ) ,
		.classic(classic ) ,
		.start  (tx_start) , //start
		.pid    (PID  	 ) , //id or address
		.data   (data_in ) , //
		.sdo	(txd     ) , //serial data out
		.busy	(tx_busy )	   
    );

	assign err = rx_err;
	assign test = rx_test;			//43
	                                //41
	                                //39
	                                //38
endmodule