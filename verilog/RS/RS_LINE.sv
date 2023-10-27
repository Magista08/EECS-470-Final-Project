/*
	我们决定将superscalar的way number改为packet外，所以sys_defs中
	打包的【2:0】都去掉
*/
`include "verilog/sys_defs.svh"

module RS_LINE (
    input             		clock, reset, enable,
    input 	 				clear,             // whether clear the RS_line
    input  					squash_flag,
    input                  [$clog2(`ROBLEN)-1:0]line_id,
    input					sel,
    input DP_IS_PACKET 		dp_packet,
    input MT_RS_PACKET  	mt_packet,
    input ROB_RS_PACKET		rob_packet,
    input CDB_RS_PACKET		cdb_packet,

	output logic  			not_ready,
    output RS_LINE  		rs_line
);
    RS_LINE  				n_rs_line;
	RS_LIN                  nn_rs_line;    // to remain n_rs_line unchanged
    logic 					valid_flag1;
	logic 					valid_flag2;

	assign		valid_flag1 = (rob_packet.T1 == cdb_packet.tag) || mt_packet.T1_plus;
	assign		valid_flag2 = (rob_packet.T2 == cdb_packet.tag) || mt_packet.T2_plus;

    /*  ready
	determine ready：decide whether to issue
	when checking tags, CDB and RS filling are in the same
	cycle but at the time map table is still in the last cycle

	what proble will it cause?
	eg: inst n: R3= R1+R2
	    inst n+1: R4= R1+R3 (the two insts dispatch simul.)
	在last cycle中，R3对应的mt中带有+, 但在这个cycle中，由于RAW，直
	接对比mt_tag和rs_tag可能会出问题
	*/

    always_comb begin
		//not_ready = ~(valid_flag1 && valid_flag2 && ~empty);

		// Clear the RS line(n_rs_line)
		if(clear) begin
			n_rs_line = '{
				0,                // RSID
				`NOP,             // inst
				0,				  // busy
				0,                // T
				0,                // T1
				0,				  // T2
				0,			      // valid1
				0,                // valid2
				0,                // V1
				0,                // V2
				0,                // PC
				0,				  // NPC
				OPA_IS_RS1,       // opa_select
				OPB_IS_RS2,       // opb_select
				`ZERO_REG,        // dest_reg_idx
				ALU_ADD,          // alu_func
				0,				  // rd_mem
				0,				  // wr_mem
				0,				  // cond_branch
				0,                // uncond_branch
				0,				  // halt
				0,			      // illegal
				0,				  // csr_op
				0				  // valid
			};
			not_ready = 1;
			nn_rs_line = n_rs_line;
		// insert a new inst.
		end else if(enable && (dp_packet.inst != `NOP)) begin
			// data from ROB,MT,CDB
			n_rs_line.valid1 = valid_flag1;
			n_rs_line.valid2 = valid_flag2;
			n_rs_line.RSID = line_id;
			n_rs_line.T = rob_packet.T;
			n_rs_line.T1 = valid_flag1? 0: mt_packet.T1; // 1.Cycle problem? 2.RS tags in RS are from MT
			n_rs_line.T2 = valid_flag2? 0: mt_packet.T2;
			n_rs_line.busy = 1;                          // busy = 1 when enable
			// data from dp_packet
			n_rs_line.V1 = valid_flag1? dp_packet.rs1_value: 0;  // if no value in RS, can we assignV=0? data from DP_IS
			n_rs_line.V2 = valid_flag2? dp_packet.rs2_value: 0;  // if RS2 won't be used? Due to inst. type, should be correct
			n_rs_line.inst = dp_packet.inst;
			n_rs_line.PC = dp_packet.PC;
			n_rs_line.NPC = dp_packet.NPC;
			n_rs_line.opa_select = dp_packet.opa_select;
			n_rs_line.opb_select = dp_packet.opb_select;
			n_rs_line.dest_reg_idx = dp_packet.dest_reg_idx;
			n_rs_line.alu_func = dp_packet.alu_func;
			n_rs_line.rd_mem = dp_packet.rd_mem;
			n_rs_line.wr_mem = dp_packet.wr_mem;
			n_rs_line.cond_branch = dp_packet.cond_branch;
			n_rs_line.uncond_branch = dp_packet.uncond_branch;
			n_rs_line.halt = dp_packet.halt;
			n_rs_line.illegal = dp_packet.illegal;
			n_rs_line.csr_op = dp_packet.csr_op;
			n_rs_line.valid = dp_packet.valid;

			if (valid_flag1 && valid_flag2) begin            // not_ready is to decide 'issue'
				not_ready = 0;
			end else begin
				not_ready = 1;
			end

			nn_rs_line = n_rs_line;
		// line remains unchanged
		end else begin
			n_rs_line = nn_rs_line;
		end
	end







  

// 决定是否将n_rs_line的值传递给rs_line
    always_ff @(posedge clock) begin
        if (reset || squash_flag) begin  // if empty=0，rs_line stalls
			rs_line <= '{
				0,                // RSID
				`NOP,             // inst
				0,				  // busy
				0,                // T
				0,                // T1
				0,				  // T2
				0,			      // valid1
				0,                // valid2
				0,                // V1
				0,                // V2
				0,                // PC
				0,				  // NPC
				OPA_IS_RS1,       // opa_select
				OPB_IS_RS2,       // opb_select
				`ZERO_REG,        // dest_reg_idx
				ALU_ADD,          // alu_func
				0,				  // rd_mem
				0,				  // wr_mem
				0,				  // cond_branch
				0,                // uncond_branch
				0,				  // halt
				0,			      // illegal
				0,				  // csr_op
				0				  // valid
			};

		end else if(enable) begin
			rs_line <= n_rs_line;
		end else begin
			rs_line <= '{
				0,                // RSID
				`NOP,             // inst
				0,				  // busy
				0,                // T
				0,                // T1
				0,				  // T2
				0,			      // valid1
				0,                // valid2
				0,                // V1
				0,                // V2
				0,                // PC
				0,				  // NPC
				OPA_IS_RS1,       // opa_select
				OPB_IS_RS2,       // opb_select
				`ZERO_REG,        // dest_reg_idx
				ALU_ADD,          // alu_func
				0,				  // rd_mem
				0,				  // wr_mem
				0,				  // cond_branch
				0,                // uncond_branch
				0,				  // halt
				0,			      // illegal
				0,				  // csr_op
				0				  // valid
			};
		end
	end
	
endmodule