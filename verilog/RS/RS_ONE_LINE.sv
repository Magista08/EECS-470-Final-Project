/*
	我们决定将superscalar的way number改为packet外，所以sys_defs中
	打包的【2:0】都去掉
*/
`include "../sys_defs.svh"

module RS_ONE_LINE (
	// INPUT

    input             	       clock, reset, enable,
    input 	 				   clear,             // whether clear the RS_line
    // input  					   squash_flag,
    input [$clog2(`ROBLEN)-1:0]line_id,
    // input					sel,
    input DP_IS_PACKET 		   dp_packet,
    input MT_RS_PACKET  	   mt_packet,
    input ROB_RS_PACKET		   rob_packet,
    input CDB_RS_PACKET	[2:0]  cdb_packet,

	// the other 2 tags (in order)
	input [$clog2(`ROBLEN)-1:0] other_T1,
	input [$clog2(`ROBLEN)-1:0] other_T2,
	// the other 2 insts (in order)
	input  						other_dest_reg1,
	input  						other_dest_reg2,
	// position
	input [1:0] 				my_position,

	// OUTPUT
	output logic  			not_ready,
    output RS_LINE  		rs_line
);
    RS_LINE  				n_rs_line;
    logic 					valid_flag1;
	logic 					valid_flag2;

	assign		valid_flag1 = (~mt_packet.valid1) || 
							  (cdb_packet[0].valid && mt_packet.T1 == cdb_packet[0].tag) || 
							  (cdb_packet[1].valid && mt_packet.T1 == cdb_packet[1].tag) || 
							  (cdb_packet[2].valid && mt_packet.T1 == cdb_packet[2].tag) || 
							  mt_packet.T1_plus;  //judge whether T1 in RS is valid
	assign		valid_flag2 = (~mt_packet.valid2) || 
							  (cdb_packet[0].valid && mt_packet.T2 == cdb_packet[0].tag) || 
							  (cdb_packet[1].valid && mt_packet.T2 == cdb_packet[1].tag) || 
							  (cdb_packet[2].valid && mt_packet.T2 == cdb_packet[2].tag) || 
							  mt_packet.T2_plus;
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
		if(clear || reset) begin // add reset
			n_rs_line = '{
				{$clog2(`RSLEN){1'b0}},  // RSID
				`NOP,             		 // inst
				1'b0,				  	 // busy
				{$clog2(`ROBLEN){1'b0}}, // T
				{$clog2(`ROBLEN){1'b0}}, // T1
				{$clog2(`ROBLEN){1'b0}}, // T2
				1'b0,			     	 // valid1
				1'b0,             		 // valid2
				{`XLEN{1'b0}},           // V1
				{`XLEN{1'b0}},           // V2
				{`XLEN{1'b0}},           // PC
				{`XLEN{1'b0}},			 // NPC
				OPA_IS_RS1,       		 // opa_select
				OPB_IS_RS2,       		 // opb_select
				`ZERO_REG,       		 // dest_reg_idx
				ALU_ADD,         		 // alu_func
				1'b0,				     // rd_mem
				1'b0,				     // wr_mem
				1'b0,				     // cond_branch
				1'b0,                    // uncond_branch
				1'b0,				     // halt
				1'b0,			         // illegal
				1'b0,				     // csr_op
				1'b0				     // valid
			};
			not_ready = 1;

		// clear = 0 conditon
		end else begin
			// enable =1 indicates we should observe RS_line
			if (enable) begin
				// when instruction fetched is not a noop -- insert a new inst.
				if (dp_packet.inst != `NOP) begin
					// data from ROB,MT,CDB
					n_rs_line.valid1 = valid_flag1;
					n_rs_line.valid2 = valid_flag2;
					n_rs_line.RSID = line_id;
					n_rs_line.T = rob_packet.T;
					// n_rs_line.T1 = valid_flag1? 0: mt_packet.T1; // 1.Cycle problem? 2.RS tags in RS are from MT
					// n_rs_line.T2 = valid_flag2? 0: mt_packet.T2;

					if (my_position == 2'b00) begin
						n_rs_line.T1 = valid_flag1? 0:mt_packet.T1;
					end else if (my_position == 2'b01) begin
						n_rs_line.T1 = (dp_packet.rs1_instruction && dp_packet.inst.r.rs1 == other_dest_reg1 && ~other_dest_reg1)? other_T1:
									    valid_flag1? 0:
										mt_packet.T1;
					end else begin
						n_rs_line.T1 = (dp_packet.rs1_instruction && dp_packet.inst.r.rs1 == other_dest_reg2 && ~other_dest_reg2)? other_T2:
									   (dp_packet.rs1_instruction && dp_packet.inst.r.rs1 == other_dest_reg1 && ~other_dest_reg1)? other_T1:
									   	valid_flag1? 0:
										mt_packet.T1;
					end

					if (my_position == 2'b00) begin
						n_rs_line.T2 = valid_flag2? 0:mt_packet.T2;
					end else if (my_position == 2'b01) begin
						n_rs_line.T2 = (dp_packet.rs2_instruction && dp_packet.inst.r.rs2 == other_dest_reg1 && ~other_dest_reg1)? other_T1:
									    valid_flag2? 0:
										mt_packet.T2;
					end else begin
						n_rs_line.T2 = (dp_packet.rs2_instruction && dp_packet.inst.r.rs2 == other_dest_reg2 && ~other_dest_reg2)? other_T2:
									   (dp_packet.rs2_instruction && dp_packet.inst.r.rs2 == other_dest_reg1 && ~other_dest_reg1)? other_T1:
									   	valid_flag2? 0:
										mt_packet.T2;
					end 




					n_rs_line.busy = 1;                          // busy = 1 when enable


					// data from ROB, CDB, Regfile
					n_rs_line.V1 = (cdb_packet[0].valid && mt_packet.T1 == cdb_packet[0].tag)? cdb_packet[0].value:
								   (cdb_packet[1].valid && mt_packet.T1 == cdb_packet[1].tag)? cdb_packet[1].value:
								   (cdb_packet[2].valid && mt_packet.T1 == cdb_packet[2].tag)? cdb_packet[2].value:
								   (rob_packet.valid1 && mt_packet.valid1 && mt_packet.T1_plus)? rob_packet.V1:
								    dp_packet.rs1_value;

					n_rs_line.V2 = (cdb_packet[0].valid && mt_packet.T2 == cdb_packet[0].tag)? cdb_packet[0].value:
								   (cdb_packet[1].valid && mt_packet.T2 == cdb_packet[1].tag)? cdb_packet[1].value:
								   (cdb_packet[2].valid && mt_packet.T2 == cdb_packet[2].tag)? cdb_packet[2].value:
								   (rob_packet.valid2 && mt_packet.valid2 && mt_packet.T2_plus)? rob_packet.V2:
								    dp_packet.rs2_value;
													
					
					// n_rs_line.V1 = (dp_packet.T1 == cdb_packet.tag)? cdb_packet.value: 
					// 			   (~mt_packet.valid1)? dp_packet.rs1_value: 
					// 			   (mt_packet.T1_plus)? rob_packet.V1: 0;
					// n_rs_line.V2 = (dp_packet.T2 == cdb_packet.tag)? cdb_packet.value: (~mt_packet.valid1) ? dp_packet.rs1_value : (mt_packet.T1_plus)? rob_packet.V1: 0;
					
										
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
				// inst == NOP condition
				end else begin
					n_rs_line = '{
						{$clog2(`RSLEN){1'b0}},  // RSID
						`NOP,             		 // inst
						1'b0,				  	 // busy
						{$clog2(`ROBLEN){1'b0}}, // T
						{$clog2(`ROBLEN){1'b0}}, // T1
						{$clog2(`ROBLEN){1'b0}}, // T2
						1'b0,			     	 // valid1
						1'b0,             		 // valid2
						{`XLEN{1'b0}},           // V1
						{`XLEN{1'b0}},           // V2
						{`XLEN{1'b0}},           // PC
						{`XLEN{1'b0}},			 // NPC
						OPA_IS_RS1,       		 // opa_select
						OPB_IS_RS2,       		 // opb_select
						`ZERO_REG,       		 // dest_reg_idx
						ALU_ADD,         		 // alu_func
						1'b0,				     // rd_mem
						1'b0,				     // wr_mem
						1'b0,				     // cond_branch
						1'b0,                    // uncond_branch
						1'b0,				     // halt
						1'b0,			         // illegal
						1'b0,				     // csr_op
						1'b0				     // valid
					};
					not_ready = 1;
				end
			// enable = 0 conditon
			end else begin
				// last cycle: RS_line filled or unfilled? (up to busy)
				// RS_line unfilled 
				if (!rs_line.busy) begin
					n_rs_line = '{
						{$clog2(`RSLEN){1'b0}},  // RSID
						`NOP,             		 // inst
						1'b0,				  	 // busy
						{$clog2(`ROBLEN){1'b0}}, // T
						{$clog2(`ROBLEN){1'b0}}, // T1
						{$clog2(`ROBLEN){1'b0}}, // T2
						1'b0,			     	 // valid1
						1'b0,             		 // valid2
						{`XLEN{1'b0}},           // V1
						{`XLEN{1'b0}},           // V2
						{`XLEN{1'b0}},           // PC
						{`XLEN{1'b0}},			 // NPC
						OPA_IS_RS1,       		 // opa_select
						OPB_IS_RS2,       		 // opb_select
						`ZERO_REG,       		 // dest_reg_idx
						ALU_ADD,         		 // alu_func
						1'b0,				     // rd_mem
						1'b0,				     // wr_mem
						1'b0,				     // cond_branch
						1'b0,                    // uncond_branch
						1'b0,				     // halt
						1'b0,			         // illegal
						1'b0,				     // csr_op
						1'b0				     // valid
					};
					not_ready = 1;
				// RS_line filled (busy = 1)
				end else begin
					n_rs_line.valid1 = ((cdb_packet[0].valid && rs_line.T1 == cdb_packet[0].tag) || 
										(cdb_packet[1].valid && rs_line.T1 == cdb_packet[1].tag) ||
										(cdb_packet[2].valid && rs_line.T1 == cdb_packet[2].tag)) ? 1 : rs_line.valid1;     //根据上一个cycle中rs_line中的tag与mt,cdb比较来确定
					n_rs_line.valid2 = ((cdb_packet[0].valid && rs_line.T2 == cdb_packet[0].tag) || 
										(cdb_packet[1].valid && rs_line.T2 == cdb_packet[1].tag) ||
										(cdb_packet[2].valid && rs_line.T2 == cdb_packet[2].tag)) ? 1 : rs_line.valid2;
					n_rs_line.RSID = rs_line.RSID;
					n_rs_line.T = rs_line.T;
					n_rs_line.T1 = ((cdb_packet[0].valid && rs_line.T1 == cdb_packet[0].tag) || 
									(cdb_packet[1].valid && rs_line.T1 == cdb_packet[1].tag) ||
									(cdb_packet[2].valid && rs_line.T1 == cdb_packet[2].tag)) ? 0 :
									(rs_line.T1 == mt_packet.T1_plus) ? 0 : rs_line.T1; // 1.Cycle problem? 2.RS tags in RS are from MT
					n_rs_line.T2 = ((cdb_packet[0].valid && rs_line.T2 == cdb_packet[0].tag) || 
									(cdb_packet[1].valid && rs_line.T2 == cdb_packet[1].tag) ||
									(cdb_packet[2].valid && rs_line.T2 == cdb_packet[2].tag)) ? 0 :
									(rs_line.T2 == mt_packet.T2_plus) ? 0 : rs_line.T2;
					n_rs_line.busy = 1;                          // busy = 1 before entering exe


					// n_rs_line.V1 = (rs_line.T1 == cdb_packet.tag)? cdb_packet.value:mt_packet.T1_plus? dp_packet.rs1_value: rs_line.V1;  // value要改
					// n_rs_line.V2 = (rs_line.T2 == cdb_packet.tag)? cdb_packet.value:(rs_line.T2 == mt_packet.T2_plus)? dp_packet.rs2_value: rs_line.V2;   // value要改
					

					// CDB or no change
					n_rs_line.V1 = (cdb_packet[0].valid && rs_line.T1 == cdb_packet[0].tag)? cdb_packet[0].value:
								   (cdb_packet[1].valid && rs_line.T1 == cdb_packet[1].tag)? cdb_packet[1].value:
								   (cdb_packet[2].valid && rs_line.T1 == cdb_packet[2].tag)? cdb_packet[2].value:
								   rs_line.V1;


					n_rs_line.V2 = (cdb_packet[0].valid && rs_line.T2 == cdb_packet[0].tag)? cdb_packet[0].value:
								   (cdb_packet[1].valid && rs_line.T2 == cdb_packet[1].tag)? cdb_packet[1].value:
								   (cdb_packet[2].valid && rs_line.T2 == cdb_packet[2].tag)? cdb_packet[2].value:
								   rs_line.V2;				
					
					
					// below keeps unchanged
					n_rs_line.inst = rs_line.inst;
					n_rs_line.PC = rs_line.PC;
					n_rs_line.NPC = rs_line.NPC;
					n_rs_line.opa_select = rs_line.opa_select;
					n_rs_line.opb_select = rs_line.opb_select;
					n_rs_line.dest_reg_idx = rs_line.dest_reg_idx;
					n_rs_line.alu_func = rs_line.alu_func;
					n_rs_line.rd_mem = rs_line.rd_mem;
					n_rs_line.wr_mem = rs_line.wr_mem;
					n_rs_line.cond_branch = rs_line.cond_branch;
					n_rs_line.uncond_branch = rs_line.uncond_branch;
					n_rs_line.halt = rs_line.halt;
					n_rs_line.illegal = rs_line.illegal;
					n_rs_line.csr_op = rs_line.csr_op;
					n_rs_line.valid = rs_line.valid;

				end

			end
		end
	end


// 决定是否将n_rs_line的值传递给rs_line
    always_ff @(posedge clock) begin
        if (reset || clear) begin  // if empty=0，rs_line stalls
			rs_line <= '{
				{$clog2(`RSLEN){1'b0}},  // RSID
				`NOP,             		 // inst
				1'b0,				  	 // busy
				{$clog2(`ROBLEN){1'b0}}, // T
				{$clog2(`ROBLEN){1'b0}}, // T1
				{$clog2(`ROBLEN){1'b0}}, // T2
				1'b0,			     	 // valid1
				1'b0,             		 // valid2
				{`XLEN{1'b0}},           // V1
				{`XLEN{1'b0}},           // V2
				{`XLEN{1'b0}},           // PC
				{`XLEN{1'b0}},			 // NPC
				OPA_IS_RS1,       		 // opa_select
				OPB_IS_RS2,       		 // opb_select
				`ZERO_REG,       		 // dest_reg_idx
				ALU_ADD,         		 // alu_func
				1'b0,				     // rd_mem
				1'b0,				     // wr_mem
				1'b0,				     // cond_branch
				1'b0,                    // uncond_branch
				1'b0,				     // halt
				1'b0,			         // illegal
				1'b0,				     // csr_op
				1'b0				     // valid
			};

		end else if(enable) begin
			rs_line <= n_rs_line;
		end else begin
			rs_line <= '{
				{$clog2(`RSLEN){1'b0}},  // RSID
				`NOP,             		 // inst
				1'b0,				  	 // busy
				{$clog2(`ROBLEN){1'b0}}, // T
				{$clog2(`ROBLEN){1'b0}}, // T1
				{$clog2(`ROBLEN){1'b0}}, // T2
				1'b0,			     	 // valid1
				1'b0,             		 // valid2
				{`XLEN{1'b0}},           // V1
				{`XLEN{1'b0}},           // V2
				{`XLEN{1'b0}},           // PC
				{`XLEN{1'b0}},			 // NPC
				OPA_IS_RS1,       		 // opa_select
				OPB_IS_RS2,       		 // opb_select
				`ZERO_REG,       		 // dest_reg_idx
				ALU_ADD,         		 // alu_func
				1'b0,				     // rd_mem
				1'b0,				     // wr_mem
				1'b0,				     // cond_branch
				1'b0,                    // uncond_branch
				1'b0,				     // halt
				1'b0,			         // illegal
				1'b0,				     // csr_op
				1'b0				     // valid
			};
		end
	end
	
endmodule