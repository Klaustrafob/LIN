`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Sudhee
//
// Create Date: 26.04.2023 17:57:41
// Design Name: LIN Commander Module
// Module Name: lin_comm
// Project Name: LIN Protocol
// Target Devices: Zynq 7020
// Tool Versions: Vivado
// Description: LIN Commander module to initiates the data communication using PID.
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module lin_comm(
    input  logic sys_clk        ,//system clock
    input  logic rstn           ,//reset
    input  logic start          ,//start commander
    input  logic [5:0] pid      ,//id or address
	input  logic [63:0] data	, //
 //   input  logic inter_tx_delay ,//inter transmission delay
 //   input  logic resp_busy      ,//responder busy
    output logic sdo       //serial data out
 //   output logic lin_busy       ,//commander busy
 //   output logic comm_tx_done   ,//tx complete from commander
//    output logic [33:0] frame_header_out //frame header
    );

 //  logic [3:0] break_count    ;//count for break field
 //   logic [3:0] sync_count     ;//count for sync field
    logic [7:0] pid_adrs_reg   ;//PID
    logic [3:0] bit_count, byte_count      ;//
//    logic [1:0] parity_count   ;//count for parity
//    logic parity0              ;//for parity
//    logic parity1              ;//for parity
//    logic [33:0] frame_header  ;//frame header reg
	logic [63:0] data_reg;

    //states declaration
    typedef enum {IDLE, SYNC_BREAK, SYNC_FIELD, PID, DATA, CHECKSUM} state_type_e;

    state_type_e state = IDLE;
	
	//CRC instantiation
	wire [7:0] checksum;
	reg [7:0]checksum_reg = '0;
    crcd64_o8 CRCD64_O8(
            .crc_in  (8'hFF ),
            .data_in (data),
            .crc_out (checksum)
            );

    //FSM to synchronize and send PID data to responder
    always_ff @ (posedge sys_clk or negedge rstn) begin
        if (!rstn) begin
            sdo <= 0;
 //           break_count <= 0;
 //           sync_count <= 0;
			byte_count <= '0;
            bit_count <= 0;
            pid_adrs_reg <= 0;
//            parity_count <= 0;
//            parity0 <= 0;
//            parity1 <= 0;
 //           comm_tx_done <= 0;
 //           frame_header <= 0;
			data_reg <= '0;
			checksum_reg <= '0;
            state <= IDLE;
        end else begin
            case(state)
            IDLE: begin
  //              break_count <= 0;
  //              sync_count <= 0;
				byte_count <= '0;
                bit_count <= 0;
  //              frame_header <= 0;
				data_reg <= '0;
  //              parity_count <= 0;
 //               parity0 <= 0;
  //             parity1 <= 0;
                sdo <= 0;
  //              comm_tx_done <= 0;
                pid_adrs_reg <= {pid[1] ^ pid[3] ^ pid[4] ^ pid[5], pid[0] ^ pid[1] ^ pid[2] ^ pid[4], pid};
 //               if (start && !inter_tx_delay && !resp_busy) begin
				if (start) begin
                    state <= SYNC_BREAK;
                end else begin
                    state <= IDLE;
                end
            end
			
            SYNC_BREAK: begin
 //               frame_header <= {frame_header[33:0], sdo};
                if (bit_count < 13) begin
                    sdo <= 0;//sync break
                    bit_count <= bit_count + 1;
                    state <= SYNC_BREAK;
                end else begin
                    sdo <= 1;//delimeter
                    bit_count <= 0;
                    state <= SYNC_FIELD;
                end
            end
			
            SYNC_FIELD: begin
 //               frame_header <= {frame_header[33:0], sdo};
                bit_count <= bit_count + 1;
                if (bit_count < 1) begin
                    sdo <= 0;//start bit
                    state <= SYNC_FIELD;
                end else if (bit_count < 9) begin
                    sdo <= ~sdo;
                    state <= SYNC_FIELD;
                end else begin
                    sdo <= 1;//stop bit
                    bit_count <= 0;
                    state <= PID;
                end
            end
			
            PID: begin
 //               frame_header <= {frame_header[33:0], sdo};
                
                if (bit_count < 1) begin
					bit_count <= bit_count + 1;
                    sdo <= 0;//start bit
                end else if (bit_count < 9) begin
					bit_count <= bit_count + 1;
                    pid_adrs_reg <= {1'b0, pid_adrs_reg[7:1]};
                    sdo <= pid_adrs_reg[0];
                end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
					data_reg <= data;
					checksum_reg <= checksum;
                    state <= DATA;
                end
            end
			
			
			DATA: begin
//                response_out <= {response_out[88:0], sdo};
				if (bit_count < 1) begin
					bit_count <= bit_count + 1;	
					sdo <= 0;//start bit
				end else if (bit_count < 9) begin
					data_reg <= {1'b0, data_reg[63:1]};
					sdo <= data_reg[0];
					bit_count <= bit_count + 1;
				end else if (byte_count < 7) begin
					sdo <= 1;	// stop bit
					byte_count <= byte_count + 1;
					bit_count <= 0;
				end else begin
					sdo <= 1; // stop bit
					bit_count <= 0;
					state <= CHECKSUM;
				end
            end
			
			CHECKSUM: begin
//                response_out <= {response_out[88:0], sdo};
                if (bit_count < 1) begin
					bit_count <= bit_count + 1;
                    sdo <= 0;//start bit
                end else if (bit_count < 9) begin
					bit_count <= bit_count + 1;
                    checksum_reg <= {1'b0, checksum_reg[7:1]};
                    sdo <= checksum_reg[0];
                end else begin
					sdo <= 1;//stop bit
					bit_count <= 0;
                    state <= IDLE;
				end
            end
						
 /*            WAIT: begin
                if (resp_busy) begin
                    state <= WAIT;//wait till responder finishes tx
                end else begin
                    state <= IDLE;
                end
            end */
            default: state <= IDLE;
            endcase
        end
    end

   // assign lin_busy = state >= SYNC_BREAK && state <= STOP;//commander busy
   // assign frame_header_out = comm_tx_done ? frame_header : 0;//frame header

endmodule
