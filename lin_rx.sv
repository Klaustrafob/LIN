module lin_rx #(
 parameter
	CLK_FREQ,
	BAUD_RATE,
	MASTER_PID
) (
    input
		clk,rst,rx,master,
	output
		busy,
    output reg 
		data_valid = '0, err = '0, req = '0, classic = '0,
	output reg [5:0]
		pid,
	output reg [63:0] 
		data_out = '0,
	output reg [4:0] 
		test
);

    // State encoding
	typedef enum reg [3:0] {IDLE, BREAK, BREAK_DELIMITER, SYNC, SYNC_STOP, PID, PID_STOP, BYTE_STOP, DATA, DATA_STOP, CRC, CRC_STOP} lin_state_type;
    lin_state_type state = IDLE;
	
    // Constant
    localparam int
		nBAUD	     = CLK_FREQ/BAUD_RATE,
		MAX_nBAUD	 = 1.14*nBAUD,//+14%
		MIN_nBAUD    = 0.86*nBAUD,//-14%
		SYNC_BREAK	 = 13,
		nBREAK		 = SYNC_BREAK*MIN_nBAUD,
		wTICK        = $clog2(nBREAK + 1),
		wBAUD		 = $clog2(MAX_nBAUD),
		SYNC_BYTE    = 8'h55,
		CRC_OK		 = 8'hFF,
		nWIN		 = 4         //Majority window
	;	

    // Internal signals
    reg [7:0] shift_reg = '0;
    reg [63:0] data_buffer = '0;
    reg [3:0] bit_counter = '0; 
	reg [2:0] byte_counter = '0;
	wire [7:0] master_pid;
	assign master_pid[5:0] = MASTER_PID;
	assign master_pid[7:6] = {~(master_pid[1] ^ master_pid[3] ^ master_pid[4] ^ master_pid[5]), master_pid[0] ^ master_pid[1] ^ master_pid[2] ^ master_pid[4]};
	
	//CRC instantiation
	function automatic [7:0] crc (input [7:0] a, b);
		reg [8:0] tcrc;
		begin
			tcrc = a + b;
			return tcrc[7:0] + tcrc[8];
		end
	endfunction
	
	reg  [7:0] crc_ff = '0;	
// 	wire [8:0] tcrc = crc_ff + shift_reg;
//	wire [7:0] crc = tcrc[7:0] + tcrc[8];
	
	reg  [7:0] classic_crc_ff = '0;
