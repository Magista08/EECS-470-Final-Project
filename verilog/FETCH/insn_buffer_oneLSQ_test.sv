`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module testbench;

IF_ID_PACKET [2:0] if_packet, if_reg;
IF_ID_PACKET [2:0] ib_packet, ib_packet_check;
logic [1:0] ROB_blank_number, ROB_reg, RS_blank_number, RS_reg;
logic insn_buffer_full;
logic [5-1:0] wptr_dbg, rptr_dbg;
// logic sq_complete;

// Call Module
insn_buffer ib1(
	.clock(clock), 
    .reset(reset), 
    .enable(),
	.squash_flag(1'b0),

	.if_packet_in(if_reg),
	.ROB_blank_number(ROB_reg), // blank number in ROB
	.RS_blank_number(RS_reg), // blank number in reservation station

	.insn_buffer_full(insn_buffer_full),
	.ib_dp_packet_out(ib_packet_check),
	.wptr(wptr_dbg),
	.rptr(rptr_dbg)
);

always_ff @(posedge clock) begin
    if_reg  <= if_packet;
    ROB_reg <= ROB_blank_number;
    RS_reg  <= RS_blank_number;
end

always begin
    #10 clock = ~clock;
end

initial begin
    $monitor("clock:%b insn_buffer_full: %b, ib_packet_check[0].inst: %h, ib_packet_check[0].valid: %h, ib_packet_check[0].PC: %h\n\
clock:%b insn_buffer_full: %b, ib_packet_check[1].inst: %h, ib_packet_check[1].valid: %h, ib_packet_check[1].PC: %h\n\
clock:%b insn_buffer_full: %b, ib_packet_check[2].inst: %h, ib_packet_check[2].valid: %h, ib_packet_check[2].PC: %h" 
	clock, insn_buffer_full, ib_packet_check[0].inst, ib_packet_check[0].valid, ib_packet_check[0].PC,
	clock, insn_buffer_full, ib_packet_check[1].inst, ib_packet_check[1].valid, ib_packet_check[1].PC,
	clock, insn_buffer_full, ib_packet_check[2].inst, ib_packet_check[2].valid, ib_packet_check[2].PC);

	reset = 1'b1;
	clock = 1'b0;
	ROB_blank_number = 2'b11;
	RS_blank_number = 2'b11;
	// sq_complete = 0;

	$display("-----------------------------------------RESETTING-----------------------------------------");
	#20;

	reset = 1'b0;
	if_packet[0].inst = `RV32_SB;
	if_packet[0].valid = 1'b1;
	if_packet[0].PC = 32'h00000000;
	if_packet[0].NPC = 32'h00000004;

	if_packet[1].inst = `RV32_LB;
	if_packet[1].valid = 1'b1;
	if_packet[1].PC = 32'h00000004;
	if_packet[1].NPC = 32'h00000008;

	if_packet[1].inst = `RV32_ADD;
	if_packet[1].valid = 1'b1;
	if_packet[1].PC = 32'h00000008;
	if_packet[1].NPC = 32'h0000000c;
	$display("-----------------------------------------TEST1: LB+SB+ADD-----------------------------------------");
	#20;
	#20;
	#20;

	// sq_complete = 1;
	// sq_complete = 0;
end

endmodule