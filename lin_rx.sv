module lin_rx #(
 parameter
	CLK_FREQ,
	BAUD_RATE
) (
    input
		clk,
		rst,
		rx,
    
    output logic data_valid = '0, busy,
	output logic [63:0] data_out = '0,
	output logic [4:0] test
);

    // State encoding
    typedef enum logic [2:0] {IDLE, BREAK, SYNC, STOP, IDENTIFIER, DATA, CHECKSUM} lin_state_type;
    lin_state_type state = IDLE, next_state = IDLE;

    // Internal signals
    logic [7:0] shift_reg = '0;
    logic [63:0] data_buffer = '0;
    reg [3:0] bit_counter = '0, byte_counter = '0;
	
	//CRC instantiation
 	reg [7:0] crc_out = '0;
	reg [8:0] crc = '0;


    // Constant
    localparam int
		nBAUD	     	= CLK_FREQ/BAUD_RATE,
		MAX_nBAUD	 	= 1.14*nBAUD,//+14%
		MIN_nBAUD    	= 0.86*nBAUD,//-14%
		SYNC_BREAK_MAX	= 13,
		SYNC_BREAK_MIN	= 11,
		nBREAK_MAX	 	= SYNC_BREAK_MAX*nBAUD,
		nBREAK_MIN	 	= SYNC_BREAK_MIN*nBAUD,
		wTICK        	= $clog2(nBREAK_MAX + 1),
		wBAUD		 	= $clog2(nBAUD),
		SYNC_BYTE    	= 8'h55
	;
	reg [wBAUD:0] bit_time = '0; 		// x2 nBAUD
	
	reg [wTICK-1:0] tick_cnt = '0;
	wire [wTICK-1:0] tick_mod = tick_cnt + 1;
	wire [wBAUD:0] true_bit_time =(tick_mod>>3) + tick_mod[2]; //DIV 8 set baud rate
	
	reg drx = '0;
	reg sync = '0;
	wire [28:0] result;
	wire [wBAUD:0] new_bit_time = result >> 22; // 6+16pos
	
	lpm_mult #(
		.lpm_hint 			( "INPUT_B_IS_CONSTANT=YES,MAXIMIZE_SPEED=5"),
		.lpm_pipeline 		( 1											),
		.lpm_representation ( "UNSIGNED"								),
		.lpm_type 			( "LPM_MULT"								),
		.lpm_widtha 		( 16										),
		.lpm_widthb 		( 13										),
		.lpm_widthp 		( 29										)
	)SyncDivider(
		.clken 	(sync			),
		.clock 	(clk			),
		.dataa 	(tick_mod << 6	), //6pos = *64
		.datab 	(13'h199A		), //65536(16pos) div 10 = 6554
		.result (result			),
		.aclr 	(1'b0			),
		.sclr 	(1'b0			),
		.sum 	(1'b0			)
	);
	
	
    // Main logic
    always @(posedge clk) begin
		drx <= rx;
        if (rst) begin
            state <= STOP;
			next_state <= BREAK;
			tick_cnt <= nBREAK_MAX - 1;
            bit_counter <= '0;
            byte_counter <= '0;
            shift_reg <= 8'b0;
            data_buffer <= 64'b0;
            data_valid <= 1'b0;
        end
		
		case (state)
		
			default: begin
					if(rx) begin
						if (tick_cnt)											// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
					end else begin
						if (tick_cnt) begin										// STOP too short
							tick_cnt <= nBREAK_MAX - 1;
							state <= BREAK;
						end else begin											// STOP Ok
							state <= next_state;
							if(next_state == BREAK)
								tick_cnt <= nBREAK_MAX - 1;
							else
								tick_cnt <= (bit_time>>1) + bit_time[0]; 	   //set sync phase for data							
						end
					end
				end
			
			BREAK: begin
					if (tick_cnt) begin
						if (rx) begin									//BREAK too short
							tick_cnt <= nBREAK_MAX - 1;
							state <= STOP;								
						end else
							tick_cnt <= tick_cnt - 1'b1;
					end else if (rx)									// BREAK Ok
						state <= SYNC;
			end
				
			
			SYNC: begin
				sync <= rx ^ drx;
				if (sync) begin		
					if (bit_counter < 9) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						if (bit_counter > 1)
							tick_cnt <= tick_cnt + 1'b1;
					end else begin
						state <= STOP;	
						if ((shift_reg == SYNC_BYTE)&& (true_bit_time >= MIN_nBAUD)&&(true_bit_time <= MAX_nBAUD)) begin // ±14% rate
							next_state <= IDENTIFIER;
							bit_counter <= 0;
							bit_time <= true_bit_time;
							tick_cnt <= true_bit_time - 3;
						end else begin
							tick_cnt <= nBREAK_MAX - 1;
							next_state <= BREAK;
						end
					end
				end else if (bit_counter > 1)
					tick_cnt <= tick_cnt + 1'b1;
			end
			



			IDENTIFIER: begin
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						tick_cnt <= tick_cnt - 1'b1;
					end  else  begin
						bit_counter <= 0;
						byte_counter <= 0;
						state <= STOP;
						tick_cnt <= bit_time - 3;
						if (shift_reg[7:6] == {~(shift_reg[1] ^ shift_reg[3] ^ shift_reg[4] ^ shift_reg[5]), shift_reg[0] ^ shift_reg[1] ^ shift_reg[2] ^ shift_reg[4]}) begin
							next_state <= DATA;
							crc <= shift_reg;
							data_valid <= 1'b0;
						end else begin
							next_state <= BREAK;
						end
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						if(bit_counter < 8)
							tick_cnt <= bit_time - 1;
						else
							tick_cnt <= (bit_time>>1) + bit_time[0] - 2; //set sync phase for STOP
					end
				end
			end

			DATA: begin		
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						tick_cnt <= tick_cnt - 1'b1;
						bit_counter <= bit_counter + 1;
						shift_reg <= {rx, shift_reg[7:1]};
					end else begin
						tick_cnt <= bit_time - 3;
						bit_counter <= 0;
						state <= STOP;
						data_buffer[byte_counter*8 +: 8] <= shift_reg;
						crc <= crc[7:0]  + crc[8] + shift_reg;						
						if (byte_counter < 7) begin
							byte_counter <= byte_counter + 1;
							next_state <= DATA;
						end else begin
							byte_counter <= '0;
							next_state <= CHECKSUM;
						end
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						if(bit_counter < 8)
							tick_cnt <= bit_time - 1;
						else
							tick_cnt <= (bit_time>>1) + bit_time[0] - 2; //set sync phase for STOP
					end
				end
			end

			CHECKSUM: begin		
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						crc_out <= ~(crc[7:0]  + crc[8]);
					end else begin
							bit_counter <= '0;
							tick_cnt <= bit_time - 3;
							state <= STOP;
							next_state <= BREAK;
						// Verify checksum
						if (shift_reg == crc_out) begin
							data_out <= data_buffer;
							data_valid <= 1'b1;
						end
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						if(bit_counter < 8)
							tick_cnt <= bit_time - 1;
						else
							tick_cnt <= (bit_time>>1) + bit_time[0] - 2; //set sync phase for STOP
					end
				end
			end
							
		endcase
    end

	wire s_info;
	sinfo #( 
		.GROUPS	(8),
		.WORDS 	(2),
		.WIDTH 	(4)
	)sinfo0(
		.clk (clk),
		.d   ({state,1'b0,bit_counter, tick_cnt, 6'b000000, data_out[39:0]}),
		.q   (s_info)
	);
	
	assign busy = (state != IDLE);
	
	assign test[4] = state == SYNC;						//44
	assign test[3] = state == BREAK;					//43
	assign test[2] = state == IDLE;						//41
	assign test[1] = rx;								//39
	assign test[0] = s_info;							//38
	
	
endmodule