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
	output logic err = '0,
	output logic [4:0] test
);

    // State encoding
	typedef enum logic [3:0] {IDLE, BREAK, BREAK_DELIMITER, SYNC, SYNC_STOP, PID, PID_STOP, DATA, DATA_STOP, CRC, CRC_STOP} lin_state_type;
    lin_state_type state = IDLE;

    // Internal signals
    logic [7:0] shift_reg = '0;
    logic [63:0] data_buffer = '0;
    reg [3:0] bit_counter = '0; 
	reg [2:0] byte_counter = '0;
	
	//CRC instantiation
	reg  [8:0] crc = '0;	
 	wire [7:0] crc_out = ~(crc[7:0] + crc[8]);



    // Constant
    localparam int
		nBAUD	     = CLK_FREQ/BAUD_RATE,
		MAX_nBAUD	 = 1.14*nBAUD,//+14%
		MIN_nBAUD    = 0.86*nBAUD,//-14%
		SYNC_BREAK	 = 13,
		nBREAK		 = SYNC_BREAK*MIN_nBAUD,
		wTICK        = $clog2(nBREAK + 1),
		wBAUD		 = $clog2(MAX_nBAUD),
		SYNC_BYTE    = 8'h55
	;
	reg [wBAUD-1:0] bit_time = '0;
	
	reg [wTICK-1:0] tick_cnt = '0;
	wire [wTICK-1:0] tick_mod = tick_cnt + 1;
	wire [wBAUD-1:0] true_bit_time = (tick_mod>>3) + tick_mod[2]; //DIV 8 set baud rate
	

	reg drx = '0, sync = '0;
	
    // Main logic FSM
    always @(posedge clk) begin
		drx <= rx;
        if (rst) begin
            state <= IDLE;
			tick_cnt <= nBREAK - 1;
            bit_counter <= '0;
            byte_counter <= '0;
            shift_reg <= 8'b0;
            data_buffer <= 64'b0;
            data_valid <= 1'b0;
			sync <= '0;
			err <= '0;
        end
		
		case (state)
		
			default: begin
				sync <= '0;
				bit_counter <= '0;
				tick_cnt <= nBREAK - 1;
				if (!rx)
					state <= BREAK;
			end
			
			BREAK: begin
					if (tick_cnt) begin
						if (rx) begin																					// BREAK too short
							err <= '1;
							state <= IDLE;
						end else
							tick_cnt <= tick_cnt - 1'b1;
					end else if (rx) begin																					// BREAK is Ok
						tick_cnt <= MIN_nBAUD;
						state <= BREAK_DELIMITER;
					end
			end
			
			BREAK_DELIMITER: begin
				if(rx) begin
					if (tick_cnt)													// STOP continued
						tick_cnt <= tick_cnt - 1'b1;
				end else begin
					if (tick_cnt) begin												// STOP too short
						err <= '1;
						state <= IDLE;
					end else begin													// STOP Ok
						bit_counter <= '0;
						state <= SYNC;					
					end
				end
			end
				
			SYNC: begin
				sync <= rx ^ drx;
				if (sync) begin		
					if (bit_counter < 8) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						if (bit_counter)																			 // start bit don't care
							tick_cnt <= tick_cnt + 1'b1;
					end else begin
							bit_counter <= 0;
						if ((shift_reg == SYNC_BYTE)&& (true_bit_time >= MIN_nBAUD)&&(true_bit_time <= MAX_nBAUD)) begin // ±14% rate    SYNC pattern is Ok
							bit_time <= true_bit_time;
							tick_cnt <= true_bit_time - 4;															// 4 Sync delay
							state <= SYNC_STOP;
						end else begin
							err <= '1;
							state <= IDLE;
						end
					end
				end else if (bit_counter)
					tick_cnt <= tick_cnt + 1'b1;
			end
			
			
			SYNC_STOP:begin
				if(rx) begin
					if (tick_cnt)													// STOP continued
						tick_cnt <= tick_cnt - 1'b1;
				end else begin
					if (tick_cnt) begin												// STOP too short
						err <= '1;
						state <= IDLE;
					end else begin													// STOP Ok
						tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
						bit_counter <= '0;
						state <= PID;					
					end
				end
			end
			
			
			PID: begin
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						tick_cnt <= tick_cnt - 1'b1;
					end  else begin
						tick_cnt <= tick_cnt - 1'b1;
						bit_counter <= bit_counter + 1;
						byte_counter <= 0;					
						if (shift_reg[7:6] == {~(shift_reg[1] ^ shift_reg[3] ^ shift_reg[4] ^ shift_reg[5]), shift_reg[0] ^ shift_reg[1] ^ shift_reg[2] ^ shift_reg[4]}) begin
							crc <= shift_reg;
							data_valid <= 1'b0;
							tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
							state <= PID_STOP;
						end else begin
							err <= '1;
							state <= IDLE;
						end
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						tick_cnt <= bit_time - 1;						
					end
				end
			end
			
			
			PID_STOP:begin
				if(rx) begin
					if (tick_cnt)													// STOP continued
						tick_cnt <= tick_cnt - 1'b1;
				end else begin
					if (tick_cnt) begin												// STOP too short
						err <= '1;
						state <= IDLE;
					end else begin													// STOP Ok
						tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
						bit_counter <= '0;
						state <= DATA;					
					end
				end
			end			
			

			DATA: begin
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						bit_counter <= bit_counter + 1;
						shift_reg <= {rx, shift_reg[7:1]};
						tick_cnt <= tick_cnt - 1'b1;
					end else begin
						bit_counter <= bit_counter + 1;
						data_buffer[byte_counter*8 +: 8] <= shift_reg;
						crc <= crc[7:0]  + crc[8] + shift_reg;
						tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
						if (byte_counter < 7) begin
							state <= PID_STOP;
							byte_counter <= byte_counter + 1;
						end else begin
							byte_counter <= '0;
							state <= DATA_STOP;
						end
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						tick_cnt <= bit_time - 1;
					end
				end
			end
			
			
			DATA_STOP:begin
				if(rx) begin
					if (tick_cnt)													// STOP continued
						tick_cnt <= tick_cnt - 1'b1;
				end else begin
					if (tick_cnt) begin												// STOP too short
						err <= '1;
						state <= IDLE;
					end else begin													// STOP Ok
						tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
						bit_counter <= '0;
						state <= CRC;					
					end
				end
			end						
		

			CRC: begin
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						shift_reg <= {rx, shift_reg[7:1]};
						bit_counter <= bit_counter + 1;
						tick_cnt <= tick_cnt - 1'b1;
					end else begin
						bit_counter <= bit_counter + 1;
						data_out <= data_buffer;
						tick_cnt <= (bit_time>>1) + bit_time[0] - 3;
					// Verify checksum
						if (shift_reg == crc_out)
							data_valid <= 1'b1;
						else
							err <= '1;
						state <= CRC_STOP;
					end
				end else begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						sync <= '1;
						tick_cnt <= bit_time - 1;
					end
				end
			end
			
			CRC_STOP:begin
				if (tick_cnt) begin												// STOP continued
					if(rx)
						tick_cnt <= tick_cnt - 1'b1;
					else begin													// STOP too short		
						err <= '1;
						state <= IDLE;
					end 
				end else														// STOP Ok
					state <= IDLE;					
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
		.d   ({state,1'b0, tick_cnt, 6'b000000, bit_counter, data_out[39:0]}),
		.q   (s_info)
	);
	
	assign busy = (state != IDLE);
	
	assign test[4] = sync;								//44
	assign test[3] = err;								//43
	assign test[2] = busy;								//41
	assign test[1] = rx;								//39
	assign test[0] = s_info;							//38
	
	
endmodule