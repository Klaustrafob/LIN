`ifdef ALTERA_RESERVED_QIS
 	`default_nettype none 			
`endif

module Lin10M08EVK (
    input
		clk_50m,
		rxd,
    output 
		txd,
	output logic       slpn,
	output logic [4:0] led ,
	output     [4:0] test
);

	localparam
		CLK_FREQ 		=  1000000,      	// 1MHz
		CLK_DIV			= CRYSTAL_FREQ/CLK_FREQ/2,
		wCLK			= $clog2(CLK_DIV)
	;

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

	wire data_valid,tx_start,tx_busy,rx_busy;
	wire [63:0] data_in, data_out;
	assign data_in = 64'h584C410110620816;
	wire [4:0]lin_test;
	wire [5:0] pid;
	wire lin_start, lin_err;
	
 	localparam CRYSTAL_FREQ	=  50000000;
	localparam real	LED_FREQ = 0.2;			// 1Hz
	wire classic;
	
	lin_node #(
		.CLK_FREQ			(CLK_FREQ	),		// 1MHz
		.BAUD_RATE	  		(19200   	),		// 19200 UART rate
		.PID				(6'h3D		)
	) lin_node0 			(
		.reset				(~slpn		),
		.clock				(clk1MHz	),
		.rxd				(rxd		),
		.classic			(classic	),
		.data_in			(data_in	),
		.txd				(txd		),
		.master				(1'b0		), 
		.start				(lin_start  ),
		.data_valid			(data_valid	),
		.tx_busy			(tx_busy	),
		.rx_busy			(rx_busy	),
		.data_out   		(data_out	),
		.err				(lin_err	),
		.test				(lin_test	)
	);

	localparam int
		nLED			= CRYSTAL_FREQ/LED_FREQ,
		wLED 			= $clog2(nLED) //20
	;
	
/* 	reg [wLED-1:0]led_cnt = '0;
	always @( posedge clk_50m) begin
		led_cnt <= led_cnt- 1'b1;
	end */
	
	reg [4:0]err_cnt = '0;
	always @( posedge clk1MHz) begin err_cnt <= err_cnt + (err_cnt[0] ^ lin_err); end
	
	assign led[4] = ~classic;//led_cnt[wLED-1];
	assign led[3:0] = ~err_cnt[4:1];
	//assign led[4:0] = ~({5{led_cnt[wLED-1]}} & {5{data_valid}} & data_out[4:0]);
	//always @( posedge clk_50m) led <= data_out[4:0];
	//assign led[3:0] = lin_test[3:0];
	assign test = lin_test;
	
endmodule