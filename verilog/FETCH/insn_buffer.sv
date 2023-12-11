`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module insn_buffer(
	input clock, reset, enable,
	input squash_flag,
	input IF_ID_PACKET [2:0] if_packet_in,
	input [1:0] ROB_blank_number, // blank number in ROB
	input [1:0] RS_blank_number, // blank number in reservation station
	input       SQ_full,


	output logic insn_buffer_full,
	output IF_ID_PACKET [2:0] ib_dp_packet_out,
	output logic [5-1:0] wptr,
	output logic [5-1:0] rptr

);

parameter BUFFER_DEPTH = 16;
parameter PTR_DEPTH = $clog2(BUFFER_DEPTH) + 1;
logic buffer_empty;
logic [1:0] dp_packet_count;
logic [1:0] m, n;
logic [PTR_DEPTH-1:0] n_wptr, wptr1, wptr2;
logic [PTR_DEPTH-1:0] n_rptr, rptr1, rptr2;
logic [1:0] if_packet_size;
logic [4:0] ready_insn_size;
IF_ID_PACKET [BUFFER_DEPTH-1:0] slot;
IF_ID_PACKET [BUFFER_DEPTH-1:0] n_slot;

assign insn_buffer_empty = (wptr == rptr);
//
assign insn_buffer_full = (ready_insn_size > BUFFER_DEPTH-3 || ready_insn_size == BUFFER_DEPTH-3);
// find the size of the if_packt
assign if_packet_size = n_wptr - wptr;
// find how many insns in the buffer are ready
assign ready_insn_size = (rptr > wptr)? 5'b11111-rptr+wptr+1 : wptr - rptr;
// how many packet can i send to dispatch
assign m = SQ_full? 0 : (ready_insn_size <= ROB_blank_number)? ready_insn_size : ROB_blank_number;
assign n = SQ_full? 0 : (ready_insn_size <= RS_blank_number)? ready_insn_size : RS_blank_number;
assign dp_packet_count = SQ_full? 0 : (m<=n) ? m : n;



assign wptr1 = wptr + 1;
assign wptr2 = wptr + 2;
assign rptr1 = rptr + 1;
assign rptr2 = rptr + 2;

// find the next write pointer
always_comb begin
	n_wptr = wptr;
	for(integer i=0; i<=2; i++) begin
		if(if_packet_in[i].valid == 1) begin
			n_wptr = wptr + i + 1;

		end
	end
end

// Write the buffer
always_comb begin
	if(reset || squash_flag) begin
		n_slot = 0;
	end else begin 
		case(if_packet_size)

			2'b01: begin
				n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
			end
			2'b10: begin
				n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
				n_slot[wptr1[PTR_DEPTH-2:0]]  = if_packet_in[1];
			end
			2'b11: begin
				n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
				n_slot[wptr1[PTR_DEPTH-2:0]]  = if_packet_in[1];
				n_slot[wptr2[PTR_DEPTH-2:0]]  = if_packet_in[2];
			end
			default: begin
				n_slot = slot;
			end
		endcase
	end
end


always_comb begin
	if(dp_packet_count == 2'b01) begin
		n_rptr = rptr + 1;
	end else if(dp_packet_count == 2'b10) begin
		n_rptr = rptr + 2;
	end else if(dp_packet_count == 2'b11) begin
		n_rptr = rptr + 3;
	end else begin
		n_rptr = rptr;
	end
end


always_comb begin
	if(reset || dp_packet_count == 2'b00 || SQ_full) begin
		ib_dp_packet_out[0].inst  =  `NOP;
		ib_dp_packet_out[0].PC    =  0;
		ib_dp_packet_out[0].NPC   =  0;
		ib_dp_packet_out[0].valid =  0;
		
		ib_dp_packet_out[1].inst  =  `NOP;
		ib_dp_packet_out[1].PC    =  0;
		ib_dp_packet_out[1].NPC   =  0;
		ib_dp_packet_out[1].valid =  0;
		
		ib_dp_packet_out[2].inst  =  `NOP;
		ib_dp_packet_out[2].PC    =  0;
		ib_dp_packet_out[2].NPC   =  0;
		ib_dp_packet_out[2].valid =  0;
	end else if(dp_packet_count == 2'b01) begin
		ib_dp_packet_out[0]       =  slot[rptr[PTR_DEPTH-2:0]];
		
		ib_dp_packet_out[1].inst  =  `NOP;
		ib_dp_packet_out[1].PC    =  0;
		ib_dp_packet_out[1].NPC   =  0;
		ib_dp_packet_out[1].valid =  0;
	
		ib_dp_packet_out[2].inst  =  `NOP;
		ib_dp_packet_out[2].PC    =  0;
		ib_dp_packet_out[2].NPC   =  0;
		ib_dp_packet_out[2].valid =  0;
	
	end else if(dp_packet_count == 2'b10) begin
		ib_dp_packet_out[0]       =  slot[rptr[PTR_DEPTH-2:0]];
		ib_dp_packet_out[1]       =  slot[rptr1[PTR_DEPTH-2:0]];
		
		ib_dp_packet_out[2].inst  =  `NOP;
		ib_dp_packet_out[2].PC    =  0;
		ib_dp_packet_out[2].NPC   =  0;
		ib_dp_packet_out[2].valid =  0;
	end else if(dp_packet_count == 2'b11) begin
		ib_dp_packet_out[0]       =  slot[rptr[PTR_DEPTH-2:0]];
		ib_dp_packet_out[1]       =  slot[rptr1[PTR_DEPTH-2:0]];
		ib_dp_packet_out[2]       =  slot[rptr2[PTR_DEPTH-2:0]];
	end else begin
		ib_dp_packet_out[0].inst  =  `NOP;
		ib_dp_packet_out[0].PC    =  0;
		ib_dp_packet_out[0].NPC   =  0;
		ib_dp_packet_out[0].valid =  0;
		
		ib_dp_packet_out[1].inst  =  `NOP;
		ib_dp_packet_out[1].PC    =  0;
		ib_dp_packet_out[1].NPC   =  0;
		ib_dp_packet_out[1].valid =  0;
		
		ib_dp_packet_out[2].inst  =  `NOP;
		ib_dp_packet_out[2].PC    =  0;
		ib_dp_packet_out[2].NPC   =  0;
		ib_dp_packet_out[2].valid =  0;
	end 
	
end


always_ff @(posedge clock) begin
	if(reset || squash_flag) begin
		wptr <= 0;
		rptr <= 0;
		for(integer j=0; j<=BUFFER_DEPTH; j++) begin
			slot[j].inst <= `NOP;
			slot[j].PC   <= 0;
			slot[j].NPC  <= 0;
			slot[j].valid<= 0;
		end
	end else if (enable) begin
		if(!insn_buffer_full) begin 
			wptr <=  n_wptr;
			slot <=  n_slot;
		end 
		if (!insn_buffer_empty) begin
			rptr <=  n_rptr;
		end
	end
	 $display("wptr = %d, rptr = %d", wptr, rptr);
	 $display("dp_packet_count = %d", dp_packet_count);
end

endmodule





