`ifdef ALTERA_RESERVED_QIS
 	`default_nettype none 			
`endif
module Lin10M08EVK (
    input
		clk_50m,
		rxd,
    output 
		txd,
		slpn,
	output reg [4:0] led = '0,
	output [1:0] pump,
	output [3:0] test
);

	wire	data_valid;
	wire [63:0] data_in, data_out;
	wire [4:0]lin_test;
	
 	localparam
		CRYSTAL_FREQ	=  50000000,
		LED_FREQ 		=      1			// 1Hz
	;	
	
	
	lin_node #(
		.CRYSTAL_FREQ 	(CRYSTAL_FREQ), // 50MHz
		.BAUD_RATE	  	(19200   )		// 19200 UART rate
	) lin_node0 		(
		.clk_50m		(clk_50m),
		.rxd			(rxd),
		.txd			(txd),
		.slpn			(slpn),
		.data_valid		(data_valid),
		.data_in		(data_in),
		.data_out   	(data_out),
		.pump			(),
		.test			(lin_test)
	);



	localparam int
		nLED			= CRYSTAL_FREQ/LED_FREQ,
		wLED 			= $clog2(nLED) //20
	;
	
	reg [wLED-1:0]led_cnt= '0;
	always @( posedge clk_50m) begin
		led_cnt <= led_cnt- 1'b1;
	end
	
	assign led[4:0] = ~({5{led_cnt[wLED-1]}} & {5{data_valid}} & data_out[4:0]);
	//assign pump = {led_cnt[8], ~led_cnt[8]};
	assign pump = lin_test[1:0];
	
	//always @( posedge clk_50m) led <= data_out[4:0];
	//assign led[3:0] = lin_test[3:0];
	//assign test = lin_test[3:0];
	
endmodule