`timescale 1ns / 1ps


module lin_tx #(
	parameter
		CLK_FREQ,
		BAUD_RATE
	)(
    input  
		clk        	   , //system clock
		rst            , //reset
		master		   ,
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
	
	reg [1:0]parity = '0;

    logic [7:0] pid_adrs_reg   ;//PID
    logic [3:0] bit_count, byte_count      ;//
	logic [63:0] data_reg;

    //states declaration
    typedef enum {IDLE, SYNC_BREAK, SYNC_FIELD, PID, DATA, CHECKSUM} state_type_e;

    state_type_e state = IDLE;
	
	//CRC instantiation
 	reg [7:0] crc_out = '0;
	reg [8:0] crc = '0;
	
/* 	wire [7:0] checksum;
	reg [7:0]checksum_reg = '0;
    crcd64_o8 CRCD64_O8(
            .crc_in  (8'hFF ),
            .data_in (data),
            .crc_out (checksum)
            ); */

    //FSM to synchronize and send PID data to responder
    always_ff @ (posedge clk ) begin
        if (rst) begin
            sdo <= 0;
			byte_count <= '0;
            bit_count <= 0;
            pid_adrs_reg <= 0;
			data_reg <= '0;
			crc <= '0;
			crc_out <= '0;
            state <= IDLE;
        end else begin
            case(state)
			
            IDLE: begin
				byte_count <= '0;
                bit_count <= 0;
                pid_adrs_reg <= {~(pid[1] ^ pid[3] ^ pid[4] ^ pid[5]), pid[0] ^ pid[1] ^ pid[2] ^ pid[4], pid};
                if (start) begin
					if (master) begin
						sdo <= 1'b0;
						data_reg <= data;
						state <= SYNC_BREAK;
					end else begin
						sdo <= 1'b1;
						crc <= '0;
						data_reg <= data;
						state <= DATA;
					end
                end else
					sdo <= 1'b1;
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
					crc <= pid_adrs_reg;
                    state <= PID;
                end
            end
			
            PID: if (sync) begin
                if (bit_count < 9) begin
					bit_count <= bit_count + 1;
					if (bit_count) begin
						pid_adrs_reg <= {1'b0, pid_adrs_reg[7:1]};
						sdo <= pid_adrs_reg[0];
					end else
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
					byte_count <= '0;
					data_reg <= data;
					crc <= crc[7:0]  + crc[8] + data_reg[7:0];
                    state <= DATA;
                end
            end
			
			
			DATA: if (sync) begin
				if (bit_count < 9) begin
					bit_count <= bit_count + 1;	
					if (bit_count) begin
						data_reg <= {1'b0, data_reg[63:1]};
						sdo <= data_reg[0];
					end else
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;	 // stop bit
					bit_count <= '0;
					if (byte_count < 7) begin
						crc <= crc[7:0]  + crc[8] + data_reg[7:0];
						byte_count <= byte_count + 1;
					end else begin
						crc_out <= ~(crc[7:0]  + crc[8]);
						sdo <= 1; // stop bit
						bit_count <= 0;
						state <= CHECKSUM;
					end
				end
            end
			
			CHECKSUM: if (sync) begin
                if (bit_count < 9) begin
					bit_count <= bit_count + 1;
					if (bit_count)begin
						crc_out <= {1'b0, crc_out[7:1]};
						sdo <= crc_out[0];
					end else  
						sdo <= 0;//start bit
				end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
                    state <= IDLE;
				end
            end
			
            default: state <= IDLE;
            endcase
        end
    end

    assign busy = start || (state != IDLE);	//transmitter busy

endmodule
