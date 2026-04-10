
module lin_tx #(
	parameter
		CLK_FREQ,
		BAUD_RATE
	)(
    input  
		clk        	   , //system clock
		rst            , //reset
		master		   ,
		classic		   ,
		start          , //start
	input [5:0]	pid    , //id or address
	input  [63:0] data , //
    output reg
		sdo			   , //serial data out
		busy		   
    );
	
	localparam int
		nBAUD	     = CLK_FREQ/BAUD_RATE,
		wBAUD		 = $clog2(nBAUD)
	;
	
	reg [wBAUD-1:0] bit_time = '0; 		// nBAUD
	
	wire sync;
	assign sync = !bit_time;
	
	always_ff @ (posedge clk) begin
		if (start)
			bit_time <= nBAUD - 1;
		else if (bit_time)
			bit_time <= bit_time - 1'b1;
		else
			bit_time <= nBAUD - 1;
	end
	
//	reg [1:0]parity = '0;

    logic [7:0] pid_adrs_reg   ;//PID
    logic [3:0] bit_count, byte_count      ;//
	logic [63:0] data_reg;

    //states declaration
    typedef enum reg [2:0]{IDLE, SYNC_BREAK, SYNC_FIELD, PID, DATA, CHECKSUM} state_type_e;

    state_type_e state = IDLE;
	
	//CRC instantiation
	reg  [7:0] crc_ff = '0;	
	function automatic [7:0] crc (input [7:0] a, b);
		reg [8:0] tcrc;
		begin
			tcrc = a + b;
			return tcrc[7:0] + tcrc[8];
		end
	endfunction
 	
	
	

    //FSM 
    always_ff @ (posedge clk  or posedge rst) begin
        if (rst) begin
            sdo <= 1;
			byte_count <= '0;
            bit_count <= 0;
            pid_adrs_reg <= 0;
			data_reg <= '0;
			crc_ff <= '0;
            state <= IDLE;
        end else begin
            case(state)
			
            default: begin
				byte_count <= '0;
                bit_count <= 0;
                if (start) begin
					pid_adrs_reg <= {~(pid[1] ^ pid[3] ^ pid[4] ^ pid[5]), pid[0] ^ pid[1] ^ pid[2] ^ pid[4], pid};
					data_reg <= data;					
					if (master) begin
						crc_ff <= '0;
						sdo <= 1'b0;
						state <= SYNC_BREAK;
					end else begin
						crc_ff <= classic ? data[7:0] : crc(data[7:0],{~(pid[1] ^ pid[3] ^ pid[4] ^ pid[5]), pid[0] ^ pid[1] ^ pid[2] ^ pid[4], pid});
						sdo <= 1'b1;
						state <= DATA;
					end
                end else begin
//					crc_ff <= {~(pid[1] ^ pid[3] ^ pid[4] ^ pid[5]), pid[0] ^ pid[1] ^ pid[2] ^ pid[4], pid};
					sdo <= 1'b1;
				end
            end
			
            SYNC_BREAK: if (sync) begin
                if (bit_count < 13) begin
                    sdo <= 0;//sync break
                    bit_count <= bit_count + 1;
                end else begin
                    sdo <= 1;//delimeter
                    bit_count <= 0;
                    state <= SYNC_FIELD;
                end
            end
			
            SYNC_FIELD: if (sync) begin
				if (bit_count < 9) begin
					bit_count <= bit_count + 1;
					if (bit_count) begin
						sdo <= ~sdo;			//haa SYNC FELD
					end else
						sdo <= 0;//start bit
				end	else begin
                    sdo <= 1;//stop bit
                    bit_count <= 0;
					if (!classic)
						crc_ff <= pid_adrs_reg;
                    state <= PID;
                end
            end
			
            PID: if (sync) begin
                if (bit_count < 9) begin
					bit_count <= bit_count + 1;
					if (bit_count) begin
						pid_adrs_reg <= {1'b0, pid_adrs_reg[7:1]};
						sdo <= pid_adrs_reg[0];
					end  else													// STOP end
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
					byte_count <= '0;
					crc_ff <= crc(crc_ff,data_reg[7:0]);
                    state <= DATA;
                end
            end
			
			
			DATA: if (sync) begin
				if (bit_count < 10) begin
					bit_count <= bit_count + 1;	
					if (bit_count > 1) begin
						data_reg <= {1'b0, data_reg[63:1]};
						sdo <= data_reg[0];
					end else if (bit_count)										// 2STOP end
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;	 // stop bit
					bit_count <= '0;
					crc_ff <= crc(crc_ff,data_reg[7:0]);
					if (byte_count < 7) begin
						byte_count <= byte_count + 1;
					end else begin
						sdo <= 1; // stop bit
						bit_count <= 0;
						state <= CHECKSUM;
					end
				end
            end
			
			CHECKSUM: if (sync) begin
                if (bit_count < 10) begin
					bit_count <= bit_count + 1;
					if (bit_count > 1)begin
						sdo <= ~crc_ff[bit_count-2];
					end else if(bit_count)
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
                    state <= IDLE;
				end
            end
			
            endcase
        end
    end
	
	reg [7:0]busy_delay = '0;
	always_ff @ (posedge clk) busy_delay <= {busy_delay[6:0],start | (state != IDLE)};
		
    assign busy = start | |busy_delay;	//transmitter busy

endmodule