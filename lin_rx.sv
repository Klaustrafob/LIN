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
    typedef enum logic [2:0] {IDLE, SYNC, STOP, IDENTIFIER, DATA, CHECKSUM} lin_state_type;
    lin_state_type state = IDLE, next_state = IDLE;

    // Internal signals
    logic [7:0] shift_reg = '0;
    logic [63:0] data_buffer = '0;
    reg [3:0] bit_counter = '0, byte_counter = '0;
	
	//CRC instantiation
 	reg [7:0] crc_out = '0;
	reg [8:0] crc = '0;

/*    crcd64_o8 CRCD64_O8(
		.crc_in  (8'hFF ),
		.data_in (64'hffffffffffffffff),
		.crc_out (crc_out)
    ); */

    // Constant
    localparam int
		nBAUD	     = CLK_FREQ/BAUD_RATE,
		MAX_nBAUD	 = 1.14*nBAUD,//+14%
		MIN_nBAUD    = 0.86*nBAUD,//-14%
		SYNC_BREAK	 = 13,
		tBREAK		 = SYNC_BREAK*nBAUD,
		wTICK        = $clog2(tBREAK + 1),
		wBAUD		 = $clog2(nBAUD),
		SYNC_BYTE    = 8'h55
	;
	reg [wBAUD:0] bit_time = '0; 		// x2 nBAUD
	
	reg [wTICK-1:0] tick_cnt = '0;
	wire [wTICK-1:0] tick_mod = tick_cnt + 1;
	wire [wBAUD:0] true_bit_time =(tick_mod>>3) + tick_mod[2]; //DIV 8 set baud rate
	

	reg drx = '0;
	reg sync = '0;
	
    // Main logic
    always @(posedge clk) begin
		drx <= rx;
        if (rst) begin
            state <= IDLE;
			next_state <= IDLE;
			tick_cnt <= tBREAK - 1;
            bit_counter <= '0;
            byte_counter <= '0;
            shift_reg <= 8'b0;
  //          pid <= 6'b0;
            data_buffer <= 64'b0;
 //           tx <= 1'b1;
            data_valid <= 1'b0;
        end
		
		case (state)
			IDLE: begin
				//next_state <= IDLE;
					if (tick_cnt) begin
						if (rx)
							tick_cnt <= tBREAK - 1;
						else
							tick_cnt <= tick_cnt - 1'b1;
					end else if (rx)
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
						if ((shift_reg == SYNC_BYTE)&& (true_bit_time >= MIN_nBAUD)&&(true_bit_time <= MAX_nBAUD)) begin // ±14% rate
							next_state <= IDENTIFIER;
							state <= STOP;
							bit_counter <= 0;
							bit_time <= true_bit_time;
							tick_cnt <= true_bit_time<<1; //set 2 bit max STOP
						end else begin
							tick_cnt <= tBREAK - 1;
						//	next_state <= IDLE;
							state <= IDLE;
						end
					end
				end else if (bit_counter > 1)
					tick_cnt <= tick_cnt + 1'b1;
			end
			
			STOP: if(rx) begin
					if (tick_cnt)									// STOP continued
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						tick_cnt <= tBREAK - 1;
						state <= IDLE;
					end
				end else begin
					tick_cnt <= (bit_time>>1) + bit_time[0] - 2; 		//set sync phase
					state <= next_state;
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
						if (shift_reg[7:6] == {~(shift_reg[1] ^ shift_reg[3] ^ shift_reg[4] ^ shift_reg[5]), shift_reg[0] ^ shift_reg[1] ^ shift_reg[2] ^ shift_reg[4]}) begin
							next_state <= DATA;
							crc <= '0;
							data_valid <= 1'b0;
							tick_cnt <= bit_time<<1;
							state <= STOP;
						end else begin
							tick_cnt <= tBREAK - 1;
						//	next_state <= IDLE;
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

			DATA: begin		
				if (sync) begin
					sync <= '0;
					if (bit_counter < 9) begin
						tick_cnt <= tick_cnt - 1'b1;
						bit_counter <= bit_counter + 1;
						shift_reg <= {rx, shift_reg[7:1]};
					end else begin
						tick_cnt <= bit_time<<1;
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
						tick_cnt <= bit_time - 1;
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
							tick_cnt <= tBREAK - 1;
						//	next_state <= IDLE;
							state <= IDLE;
						// Verify checksum
						if (shift_reg == crc_out) begin
							data_out <= data_buffer;
							data_valid <= 1'b1;
						end
					end
				end begin
					if (tick_cnt)
						tick_cnt <= tick_cnt - 1'b1;
					else begin
						tick_cnt <= bit_time - 1;
						sync <= '1;
					end
				end
			end
			
			default: begin
				tick_cnt <= tBREAK - 1;
				data_valid <= 1'b0;
//				next_state <= IDLE;
				state <= IDLE;
			end
				
		endcase
    end

	wire s_info;
	sinfo #( 
		.GROUPS	(1),
		.WORDS 	(2),
		.WIDTH 	(8)
	)sinfo0(
		.clk (clk),
		.d   ({shift_reg, crc_out}),
		.q   (s_info)
	);
	
	assign busy = (state != IDLE);
	
	assign test[4] = busy;
	assign test[3] = (shift_reg == crc_out);
	assign test[2] = data_valid;
	assign test[1] = rx & (state == CHECKSUM);
	assign test[0] = s_info;
	
	
endmodule