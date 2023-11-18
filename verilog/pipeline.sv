/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.sv                                         //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline together.                       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"

module pipeline (
    input        clock,             // System clock
    input        reset,             // System reset
    input [3:0]  mem2proc_response, // Tag from memory about current request
    input [63:0] mem2proc_data,     // Data coming back from memory
    input [3:0]  mem2proc_tag,      // Tag from memory about current reply

    output logic [1:0]       proc2mem_command, // Command sent to memory
    output logic [`XLEN-1:0] proc2mem_addr,    // Address sent to memory
    output logic [63:0]      proc2mem_data,    // Data sent to memory
//`ifndef CACHE_MODE
    output MEM_SIZE          proc2mem_size,    // Data size sent to memory
//`endif
    // Note: these are assigned at the very bottom of the module
    output logic [2:0] [3:0]       pipeline_completed_insts,
    output EXCEPTION_CODE    pipeline_error_status,
    output logic [2:0] [4:0]       pipeline_commit_wr_idx,
    output logic [2:0] [`XLEN-1:0] pipeline_commit_wr_data,
    output logic [2:0]            pipeline_commit_wr_en,
    output logic [2:0] [`XLEN-1:0] pipeline_commit_NPC,

    // Debug outputs: these signals are solely used for debugging in testbenches
    // Do not change for project 3
    // You should definitely change these for project 4
    output logic [2:0] [`XLEN-1:0] if_NPC_dbg,
    output logic [2:0] [31:0]      if_inst_dbg,
    output logic [2:0]            if_valid_dbg,
    output logic [2:0] [`XLEN-1:0] is_NPC_dbg,
    output logic [2:0] [31:0]      is_inst_dbg,
    output logic [2:0]            is_valid_dbg,
    output logic [2:0] [`XLEN-1:0] cdb_NPC_dbg,
    output logic [2:0]            cdb_valid_dbg,
    output logic [2:0] [`XLEN-1:0] rt_NPC_dbg,
    output logic [2:0]            rt_valid_dbg   
);

    //////////////////////////////////////////////////
    //                                              //
    //                Pipeline Wires                //
    //                                              //
    //////////////////////////////////////////////////
    logic squash_flag;
    logic [2:0]             rt_valid;
    logic [2:0][`XLEN-1:0]  rt_NPC;
    logic [`XLEN-1:0]       squash_pc;
    //logic [`XLEN-1:0]       target_pc; //from ALU result
    // Outputs from IF-Stage and IF/ID Pipeline Register
    logic [`XLEN-1:0] proc2Imem_addr;
    IF_ID_PACKET [2:0] if_ib_packet; // From IF to insn buffer
    IF_ID_PACKET [2:0] if_dp_packet; //From insn buffer to dp
    DP_PACKET [2:0] dp_packet_out;

    // Outputs from ID stage and ID/EX Pipeline Register
    RS_IS_PACKET [2:0] rs_packet_out, is_ex_reg;

    // Outputs from MEM-Stage and MEM/WB Pipeline Register
    ROB_RT_PACKET [2:0] rob_rt_packet; 
    RT_DP_PACKET [2:0] rt_dp_packet;

    ROB_MT_PACKET [2:0] rob_mt_packet;
    ROB_RS_PACKET [2:0] rob_rs_packet;
    ROB_IF_PACKET rob_if_packet;
    RS_IF_PACKET rs_if_packet;
    MT_ROB_PACKET [2:0] mt_rob_packet;
    MT_RS_PACKET [2:0] mt_rs_packet;
    CDB_MT_PACKET [2:0] cdb_mt_packet;
    CDB_RS_PACKET [2:0] cdb_rs_packet;
    CDB_ROB_PACKET [2:0] cdb_rob_packet;
    EX_PACKET [2:0] ex_cp_packet;

    FU_EMPTY_PACKET fu_empty_packet;

    logic insn_buffer_stall;
    logic halt;


    always @(negedge clock) begin
        $display("-------------------------------------------------------------------------------------------------------");
        $display("instruction[1]:%b, instruciton[0]:%b", mem2proc_data[63:32], mem2proc_data[31:0]);
        $display("proc2mem_addr:%b proc2Imem_addr:%b", proc2mem_addr, proc2Imem_addr);
        $display("if_NPC[0]:%h if_inst[0]:%h if_valid[0]:%b", if_ib_packet[0].NPC, if_ib_packet[0].inst, if_ib_packet[0].valid);
        $display("if_NPC[1]:%h if_inst[1]:%h if_valid[1]:%b", if_ib_packet[1].NPC, if_ib_packet[1].inst, if_ib_packet[1].valid);
        $display("if_NPC[2]:%h if_inst[2]:%h if_valid[2]:%b", if_ib_packet[2].NPC, if_ib_packet[2].inst, if_ib_packet[2].valid);
        $display("ib_NPC[0]:%h ib_inst[0]:%h ib_valid[0]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[0], if_inst_dbg[0], if_valid_dbg[0], rob_if_packet.empty_num, rs_if_packet.empty_num);
        $display("ib_NPC[1]:%h ib_inst[1]:%h ib_valid[1]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[1], if_inst_dbg[1], if_valid_dbg[1], rob_if_packet.empty_num, rs_if_packet.empty_num);
        $display("ib_NPC[2]:%h ib_inst[2]:%h ib_valid[2]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[2], if_inst_dbg[2], if_valid_dbg[2], rob_if_packet.empty_num, rs_if_packet.empty_num);
        $display("dp_NPC[0]:%h dp_inst[0]:%h dp_valid[0]:%b", dp_packet_out[0].NPC, dp_packet_out[0].inst, ~dp_packet_out[0].illegal);
        $display("dp_NPC[1]:%h dp_inst[1]:%h dp_valid[1]:%b", dp_packet_out[1].NPC, dp_packet_out[1].inst, ~dp_packet_out[1].illegal);
        $display("dp_NPC[2]:%h dp_inst[2]:%h dp_valid[2]:%b", dp_packet_out[2].NPC, dp_packet_out[2].inst, ~dp_packet_out[2].illegal);
        $display("is_NPC[0]:%h is_inst[0]:%h is_valid[0]:%b is_tag[0]:%h", is_NPC_dbg[0], is_inst_dbg[0], is_valid_dbg[0], is_ex_reg[0].T);
        $display("is_NPC[1]:%h is_inst[1]:%h is_valid[1]:%b is_tag[1]:%h", is_NPC_dbg[1], is_inst_dbg[1], is_valid_dbg[1], is_ex_reg[1].T);
        $display("is_NPC[2]:%h is_inst[2]:%h is_valid[2]:%b is_tag[2]:%h", is_NPC_dbg[2], is_inst_dbg[2], is_valid_dbg[2], is_ex_reg[2].T);
        $display("cdb_NPC[0]:%h cdb_valid[0]:%b cdb_tag[0]:%h", cdb_NPC_dbg[0], cdb_valid_dbg[0], cdb_rob_packet[0].tag);
        $display("cdb_NPC[1]:%h cdb_valid[1]:%b cdb_tag[1]:%h", cdb_NPC_dbg[1], cdb_valid_dbg[1], cdb_rob_packet[1].tag);
        $display("cdb_NPC[2]:%h cdb_valid[2]:%b cdb_tag[2]:%h", cdb_NPC_dbg[2], cdb_valid_dbg[2], cdb_rob_packet[2].tag);
        $display("rt_NPC[0]:%h rt_valid[0]:%b", rt_NPC_dbg[0], rt_valid_dbg[0]);
        $display("rt_NPC[1]:%h rt_valid[1]:%b", rt_NPC_dbg[1], rt_valid_dbg[1]);
        $display("rt_NPC[2]:%h rt_valid[2]:%b", rt_NPC_dbg[2], rt_valid_dbg[2]);
        $display("wr_idx[0]:%h wr_data[0]:%h wr_en[0]:%b", pipeline_commit_wr_idx[0], pipeline_commit_wr_data[0], pipeline_commit_wr_en[0]); 
        $display("wr_idx[1]:%h wr_data[1]:%h wr_en[1]:%b", pipeline_commit_wr_idx[1], pipeline_commit_wr_data[1], pipeline_commit_wr_en[1]); 
        $display("wr_idx[2]:%h wr_data[2]:%h wr_en[2]:%b", pipeline_commit_wr_idx[2], pipeline_commit_wr_data[2], pipeline_commit_wr_en[2]); 
    end
    
    //////////////////////////////////////////////////
    //                                              //
    //                Memory Outputs                //
    //                                              //
    //////////////////////////////////////////////////

    // these signals go to and from the processor and memory
    // we give precedence to the mem stage over instruction fetch
    // note that there is no latency in project 3
    // but there will be a 100ns latency in project 4

    always_comb begin
        proc2mem_command = BUS_LOAD;
        proc2mem_addr    = proc2Imem_addr;
        proc2mem_size    = DOUBLE;          // instructions load a full memory line (64 bits)
        proc2mem_data = 64'b0;
	//$display("\nin pipeline\n");
    end

    

    //////////////////////////////////////////////////
    //                                              //
    //                  IF-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    stage_if if0(
		.clock(clock),
		.reset(reset),
		.squash_flag(squash_flag),
		.take_branch(squash_flag),
		.target_pc(squash_pc), // 
		.squash_pc(squash_pc),
		.Imem2proc_data(mem2proc_data),
		.insn_buffer_stall(insn_buffer_stall),
		.if_dp_packet_out(if_ib_packet),
		.proc2Imem_addr(proc2Imem_addr)
	);

    insn_buffer insn_buffer0 (
		.clock(clock),
		.enable(1'b1),
		.reset(reset),
		.squash_flag(squash_flag),
		.if_packet_in(if_ib_packet),
		.ROB_blank_number(rob_if_packet.empty_num),
		.RS_blank_number(rs_if_packet.empty_num),
		.ib_dp_packet_out(if_dp_packet),
		.insn_buffer_full(insn_buffer_stall)
	);

    // debug outputs
/*
    assign if_NPC_dbg   = (if_dp_packet[2].valid) ? if_dp_packet[2].NPC : (if_dp_packet[1].valid) ? if_dp_packet[1].NPC : (if_dp_packet[0].valid) ?
				if_dp_packet[0].NPC : {`XLEN{1'b0}};
    assign if_inst_dbg  = (if_dp_packet[2].valid) ? if_dp_packet[2].inst : (if_dp_packet[1].valid) ? if_dp_packet[1].inst : (if_dp_packet[0].valid) ?
				if_dp_packet[0].inst : `NOP;
    assign if_valid_dbg = if_dp_packet[0].valid;
*/
    assign if_NPC_dbg[0]   = if_dp_packet[0].NPC;
    assign if_NPC_dbg[1]   = if_dp_packet[1].NPC;
    assign if_NPC_dbg[2]   = if_dp_packet[2].NPC;
    assign if_inst_dbg[0]  = if_dp_packet[0].inst;
    assign if_inst_dbg[1]  = if_dp_packet[1].inst;
    assign if_inst_dbg[2]  = if_dp_packet[2].inst;
    assign if_valid_dbg[0] = if_dp_packet[0].valid;
    assign if_valid_dbg[1] = if_dp_packet[1].valid;
    assign if_valid_dbg[2] = if_dp_packet[2].valid;
    //////////////////////////////////////////////////
    //                                              //
    //                  DP                    //
    //                                              //
    //////////////////////////////////////////////////

    DP dp0 (
        // input
        .clock(clock),
        .reset(reset),
        .if_id_packet(if_dp_packet),
        .rt_packet(rt_dp_packet),

        // output
        .dp_packet(dp_packet_out)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  MT                         //
    //                                              //
    //////////////////////////////////////////////////

    MT MT0(
        //input
        .clock(clock),
        .reset(reset),
        .squash_flag(squash_flag),
        .rob_packet(rob_mt_packet),
        .dp_packet(dp_packet_out),
        .cdb_packet(cdb_mt_packet),
        
        //output
        .mt_rs_packet(mt_rs_packet),
        .mt_rob_packet(mt_rob_packet)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  ROB                         //
    //                                              //
    //////////////////////////////////////////////////

    ROB ROB0 (
	    //input 
	    .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .squash_flag(squash_flag),
        .CDB_packet_in(cdb_rob_packet),
        .DP_packet_in(dp_packet_out),
        .MT_packet_in(mt_rob_packet),
        
        //output 
        .IF_packet_out(rob_if_packet),
        .RT_packet_out(rob_rt_packet),
	.RS_packet_out(rob_rs_packet),
	.MT_packet_out(rob_mt_packet)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  RS                         //
    //                                              //
    //////////////////////////////////////////////////

    RS RS0 (
	    //input 
	    .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .squash_flag(squash_flag),
        .mt_packet_in(mt_rs_packet),
        .dp_packet_in(dp_packet_out),
        .rob_packet_in(rob_rs_packet),
        .cdb_packet_in(cdb_rs_packet),
	.fu_empty_packet(fu_empty_packet),
        
        //output 
        .is_packet_out(rs_packet_out),
        .dp_packet_out(rs_if_packet)
    );

    //////////////////////////////////////////////////
    //                                              //
    //            IS/EX Pipeline Register           //
    //                                              //
    //////////////////////////////////////////////////
    always_ff @(posedge clock) begin
	//if branch is taken, squash predicted instruction
	// if there is data hazard, insert nop
        if (reset) begin
            is_ex_reg[0] <= {
                    {$clog2(`ROBLEN){1'b0}}, // T
                    `NOP,                    // inst
                    {`XLEN{1'b0}},           // PC
                    {`XLEN{1'b0}},           // NPC

                    {`XLEN{1'b0}},           // RS1_value
                    {`XLEN{1'b0}},           // RS2_value
                    
                    OPA_IS_RS1,              // OPA_SELECT
                    OPB_IS_RS2,              // OPB_SELECT
                    
                    `ZERO_REG,               // dest_reg_idx
                    ALU_ADD,                 // alu_func

                    1'b0,                    // rd_mem
                    1'b0,                    // wr_mem
                    1'b0,                    // cond_branch
                    1'b0,                    // uncond_branch
                    1'b0,                    // halt
                    1'b1,                    // illegal
                    1'b0,                    // csr_op
                    1'b0,                     // valid
		    FUNC_NOP			//func_unit
                };
            is_ex_reg[1] <= {
                    {$clog2(`ROBLEN){1'b0}}, // T
                    `NOP,                    // inst
                    {`XLEN{1'b0}},           // PC
                    {`XLEN{1'b0}},           // NPC

                    {`XLEN{1'b0}},           // RS1_value
                    {`XLEN{1'b0}},           // RS2_value
                    
                    OPA_IS_RS1,              // OPA_SELECT
                    OPB_IS_RS2,              // OPB_SELECT
                    
                    `ZERO_REG,               // dest_reg_idx
                    ALU_ADD,                 // alu_func

                    1'b0,                    // rd_mem
                    1'b0,                    // wr_mem
                    1'b0,                    // cond_branch
                    1'b0,                    // uncond_branch
                    1'b0,                    // halt
                    1'b1,                    // illegal
                    1'b0,                    // csr_op
                    1'b0,                     // valid
		    FUNC_NOP			//func_unit
                };
            is_ex_reg[2] <= {
            {$clog2(`ROBLEN){1'b0}}, // T
            `NOP,                    // inst
            {`XLEN{1'b0}},           // PC
            {`XLEN{1'b0}},           // NPC

            {`XLEN{1'b0}},           // RS1_value
            {`XLEN{1'b0}},           // RS2_value
            
            OPA_IS_RS1,              // OPA_SELECT
            OPB_IS_RS2,              // OPB_SELECT
            
            `ZERO_REG,               // dest_reg_idx
            ALU_ADD,                 // alu_func

            1'b0,                    // rd_mem
            1'b0,                    // wr_mem
            1'b0,                    // cond_branch
            1'b0,                    // uncond_branch
            1'b0,                    // halt
            1'b1,                    // illegal
            1'b0,                    // csr_op
            1'b0,                     // valid
		    FUNC_NOP			//func_unit
        };
        end else begin
            is_ex_reg <= rs_packet_out;
        end
    end

    // debug outputs
/*
    assign is_NPC_dbg   = (~is_ex_reg[2].illegal) ? is_ex_reg[2].NPC : (~is_ex_reg[1].illegal) ? is_ex_reg[1].NPC : (~is_ex_reg[0].illegal) ? is_ex_reg[0].NPC : {`XLEN{1'b0}};
    assign is_inst_dbg  = (~is_ex_reg[2].illegal) ? is_ex_reg[2].inst : (~is_ex_reg[1].illegal) ? is_ex_reg[1].inst : (~is_ex_reg[0].illegal) ? is_ex_reg[0].inst : `NOP;
    assign is_valid_dbg = ~is_ex_reg[0].illegal;
*/
    assign is_NPC_dbg[0]   = is_ex_reg[0].NPC;
    assign is_NPC_dbg[1]   = is_ex_reg[1].NPC;
    assign is_NPC_dbg[2]   = is_ex_reg[2].NPC;
    assign is_inst_dbg[0]  = is_ex_reg[0].inst;
    assign is_inst_dbg[1]  = is_ex_reg[1].inst;
    assign is_inst_dbg[2]  = is_ex_reg[2].inst;
    assign is_valid_dbg[0] = ~is_ex_reg[0].illegal;
    assign is_valid_dbg[1] = ~is_ex_reg[1].illegal;
    assign is_valid_dbg[2] = ~is_ex_reg[2].illegal;
    //////////////////////////////////////////////////
    //                                              //
    //                  EX-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    EX EX0 ( 
        .clock(clock), 
        .reset(reset), 
        .clear(squash_flag),
        .IS_packet(is_ex_reg),

        .FU_empty_packet(fu_empty_packet),
        .EX_packet(ex_cp_packet)
    );
   
    stage_cp CP0(
        // input
        .ex_packet_in(ex_cp_packet),
        // output
        .cdb_rs_packet_out(cdb_rs_packet),
        .cdb_mt_packet_out(cdb_mt_packet),
        .cdb_rob_packet_out(cdb_rob_packet)
    );
    
    // debug outputs
/*
    assign cdb_NPC_dbg   = (cdb_rob_packet[2].valid) ? cdb_rob_packet[2].NPC : (cdb_rob_packet[1].valid) ? cdb_rob_packet[1].NPC : (cdb_rob_packet[0].valid) ?
				cdb_rob_packet[0].NPC : {`XLEN{1'b0}};
    assign cdb_valid_dbg = cdb_rob_packet[0].valid;
*/
    assign cdb_NPC_dbg[0]   = cdb_rob_packet[0].NPC;
    assign cdb_NPC_dbg[1]   = cdb_rob_packet[1].NPC;
    assign cdb_NPC_dbg[2]   = cdb_rob_packet[2].NPC;
    assign cdb_valid_dbg[0] = cdb_rob_packet[0].valid;
    assign cdb_valid_dbg[1] = cdb_rob_packet[1].valid;
    assign cdb_valid_dbg[2] = cdb_rob_packet[2].valid;
    //////////////////////////////////////////////////
    //                                              //
    //                  RT-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    stage_rt RT0 (
         // input
        .rob_rt_packet_in(rob_rt_packet), 
        // output
        .rt_dp_packet_out(rt_dp_packet),
        .valid(rt_valid),
        .NPC(rt_NPC),
        .squash_pc(squash_pc),
        .squash_flag(squash_flag),
	    .halt(halt)
     );

    // debug outputs
/*
    assign rt_NPC_dbg   = (rt_valid[2]) ? rt_NPC[2] : (rt_valid[1]) ? rt_NPC[1] : (rt_valid[0]) ? rt_NPC[0] : {`XLEN{1'b0}};;
    assign rt_valid_dbg = rt_valid[0];
*/
    assign rt_NPC_dbg[0]   = rt_NPC[0];
    assign rt_NPC_dbg[1]   = rt_NPC[1];
    assign rt_NPC_dbg[2]   = rt_NPC[2];
    assign rt_valid_dbg[0] = rt_valid[0];
    assign rt_valid_dbg[1] = rt_valid[1];
    assign rt_valid_dbg[2] = rt_valid[2];
    //////////////////////////////////////////////////
    //                                              //
    //               Pipeline Outputs               //
    //                                              //
    //////////////////////////////////////////////////

    assign pipeline_completed_insts[0] = {3'b0, rt_valid[0]}; // commit one valid instruction
    assign pipeline_completed_insts[1] = {3'b0, rt_valid[1]};
    assign pipeline_completed_insts[2] = {3'b0, rt_valid[2]};
    assign pipeline_error_status = (halt) ? HALTED_ON_WFI :(mem2proc_response==4'h0) ? LOAD_ACCESS_FAULT : NO_ERROR;

    assign pipeline_commit_wr_en[0]   = rt_dp_packet[0].valid;
    assign pipeline_commit_wr_en[1]   = rt_dp_packet[1].valid;
    assign pipeline_commit_wr_en[2]   = rt_dp_packet[2].valid;
    assign pipeline_commit_wr_idx[0]  = rt_dp_packet[0].retire_reg;
    assign pipeline_commit_wr_idx[1]  = rt_dp_packet[1].retire_reg;
    assign pipeline_commit_wr_idx[2]  = rt_dp_packet[2].retire_reg;
    assign pipeline_commit_wr_data[0] = rt_dp_packet[0].value;
    assign pipeline_commit_wr_data[1] = rt_dp_packet[1].value;
    assign pipeline_commit_wr_data[2] = rt_dp_packet[2].value;
    assign pipeline_commit_NPC[0]     = (rt_valid[0]) ? rt_NPC[2] : {`XLEN{1'b0}};
    assign pipeline_commit_NPC[1]     = (rt_valid[1]) ? rt_NPC[2] : {`XLEN{1'b0}};
    assign pipeline_commit_NPC[2]     = (rt_valid[2]) ? rt_NPC[2] : {`XLEN{1'b0}};

endmodule // pipeline