/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  stage_if.sv                                         //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       //
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"
module stage_if (
    input                  clock,          // system clock
    input                  reset,          // system reset
	input 			       squash_flag,    // squash? from retire
    input [`XLEN-1:0]      squash_pc,
    input [`XLEN-1:0]      bp_npc,         // branch prediction next PC
    input ICACHE_IF_PACKET [2:0] Icache_if_packet_in, // data coming back from Instruction memory
	input                  insn_buffer_stall, // sss
	
    output         IF_ID_PACKET [2:0]     if_dp_packet_out,
	output logic [2:0]  [`XLEN-1:0]      PC_reg
	
);
	logic if_valid0, if_valid1, if_valid2, if_valid;
	logic   [2:0] [`XLEN-1:0]      NPC_reg;        
	assign if_valid  = ~insn_buffer_stall && Icache_if_packet_in[0].valid && Icache_if_packet_in[1].valid; // && Icache_if_packet_in[2].valid;
	assign if_valid0 = ~insn_buffer_stall && Icache_if_packet_in[0].valid;
	assign if_valid1 = ~insn_buffer_stall && Icache_if_packet_in[1].valid;
	assign if_valid2 = ~insn_buffer_stall && Icache_if_packet_in[2].valid;

	// always_comb begin
	// 	if(squash_flag) begin
	// 		PC_reg[0] = squash_pc;
	// 		PC_reg[1] = squash_pc + 4; //+ 4;
	// 		PC_reg[2] = 0; //+ 8;
	// 	end else begin
	// 		PC_reg[0] = bp_npc; // shoule be PC_reg[2] milestone 2
	// 		PC_reg[1] = bp_npc + 4; //+ 8; // shoule be PC_reg[2] milestone 2   /// ?
	// 		PC_reg[2] = 0; //+ 12; // shoule be PC_reg[2] milestone    /// ?
	// 	end
	// end

	genvar pc_i;
	generate
		for (pc_i=0; pc_i<`N; pc_i++) begin
			assign PC_reg[pc_i] = bp_npc + 4*pc_i;
		end
	endgenerate

	always_comb begin

		NPC_reg[0] = PC_reg[0]+4;
		NPC_reg[1] = PC_reg[1]+4;
		NPC_reg[2] = 0;

	end

	/*always_comb begin
		for(integer j=0; j<=2; j++) begin
			proc2Imem_addr[j] = {PC_reg[j][`XLEN-1:3], 3'b0};
		end
	end*/
	//assign proc2Imem_addr = {PC_reg[0][`XLEN-1:3], 3'b0};

	always_comb begin
		if(reset) begin
			for (integer j=0;j<=2;j++) begin
				if_dp_packet_out[j].inst = `NOP;
				
				if_dp_packet_out[j].NPC  = 0;
				if_dp_packet_out[j].PC   = 0;
				if_dp_packet_out[j].valid= 0;			
			end
		end else begin
			if_dp_packet_out[0].inst      = (~if_valid || Icache_if_packet_in[0].inst == 0)? `NOP : Icache_if_packet_in[0].inst;	
			if_dp_packet_out[0].PC        = PC_reg[0];
			
			if_dp_packet_out[0].NPC       = NPC_reg[0];
			if_dp_packet_out[0].valid     = if_valid && Icache_if_packet_in[0].inst != 0;



			if_dp_packet_out[1].inst      = (~if_valid || Icache_if_packet_in[1].inst == 0) ? `NOP : Icache_if_packet_in[1].inst;	
			if_dp_packet_out[1].PC        = PC_reg[1];
			
			if_dp_packet_out[1].NPC       = NPC_reg[1];
			if_dp_packet_out[1].valid     = if_valid && Icache_if_packet_in[0].inst != 0;



			if_dp_packet_out[2].inst      = (~if_valid) ? `NOP : Icache_if_packet_in[2].inst;	
			if_dp_packet_out[2].PC        = PC_reg[2];
			
			if_dp_packet_out[2].NPC       = 0;
			if_dp_packet_out[2].valid     = 0;
		end
		// $display("if_dp_packet_out[0].inst: %h, if_dp_packet_out[0].valid:%b, if_dp_packet_out[0].PC:%h, if_dp_packet_out[0].NPC: %h", 
		// 		  if_dp_packet_out[0].inst,     if_dp_packet_out[0].valid,    if_dp_packet_out[0].PC,    if_dp_packet_out[0].NPC);
		// $display("if_dp_packet_out[1].inst: %h, if_dp_packet_out[1].valid:%b, if_dp_packet_out[1].PC:%h, if_dp_packet_out[1].NPC: %h", 
		// 		  if_dp_packet_out[1].inst,     if_dp_packet_out[1].valid,    if_dp_packet_out[1].PC,    if_dp_packet_out[1].NPC);
		// $display("if_dp_packet_out[2].inst: %h, if_dp_packet_out[2].valid:%b, if_dp_packet_out[2].PC:%h, if_dp_packet_out[2].NPC: %h", 
		// 		  if_dp_packet_out[2].inst,     if_dp_packet_out[0].valid,    if_dp_packet_out[2].PC,    if_dp_packet_out[2].NPC);
	end




    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
       /* if (reset) begin
        	PC_reg[0]  <= 0; //i*4
			PC_reg[1]  <= 4;  
			PC_reg[2]  <= 8;    
        end else if (if_valid || squash_flag) begin
            PC_reg <= #1 NPC_reg;
        end*/
		//$display("PC[2]:%h PC[1]:%h PC[0]:%h", PC_reg[2], PC_reg[1], PC_reg[0]);
		//$display("cache_valid[2]:%h cache_valid[1]:%h cache_valid[0]:%h", Icache_if_packet_in[2].valid, Icache_if_packet_in[1].valid, Icache_if_packet_in[0].valid);
    end


endmodule
