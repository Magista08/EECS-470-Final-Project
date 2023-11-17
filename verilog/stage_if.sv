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
    input             clock,          // system clock
    input             reset,          // system reset
    input             take_branch,    // taken-branch signal
	input 			  squash_flag,    // squash? from retire
    input [`XLEN-1:0] target_pc,          // target pc: use if take_branch is TRUE
    input [63:0]      Imem2proc_data , // data coming back from Instruction memory
	input             insn_buffer_stall, // sss
	input [`XLEN-1:0] squash_pc,

    output IF_ID_PACKET     [2:0]         if_dp_packet_out,
    output logic   [2:0] [`XLEN-1:0]      proc2Imem_addr // address sent to Instruction memory 
);
	logic   [2:0] [`XLEN-1:0] PC_reg;
    logic   [2:0] [`XLEN-1:0] NPC_reg; // PC we are currently fetching
	logic         if_valid;

	assign if_valid = ~insn_buffer_stall;
	
	always_comb begin
		//$display("\nin stage if\n");
		if(take_branch) begin
			NPC_reg[0] = target_pc;
			NPC_reg[1] = target_pc; //+ 4;
			NPC_reg[2] = target_pc; //+ 8;
		end else if(squash_flag) begin
			NPC_reg[0] = squash_pc;
			NPC_reg[1] = squash_pc; //+ 4;
			NPC_reg[2] = squash_pc; //+ 8;
		end else begin
			NPC_reg[0] = PC_reg[0] + 4; // shoule be PC_reg[2] milestone 2
			NPC_reg[1] = PC_reg[0] + 4; //+ 8; // shoule be PC_reg[2] milestone 2
			NPC_reg[2] = PC_reg[0] + 4; //+ 12; // shoule be PC_reg[2] milestone 2
		end
	end


	/*always_comb begin
		for(integer j=0; j<=2; j++) begin
			proc2Imem_addr[j] = {PC_reg[j][`XLEN-1:3], 3'b0};
		end
	end*/
	assign proc2Imem_addr = {PC_reg[0][`XLEN-1:3], 3'b0};

	always_comb begin
		//$display("\nif npc:%h\n",if_dp_packet_out[0].NPC);
		if_dp_packet_out[0].inst  = (~if_valid) ? `NOP :
                                    PC_reg[0][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
		if_dp_packet_out[0].PC    = PC_reg;
		if_dp_packet_out[0].NPC   = NPC_reg;
		if_dp_packet_out[0].valid = if_valid;

		if_dp_packet_out[1].inst  = (~if_valid) ? `NOP :
                                    PC_reg[1][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
		if_dp_packet_out[1].PC    = PC_reg[1];
		if_dp_packet_out[1].NPC   = NPC_reg[1];
		if_dp_packet_out[1].valid = 0; //if_valid
 
		if_dp_packet_out[2].inst  = (~if_valid) ? `NOP :
                                    PC_reg[2][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
		if_dp_packet_out[2].PC    = PC_reg[2];
		if_dp_packet_out[2].NPC   = NPC_reg[2];
		if_dp_packet_out[2].valid = 0;
	end




    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
			for(integer i=0; i<=2; i++) begin
            	PC_reg[i] <= 0*4; //i*4
			end          
        end else if (if_valid || take_branch || squash_flag) begin
            PC_reg <= NPC_reg;
        end
    end


endmodule

