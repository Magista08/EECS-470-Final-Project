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
    output logic   [`XLEN-1:0]      proc2Imem_addr, // address sent to Instruction memory 
	output logic   [2:0] [`XLEN-1:0]      PC_reg,
	output logic   [2:0] [`XLEN-1:0]      NPC_reg
);
	logic         if_valid;

	assign if_valid = ~insn_buffer_stall;
	
	always_comb begin
		if(reset) begin
			NPC_reg    = 0;
		end else if(take_branch) begin
			NPC_reg[0] = target_pc;
			NPC_reg[1] = target_pc; //+ 4;
			NPC_reg[2] = target_pc; //+ 8;
		end else if(squash_flag) begin
			NPC_reg[0] = squash_pc;
			NPC_reg[1] = squash_pc; //+ 4;
			NPC_reg[2] = squash_pc; //+ 8;
	    end else begin
			NPC_reg[0] = PC_reg[0] + 4; // shoule be PC_reg[2] milestone 2
			NPC_reg[1] = PC_reg[1] + 4; //+ 8; // shoule be PC_reg[2] milestone 2   /// ?
			NPC_reg[2] = PC_reg[2] + 4; //+ 12; // shoule be PC_reg[2] milestone    /// ?
		end
	end


	/*always_comb begin
		for(integer j=0; j<=2; j++) begin
			proc2Imem_addr[j] = {PC_reg[j][`XLEN-1:3], 3'b0};
		end
	end*/
	assign proc2Imem_addr = {PC_reg[0][`XLEN-1:3], 3'b0};

	always_comb begin
		if(reset) begin
			for (integer j=0;j<=2;j++) begin
				if_dp_packet_out[j].inst = `NOP;
				if_dp_packet_out[j].NPC  = 0;
				if_dp_packet_out[j].PC   = 0;
				if_dp_packet_out[j].valid= 0;			
			end
		end else begin
			if_dp_packet_out[0].inst  = (~if_valid || (PC_reg[0][2] && Imem2proc_data[63:32] == 32'h0000_0000) || (~PC_reg[0][2] && Imem2proc_data[31:0] == 32'h0000_0000) || Imem2proc_data === 64'hxxxx_xxxx_xxxx_xxxx) ? `NOP :
										PC_reg[0][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
			if_dp_packet_out[0].PC    = PC_reg[0];
			if_dp_packet_out[0].NPC   = PC_reg[0] + 4;
			if_dp_packet_out[0].valid = ~(~if_valid || Imem2proc_data === 64'hxxxx_xxxx_xxxx_xxxx || (PC_reg[0][2] && Imem2proc_data[63:32] == `NOP) || (~PC_reg[0][2] && Imem2proc_data[31:0] == `NOP) || (PC_reg[0][2] && Imem2proc_data[63:32] == 32'h0000_0000) || (~PC_reg[0][2] && Imem2proc_data[31:0] == 32'h0000_0000));

			if_dp_packet_out[1].inst  = (~if_valid || Imem2proc_data === 64'hxxxx_xxxx_xxxx_xxxx) ? `NOP :
										PC_reg[1][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
			if_dp_packet_out[1].PC    = PC_reg[1];
			if_dp_packet_out[1].NPC   = PC_reg[1] + 4;
			if_dp_packet_out[1].valid = 0; //if_valid
	
			if_dp_packet_out[2].inst  = (~if_valid || Imem2proc_data === 64'hxxxx_xxxx_xxxx_xxxx) ? `NOP :
										PC_reg[2][2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];	
			if_dp_packet_out[2].PC    = PC_reg[2];
			if_dp_packet_out[2].NPC   = PC_reg[2] + 4;
			if_dp_packet_out[2].valid = 0;
		end
	end




    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
			for(integer i=0; i<=2; i++) begin
            	PC_reg[i]  <= 0*4; //i*4
			end          
        end else if (if_valid || take_branch || squash_flag) begin
            PC_reg <= NPC_reg;
        end
		$display("if_valid = %h", if_valid);
    end


endmodule
