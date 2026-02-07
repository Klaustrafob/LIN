
module lin_node #(
 parameter
	CLK_FREQ	 	= 1000000, 		//1MHz
	BAUD_RATE		= 19200  		// 19200 UART rate
) (
    input
		clock,
		reset,
		rxd,
		tx_start,
	input [63:0] data_in,
	input [7:0] pid,
    output 
		txd,
		data_valid,
		tx_busy,
		rx_busy ,
//	output	reg slpn = '0,
	output	[63:0] data_out,
	output  err,
	output	[4:0] test
);


/*	localparam
		CLK_FREQ 		=  1000000,      	// 1MHz
		CLK_DIV			= CRYSTAL_FREQ/CLK_FREQ/2,
		wCLK			= $clog2(CLK_DIV)
	;

    // Module declarations
 logic clk1MHz = '0;

`ifdef ALTERA_RESERVED_QIS
    pll1MHz clk_pll(
        .inclk0(clk_50m),
        .c0(clk1MHz),
        .locked(slpn)
    );
`else
	reg [wCLK-1:0] clk_cnt = '0;
	always @(posedge clk_50m) begin
		if (clk_cnt)
			clk_cnt <= clk_cnt - 1'b1;
		else begin
			clk_cnt <= CLK_DIV-1;
			clk1MHz <= ~clk1MHz;
			if (clk1MHz)
				slpn <= '1;
		end
	end
	
`endif 

	wire reset = ~slpn;*/
	
	wire rx_err;
//	wire rx_busy;
	wire [4:0]rx_test;
    lin_rx #(
		CLK_FREQ,
		BAUD_RATE
	) lin_rx0 (
        .clk       	(clock   	),
        .rst       	(reset     	),
        .rx        	(rxd       	),
        .data_out  	(data_out  	),
        .data_valid	(data_valid	),
		.busy	   	(rx_busy   	),
		.err	   	(rx_err		),
		.test	   	(rx_test   	)
    );
	
	
	lin_tx #(
		CLK_FREQ,
		BAUD_RATE
	)lin_tx0(
		.clk    (clock 	 ) , //system clock
		.rst    (reset   ) , //reset
		.master	(1'b1    ) ,
		.start  (tx_start) , //start
		.pid    (pid     ) , //id or address
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