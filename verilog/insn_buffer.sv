`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module insn_buffer(
	input clock, reset, enable,
	input squash_flag,
	input IF_ID_PACKET [2:0] if_packet_in,
	input [1:0] ROB_blank_number, // blank number in ROB
	input [1:0] RS_blank_number, // blank number in reservation station

	output logic insn_buffer_full,
	output IF_ID_PACKET [2:0] ib_dp_packet_out

);

parameter BUFFER_DEPTH = 16;
parameter PTR_DEPTH = $clog2(BUFFER_DEPTH) + 1;
logic buffer_empty;
logic [1:0] dp_packet_count;
logic [PTR_DEPTH-1:0] wptr, n_wptr;
logic [PTR_DEPTH-1:0] rptr, n_rptr;
logic [1:0] if_packet_size;
IF_ID_PACKET [BUFFER_DEPTH-1:0] slot;
IF_ID_PACKET [BUFFER_DEPTH-1:0] n_slot;

assign insn_buffer_empty = (wptr == rptr) || (wptr == rptr+1) || (wptr == rptr+2);
//
assign insn_buffer_full = (wptr == {~rptr[PTR_DEPTH-1], rptr[PTR_DEPTH-2:0]})   || 
						  (wptr+1 == {~rptr[PTR_DEPTH-1], rptr[PTR_DEPTH-2:0]}) || 
						  (wptr+2 == {~rptr[PTR_DEPTH-1], rptr[PTR_DEPTH-2:0]});
// how many packet can i send to dispatch
assign dp_packet_count = (ROB_blank_number <= RS_blank_number)? ROB_blank_number : RS_blank_number;
// find the size of the if_packt
assign if_packet_size = n_wptr - wptr;

// find the next write pointer
always_comb begin
	//$display("\nin insn buffer\n");
	n_wptr = wptr;
	
	for(integer i=0; i<=2; i++) begin
		if(if_packet_in[i].valid == 1) begin
			n_wptr = wptr + i + 1;
			
		end
	end
end


// Write the buffer
always_comb begin
	for(integer k=0; k<=BUFFER_DEPTH; k++) begin
		n_slot[k] = slot[k];
	end
	case(if_packet_size)

		2'b01: begin
			   n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
			   end
		2'b10: begin
			   n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
			   n_slot[wptr[PTR_DEPTH-2:0]+1] = if_packet_in[1];
			   end
		2'b11: begin
			   n_slot[wptr[PTR_DEPTH-2:0]]   = if_packet_in[0];
			   n_slot[wptr[PTR_DEPTH-2:0]+1] = if_packet_in[1];
			   n_slot[wptr[PTR_DEPTH-2:0]+2] = if_packet_in[2];
			   end
		default: begin
			     n_slot = slot;
				 end
	endcase
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

always_ff @(posedge clock) begin
	//$display("\ninsn buffer npc:%h\n",ib_dp_packet_out[0].NPC);
	if(reset || dp_packet_count == 2'b00) begin
		ib_dp_packet_out[0].inst  <=  `NOP;
		ib_dp_packet_out[0].PC    <=  0;
		ib_dp_packet_out[0].NPC   <=  0;
		ib_dp_packet_out[0].valid <=  0;
		
		ib_dp_packet_out[1].inst  <=  `NOP;
		ib_dp_packet_out[1].PC    <=  0;
		ib_dp_packet_out[1].NPC   <=  0;
		ib_dp_packet_out[1].valid <=  0;
		
		ib_dp_packet_out[2].inst  <=  `NOP;
		ib_dp_packet_out[2].PC    <=  0;
		ib_dp_packet_out[2].NPC   <=  0;
		ib_dp_packet_out[2].valid <=  0;
	end else if(dp_packet_count == 2'b01) begin
		ib_dp_packet_out[0]       <=  slot[rptr[PTR_DEPTH-2:0]];
		
		ib_dp_packet_out[1].inst  <=  `NOP;
		ib_dp_packet_out[1].PC    <=  0;
		ib_dp_packet_out[1].NPC   <=  0;
		ib_dp_packet_out[1].valid <=  0;
		
		ib_dp_packet_out[2].inst  <=  `NOP;
		ib_dp_packet_out[2].PC    <=  0;
		ib_dp_packet_out[2].NPC   <=  0;
		ib_dp_packet_out[2].valid <=  0;
		
	end else if(dp_packet_count == 2'b10) begin
		ib_dp_packet_out[0]       <=  slot[rptr[PTR_DEPTH-2:0]];
		ib_dp_packet_out[1]       <=  slot[rptr[PTR_DEPTH-2:0]+1];
		
		ib_dp_packet_out[2].inst  <=  `NOP;
		ib_dp_packet_out[2].PC    <=  0;
		ib_dp_packet_out[2].NPC   <=  0;
		ib_dp_packet_out[2].valid <=  0;
	end else if(dp_packet_count == 2'b11) begin
		ib_dp_packet_out[0]       <=  slot[rptr[PTR_DEPTH-2:0]];
		ib_dp_packet_out[1]       <=  slot[rptr[PTR_DEPTH-2:0]+1];
		ib_dp_packet_out[2]       <=  slot[rptr[PTR_DEPTH-2:0]+2];
	end
end


always_ff @(posedge clock) begin
	if(reset || squash_flag) begin
		wptr <= 0;
		rptr <= 0;
	end else if (enable) begin
		if(!insn_buffer_full) begin 
			wptr <= n_wptr;
			slot <= n_slot;
		end 
		if (!insn_buffer_empty) begin
			rptr <= n_rptr;
		end
	end
end

endmodule






