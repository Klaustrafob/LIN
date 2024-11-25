
module lin_node #(
 parameter
	CRYSTAL_FREQ 	= 50000000, 	//50MHz
	BAUD_RATE		= 19200  		// 19200 UART rate
) (
    input
		clk_50m,
		rxd,
    output 
		txd,
		slpn,
		data_valid,
	input  [63:0] data_in,
	output [63:0] data_out,
	output [1:0] pump,
	output [4:0] test
);
	localparam
		CLK_FREQ 		=  1000000,      	// 1MHz
		CLK_DIV			= CRYSTAL_FREQ/CLK_FREQ/2,
		wCLK			= $clog2(CLK_DIV)
	;

    // Module declarations
logic reset = '0, clk1MHz = '0;
assign pump = {clk1MHz, ~clk1MHz};

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
		end
	end
	assign slpn = '1;
	
`endif

	always @(posedge clk1MHz)  reset <= ~slpn;
	
	wire rx_busy;
	wire [4:0]rx_test;
    lin_rx #(
		CLK_FREQ,
		BAUD_RATE
	) lin_rx0 (
        .clk       (clk1MHz   ),
        .rst       (reset     ),
        .rx        (rxd       ),
        .data_out  (data_out  ),
        .data_valid(data_valid),
		.busy	   (rx_busy   ),
		.test	   (rx_test   )
    );

 	wire tx_start, tx_busy;
	assign tx_start = '0;
	
	reg [7:0] pid;
	lin_tx #(
		CLK_FREQ,
		BAUD_RATE
	)lin_tx0(
		.clk    (clk1MHz ) , //system clock
		.rst    (reset   ) , //reset
		.master	(1'b0    ) ,
		.start  (tx_start) , //start
		.pid    (pid     ) , //id or address
		.data   (data_in ) , //
		.sdo	(txd     ) , //serial data out
		.busy	(tx_busy )	   
    );


	assign test = rx_test;

endmodule