//	wire [8:0] tclassic_crc = classic_crc_ff + shift_reg;
//	wire [7:0] classic_crc = tclassic_crc[7:0] + tclassic_crc[8];
	
	reg [wTICK-1:0] tick_cnt = '0;
	
	//  Majority vote
	reg [nWIN-1:0]window = '0;
	function automatic [$clog2(nWIN+1)-1:0] popcount;
		input [nWIN-1:0] v;
		integer i;
		begin
			popcount = '0;
			for (i = 0; i < nWIN; i++)
				popcount = popcount + v[i];
		end
	endfunction
	wire [$clog2(nWIN+1)-1:0] ones = popcount(window);
	reg bit_val = '0;
	
	
	reg sync = '0;
	
    // Main logic FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
			window <= '0;
			bit_val = '0;
            state <= IDLE;
			tick_cnt <= nBREAK - 1;
            bit_counter <= '0;
            byte_counter <= '0;
            shift_reg <= 8'b0;
            data_buffer <= 64'b0;
            data_valid <= 1'b0;
			pid <= '0;
			req <= '0;
			sync <= '0;
			err <= '0;
        end else begin
			window <= {window[nWIN-2:0], rx};
			bit_val <= (ones > nWIN/2);         				// most one → bit = 1
			case (state)
			
				default: begin									// IDLE
					req <= '0;
					sync <= '0;
					bit_counter <= '0;
					err <= '0;
					if (!bit_val) begin
						if (master) begin						// master mode
							tick_cnt <= nBAUD/2 - 4;
							classic_crc_ff <= '0;
							crc_ff <= master_pid;
							data_valid <= 1'b0;
							state <= DATA;
						end	else begin							// slave mode
							tick_cnt <= nBREAK - 1;
							state <= BREAK;
						end
					end
				end
				
				BREAK: begin
						if (tick_cnt) begin
							if (bit_val) begin						// BREAK too short
								err <= '1;
								state <= IDLE;
							end else
								tick_cnt <= tick_cnt - 1'b1;
						end else if (bit_val) begin					// BREAK is Ok
							tick_cnt <= MIN_nBAUD;
							state <= BREAK_DELIMITER;
						end
				end
				
				BREAK_DELIMITER: begin
					if(bit_val) begin
						if (tick_cnt)							// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
					end else begin
						if (tick_cnt) begin						// STOP too short
							err <= '1;
							state <= IDLE;
						end else begin							// STOP Ok
							tick_cnt <= nBAUD + 4;
							bit_counter <= '0;
							state <= SYNC;					
						end
					end
				end
					
				SYNC: begin
					sync <= bit_val ^ (ones > nWIN/2);
					if (sync) begin		
						if (bit_counter < 8) begin
							shift_reg <= {bit_val, shift_reg[7:1]};
							bit_counter <= bit_counter + 1;
								tick_cnt <= nBAUD + 4;
						end else begin
								bit_counter <= 0;
							if (shift_reg == SYNC_BYTE) begin 	// SYNC pattern is Ok
								tick_cnt <= nBAUD - 4;			// 4 is Sync delay
								state <= SYNC_STOP;
							end else begin
								err <= '1;
								state <= IDLE;
							end
						end
					end else begin
						if (tick_cnt)
							tick_cnt <= tick_cnt - 1'b1;		
						else begin								// BIT too long
							err <= '1;
							state <= IDLE;						
						end
					end
				end
				
				
				SYNC_STOP:begin
					if(bit_val) begin
						if (tick_cnt)								// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
					end else begin
						if (tick_cnt) begin							// STOP too short
							err <= '1;
							state <= IDLE;
						end else begin								// STOP Ok
							tick_cnt <= nBAUD/2 - 4;
							bit_counter <= '0;
							state <= PID;					
						end
					end
				end
				
				
				PID: begin
					if (sync) begin
						sync <= '0;
						if (bit_counter < 9) begin
							shift_reg <= {bit_val, shift_reg[7:1]};
							bit_counter <= bit_counter + 1;
							tick_cnt <= tick_cnt - 1'b1;
						end  else begin
							tick_cnt <= tick_cnt - 1'b1;
							bit_counter <= bit_counter + 1;
							byte_counter <= 0;					
							if (shift_reg[7:6] == {~(shift_reg[1] ^ shift_reg[3] ^ shift_reg[4] ^ shift_reg[5]), shift_reg[0] ^ shift_reg[1] ^ shift_reg[2] ^ shift_reg[4]}) begin // PID is Ok
								pid <= shift_reg[5:0];
								crc_ff <= shift_reg;
								classic_crc_ff <= '0;							
								tick_cnt <= nBAUD + nBAUD/2 + 4;
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
							tick_cnt <= nBAUD - 1;						
						end
					end
				end
				
				
				PID_STOP:begin
					if(bit_val) begin
						if (tick_cnt)								// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
						else begin									// “STOP” is too long; it's a request frame.
							req <= '1;								// Request tick
							state <= IDLE;							
						end
					end else begin
						if (tick_cnt > nBAUD - 4) begin			// STOP too short
							err <= '1;
							state <= IDLE;
						end else begin								// STOP Ok
							tick_cnt <= nBAUD/2 - 4;
							bit_counter <= '0;
							data_valid <= 1'b0;
							state <= DATA;					
						end
					end
				end			
				

				BYTE_STOP:begin
					if(bit_val) begin
						if (tick_cnt)								// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
						else begin
							err <= '1;
							state <= IDLE;							// STOP too long	
						end
					end else begin
						if (tick_cnt > nBAUD - 4) begin				// STOP too short
							err <= '1;
							state <= IDLE;
						end else begin								// STOP Ok
							tick_cnt <= nBAUD/2 - 4;
							bit_counter <= '0;
							data_valid <= 1'b0;
							state <= DATA;					
						end
					end
				end			


				DATA: begin
					if (sync) begin
						sync <= '0;
						if (bit_counter < 9) begin
							bit_counter <= bit_counter + 1;
							shift_reg <= {bit_val, shift_reg[7:1]};
							tick_cnt <= tick_cnt - 1'b1;
						end else begin
							bit_counter <= bit_counter + 1;
							data_buffer[byte_counter*8 +: 8] <= shift_reg;
							crc_ff <= crc(crc_ff,shift_reg);
							classic_crc_ff <= crc(classic_crc_ff,shift_reg);
							tick_cnt <= nBAUD + nBAUD/2 + 4;
							if (byte_counter < 7) begin
								state <= BYTE_STOP;
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
							tick_cnt <= nBAUD - 1;
						end
					end
				end
				
				
				DATA_STOP:begin
					if(bit_val) begin
						if (tick_cnt)								// STOP continued
							tick_cnt <= tick_cnt - 1'b1;
						else begin
							err <= '1;
							state <= IDLE;							// STOP too long	
						end
					end else begin
						if (tick_cnt  > nBAUD - 4) begin			// STOP too short
							err <= '1;
							state <= IDLE;
						end else begin								// STOP Ok
							tick_cnt <= nBAUD/2 - 4;
							bit_counter <= '0;
							state <= CRC;					
						end
					end
				end						
			

				CRC: begin
					if (sync) begin
						sync <= '0;
						if (bit_counter < 9) begin
							shift_reg <= {bit_val, shift_reg[7:1]};
							bit_counter <= bit_counter + 1;
							tick_cnt <= tick_cnt - 1'b1;
						end else begin
							data_out <= data_buffer;
							tick_cnt <= nBAUD/2 - 4;
							if (crc(crc_ff,shift_reg) == CRC_OK) begin				// ==FF
									classic <= '0;
									data_valid <= 1'b1;
							end else if (crc(classic_crc_ff,shift_reg) == CRC_OK) begin
									classic <= '1;
									data_valid <= 1'b1;
							end else
								err <= '1;
							state <= CRC_STOP;
						end
					end else begin
						if (tick_cnt)
							tick_cnt <= tick_cnt - 1'b1;
						else begin
							sync <= '1;
							tick_cnt <= nBAUD - 1;
						end
					end
				end
				
				CRC_STOP:begin
					if (tick_cnt) begin								// STOP continued
						if(bit_val)
							tick_cnt <= tick_cnt - 1'b1;
						else begin									// STOP too short		
							err <= '1;
							state <= IDLE;
						end 
					end else begin									// STOP Ok
						state <= IDLE;
					end
				end				
				
			endcase
		end
	end

	wire s_info;
	sinfo #( 
		.GROUPS	(8),
		.WORDS 	(2),
		.WIDTH 	(4)
	)sinfo0(
		.clk (clk),
//		.d   ({state,1'b0, tick_cnt, 6'b000000, bit_counter, data_out[39:0]}),
		.d   (data_out),
		.q   (s_info)
	);
	
	assign busy = (state != IDLE);
	
	assign test[4] = sync;								//44
	assign test[3] = err;								//43
	assign test[2] = busy;								//41
	assign test[1] = classic;							//39
	assign test[0] = s_info;							//38
	
	
endmodule