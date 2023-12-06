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
    // output logic [1:0]       proc2mem_size,    // Size sent to memory
//`endif
    // Note: these are assigned at the very bottom of the module
    output logic [2:0] [3:0]       pipeline_completed_insts,
    output EXCEPTION_CODE    pipeline_error_status,
    output logic [2:0] [4:0]       pipeline_commit_wr_idx,
    output logic [2:0] [`XLEN-1:0] pipeline_commit_wr_data,
    output logic [2:0]            pipeline_commit_wr_en,
    output logic [2:0] [`XLEN-1:0] pipeline_commit_NPC,
    output DCACHE_SET [`DCACHE_SET_NUM-1:0] dcache_table_out,

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
    logic [1:0]       proc2Dmem_command; 
    logic [`XLEN-1:0] proc2Dmem_addr;    
    logic [63:0]      proc2Dmem_data;    
    MEM_SIZE          proc2Dmem_size;
    

    // Outputs from IF-Stage and IF/ID Pipeline Register
    // icache
    logic [1:0]        Icache2Imem_command;
    ICACHE_IF_PACKET [2:0] icache_if_packet;
    logic [`XLEN-1:0] proc2Imem_addr;
    logic [2:0] [`XLEN-1:0] if_ic_addr;
    // Fetch
    IF_ID_PACKET [2:0] if_bp_packet, bp_ib_packet; // From IF to insn buffer
    logic insn_buffer_stall;
    // BP
    logic [`XLEN-1:0] bp_npc, bp_npc_reg;
    EX_BP_PACKET [2:0] ex_bp_packet;
    // Instruction Buffer
    IF_ID_PACKET [2:0] ib_dp_packet; //From insn buffer to dp
    
    // Outputs from MEM-Stage and MEM/WB Pipeline Register
    // Dispatch
    DP_PACKET [2:0] dp_packet_out;
    // ROB
    ROB_MT_PACKET [2:0] rob_mt_packet;
    ROB_RS_PACKET [2:0] rob_rs_packet;
    ROB_RT_PACKET [2:0] rob_rt_packet; 
    ROB_IF_PACKET rob_if_packet;
    // MT
    MT_ROB_PACKET [2:0] mt_rob_packet;
    MT_RS_PACKET [2:0] mt_rs_packet;
    // RS
    RS_IS_PACKET [2:0] rs_packet_out, is_ex_reg; 
    RS_IF_PACKET rs_if_packet;

    // Outputs from EX-stage and EX/MEM Pipeline Register
    EX_PACKET [2:0] ex_cp_packet;
    FU_EMPTY_PACKET fu_empty_packet;
    // LSQ
    SQ_LINE [`N-1:0] LOAD_STORE_input;
    logic   [`N-1:0] [$clog2(`SQ_SIZE)-1:0] sq_tail;     // lsq to RS, Store Queue last position
    logic                                   sq_full; // to insn buffer, Store Queue full
    // DCache
    logic rt_busy;
    logic d_i_busy;

    // Outputs from CP-stage and CP/WB Pipeline Register
    CDB_MT_PACKET [2:0]  cdb_mt_packet;
    CDB_RS_PACKET [2:0]  cdb_rs_packet;
    CDB_ROB_PACKET [2:0] cdb_rob_packet;

    // Outputs from RT-stage and RT/WB Pipeline Register
    RT_DP_PACKET [2:0]      rt_dp_packet;
    RT_MT_PACKET [2:0]      rt_mt_packet;
    RT_LSQ_PACKET   [2:0]   rt_lsq_packet;

    
    logic halt;


    always_ff @(posedge clock) begin
        $display("-----------------------------------------------------------------------------------------------------------");
        $display("---------------------------------------------Pipeline-----------------------------------------------------");
        $display("instruction[1]:%h, instruciton[0]:%h", mem2proc_data[63:32], mem2proc_data[31:0]);
        $display("squash_flag:%b, squash_pc:%h, sq_full: %b", squash_flag, squash_pc, sq_full);
        $display("---------------------------------------------ICache------------------------------------------------------");
        $display("icache_if_packet[0].inst:%h, icache_if_packet[0].valid:%b", icache_if_packet[0].inst, icache_if_packet[0].valid);
        $display("icache_if_packet[1].inst:%h, icache_if_packet[1].valid:%b", icache_if_packet[1].inst, icache_if_packet[1].valid);
        $display("icache_if_packet[2].inst:%h, icache_if_packet[2].valid:%b", icache_if_packet[2].inst, icache_if_packet[2].valid);
        $display("---------------------------------------------Fetch--------------------------------------------------------");
        $display("proc2mem_addr:%b proc2Imem_addr:%b", proc2mem_addr, proc2Imem_addr);
        $display("if_PC[0]:%h if_inst[0]:%h if_valid[0]:%b", if_bp_packet[0].PC, if_bp_packet[0].inst, if_bp_packet[0].valid);
        $display("if_PC[1]:%h if_inst[1]:%h if_valid[1]:%b", if_bp_packet[1].PC, if_bp_packet[1].inst, if_bp_packet[1].valid);
        $display("if_PC[2]:%h if_inst[2]:%h if_valid[2]:%b", if_bp_packet[2].PC, if_bp_packet[2].inst, if_bp_packet[2].valid);
        $display("------------------------------------------------BP-------------------------------------------------------");
        $display("original_npc: %h, original_inst: %h, original_valid: %b", if_bp_packet[0].NPC, if_bp_packet[0].inst, if_bp_packet[0].valid);
        $display("bp_PC[0]:%h, bp_NPC[0]:%h, bp_inst[0]:%h, bp_valid[0]:%b, bp_if_npc:%h", bp_ib_packet[0].PC, bp_ib_packet[0].NPC, bp_ib_packet[0].inst, bp_ib_packet[0].valid, bp_npc);
        $display("bp_PC[1]:%h, bp_NPC[1]:%h, bp_inst[1]:%h, bp_valid[1]:%b, bp_if_npc:%h", bp_ib_packet[1].PC, bp_ib_packet[1].NPC, bp_ib_packet[1].inst, bp_ib_packet[1].valid, bp_npc);
        $display("bp_PC[0]:%h, bp_NPC[2]:%h, bp_inst[2]:%h, bp_valid[2]:%b, bp_if_npc:%h", bp_ib_packet[2].PC, bp_ib_packet[2].NPC, bp_ib_packet[2].inst, bp_ib_packet[2].valid, bp_npc);
        $display("------------------------------------------------IB-------------------------------------------------------");
        $display("ib_PC[0]:%h, ib_NPC[0]:%h, ib_inst[0]:%h, ib_valid[0]:%b, insn_buffer_stall:%b", ib_dp_packet[0].PC, ib_dp_packet[0].NPC, ib_dp_packet[0].inst, ib_dp_packet[0].valid, insn_buffer_stall);
        $display("ib_PC[1]:%h, ib_NPC[1]:%h, ib_inst[1]:%h, ib_valid[1]:%b, insn_buffer_stall:%b", ib_dp_packet[1].PC, ib_dp_packet[1].NPC, ib_dp_packet[1].inst, ib_dp_packet[1].valid, insn_buffer_stall);
        $display("ib_PC[2]:%h, ib_NPC[2]:%h, ib_inst[2]:%h, ib_valid[2]:%b, insn_buffer_stall:%b", ib_dp_packet[2].PC, ib_dp_packet[2].NPC, ib_dp_packet[2].inst, ib_dp_packet[2].valid, insn_buffer_stall);
        //$display("------------------------------------------------Dispatch-------------------------------------------------");
        // $display("ib_NPC[0]:%h ib_inst[0]:%h ib_valid[0]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[0], if_inst_dbg[0], if_valid_dbg[0], rob_if_packet.empty_num, rs_if_packet.empty_num);
        // $display("ib_NPC[1]:%h ib_inst[1]:%h ib_valid[1]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[1], if_inst_dbg[1], if_valid_dbg[1], rob_if_packet.empty_num, rs_if_packet.empty_num);
        // $display("ib_NPC[2]:%h ib_inst[2]:%h ib_valid[2]:%b, rob_empty_num:%d, rs_empty_num: %d", if_NPC_dbg[2], if_inst_dbg[2], if_valid_dbg[2], rob_if_packet.empty_num, rs_if_packet.empty_num);
        //$display("dp_NPC[0]:%h dp_inst[0]:%h dp_valid[0]:%b, dp_rs1_value[0]: %d, dp_rs2_value[0]: %d", dp_packet_out[0].NPC, dp_packet_out[0].inst, ~dp_packet_out[0].illegal, dp_packet_out[0].rs1_value, dp_packet_out[0].rs2_value);
        //$display("dp_NPC[1]:%h dp_inst[1]:%h dp_valid[1]:%b, dp_rs1_value[1]: %d, dp_rs2_value[1]: %d", dp_packet_out[1].NPC, dp_packet_out[1].inst, ~dp_packet_out[1].illegal, dp_packet_out[1].rs1_value, dp_packet_out[0].rs2_value);
        //$display("dp_NPC[2]:%h dp_inst[2]:%h dp_valid[2]:%b, dp_rs1_value[2]: %d, dp_rs2_value[0]: %d", dp_packet_out[2].NPC, dp_packet_out[2].inst, ~dp_packet_out[2].illegal, dp_packet_out[1].rs1_value, dp_packet_out[0].rs2_value);
        $display("------------------------------------------------ISSUE--------------------------------------------------------");
        $display("ROB_EMPTY_#: %d, RS_EMPTY_#: %d", rob_if_packet.empty_num, rs_if_packet.empty_num);
        $display("is_NPC[0]:%h is_inst[0]:%h is_valid[0]:%b is_tag[0]:%h, is_value[0].rs1_value: %h, is_value[0].rs2_value: %h, is_sq_position[0]: %b", is_NPC_dbg[0], is_inst_dbg[0], is_valid_dbg[0], is_ex_reg[0].T, is_ex_reg[0].rs1_value, is_ex_reg[0].rs2_value, is_ex_reg[0].sq_position);
        $display("is_NPC[1]:%h is_inst[1]:%h is_valid[1]:%b is_tag[1]:%h, is_value[1].rs1_value: %h, is_value[1].rs2_value: %h, is_sq_position[1]: %b", is_NPC_dbg[1], is_inst_dbg[1], is_valid_dbg[1], is_ex_reg[1].T, is_ex_reg[1].rs1_value, is_ex_reg[1].rs2_value, is_ex_reg[1].sq_position);
        $display("is_NPC[2]:%h is_inst[2]:%h is_valid[2]:%b is_tag[2]:%h, is_value[2].rs1_value: %h, is_value[2].rs2_value: %h, is_sq_position[2]: %b", is_NPC_dbg[2], is_inst_dbg[2], is_valid_dbg[2], is_ex_reg[2].T, is_ex_reg[2].rs1_value, is_ex_reg[2].rs2_value, is_ex_reg[2].sq_position);
        $display("------------------------------------------------EX--------------------------------------------------------");
        $display("cdb_NPC[0]:%h cdb_valid[0]:%b cdb_tag[0]:%h, cdb_rob_packet[0].value: %h", cdb_NPC_dbg[0], cdb_valid_dbg[0], cdb_rob_packet[0].tag, cdb_rob_packet[0].value);
        $display("cdb_NPC[1]:%h cdb_valid[1]:%b cdb_tag[1]:%h, cdb_rob_packet[1].value: %h", cdb_NPC_dbg[1], cdb_valid_dbg[1], cdb_rob_packet[1].tag, cdb_rob_packet[1].value);
        $display("cdb_NPC[2]:%h cdb_valid[2]:%b cdb_tag[2]:%h, cdb_rob_packet[2].value: %h", cdb_NPC_dbg[2], cdb_valid_dbg[2], cdb_rob_packet[2].tag, cdb_rob_packet[2].value);
        $display("------------------------------------------------RT--------------------------------------------------------");
        $display("rt_NPC[0]:%h rt_valid[0]:%b", rt_NPC_dbg[0], rt_valid_dbg[0]);
        $display("rt_NPC[1]:%h rt_valid[1]:%b", rt_NPC_dbg[1], rt_valid_dbg[1]);
        $display("rt_NPC[2]:%h rt_valid[2]:%b", rt_NPC_dbg[2], rt_valid_dbg[2]);
        $display("----------------------------------------------OUTPUT------------------------------------------------------");
        $display("wr_idx[0]:%h wr_data[0]:%h wr_en[0]:%b", pipeline_commit_wr_idx[0], pipeline_commit_wr_data[0], pipeline_commit_wr_en[0]); 
        $display("wr_idx[1]:%h wr_data[1]:%h wr_en[1]:%b", pipeline_commit_wr_idx[1], pipeline_commit_wr_data[1], pipeline_commit_wr_en[1]); 
        $display("wr_idx[2]:%h wr_data[2]:%h wr_en[2]:%b", pipeline_commit_wr_idx[2], pipeline_commit_wr_data[2], pipeline_commit_wr_en[2]);
	//$display("squash_pc:%h if_ic_addr:%h ", squash_pc, if_ic_addr);
        $display("halt:%b", halt);
        $display("-------------------------------------------------------------------------------------------------------------\n"); 
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
        if (proc2Dmem_command != BUS_NONE) begin // read or write DATA from memory
            proc2mem_command = proc2Dmem_command;
            proc2mem_addr    = proc2Dmem_addr;
            // proc2mem_size    = proc2Dmem_size;  // size is never DOUBLE in project 3
        end else begin                          // read an INSTRUCTION from memory
            proc2mem_command = Icache2Imem_command;
            proc2mem_addr    = proc2Imem_addr;
            // proc2mem_size    = DOUBLE;          // instructions load a full memory line (64 bits)
        end
        proc2mem_data = {32'b0, proc2Dmem_data};
    end

    //////////////////////////////////////////////////
    //                                              //
    //                    ICache                    //
    //                                              //
    //////////////////////////////////////////////////
    icache_2way icache0(
        .clock(clock),
        .reset(reset),
        //From mem
        .Imem2proc_response(mem2proc_response),
        .Imem2proc_data(mem2proc_data),
        .Imem2proc_tag(mem2proc_tag),
        // From fetch stage
        .proc2Icache_addr(if_ic_addr[0]),
        //From Dcache
        .Dcache_on_bus(d_i_busy),
        
        // Outputs
        // To mem
        .proc2Imem_command(Icache2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),
        // To fetch
        .icache_if_packet_out(icache_if_packet)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  IF-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    stage_if stage_if0(
        .clock(clock),
		.reset(reset),
        .squash_flag(squash_flag),
        .squash_pc(squash_pc),
        .bp_npc(bp_npc_reg),
        .Icache_if_packet_in(icache_if_packet), // data coming back from Instruction memory
        .insn_buffer_stall(insn_buffer_stall),

        // Outputs
        .if_dp_packet_out(if_bp_packet),
		.PC_reg(if_ic_addr)
        
    );
    //////////////////////////////////////////////////
    //                                              //
    //           Banch Prediction (BP)              //
    //                                              //
    //////////////////////////////////////////////////

    BP BP0(
        .clock(clock), 
        .reset(reset),
        .squash_flag(squash_flag),
        .squash_pc(squash_pc),
        .if_packet_in(if_bp_packet),    // pc from if stage
        .ex_bp_packet_in(ex_bp_packet),
        
        // Outputs
        .bp_packet_out(bp_ib_packet),
        .bp_npc_out(bp_npc) // TO ICACHE

    );

    always_ff @(posedge clock) begin
        if (reset) begin
            bp_npc_reg <= 0;
        end else if(squash_flag) begin
            bp_npc_reg <= squash_pc;
        end else begin
            bp_npc_reg <= bp_npc;
        end
    end
    

    //////////////////////////////////////////////////
    //                                              //
    //                inst-buffer                   //
    //                                              //
    //////////////////////////////////////////////////
    
    insn_buffer insn_buffer0 (
		.clock(clock),
		.enable(1'b1), // sq_full
		.reset(reset),
		.squash_flag(squash_flag),
		.if_packet_in(bp_ib_packet),
		.ROB_blank_number(rob_if_packet.empty_num),
		.RS_blank_number(rs_if_packet.empty_num),
        .SQ_full(sq_full),

		.ib_dp_packet_out(ib_dp_packet),
		.insn_buffer_full(insn_buffer_stall)
	);

    // debug outputs

    // assign if_NPC_dbg   = (if_dp_packet[2].valid) ? if_dp_packet[2].NPC : (if_dp_packet[1].valid) ? if_dp_packet[1].NPC : (if_dp_packet[0].valid) ?
	// 			if_dp_packet[0].NPC : {`XLEN{1'b0}};
    // assign if_inst_dbg  = (if_dp_packet[2].valid) ? if_dp_packet[2].inst : (if_dp_packet[1].valid) ? if_dp_packet[1].inst : (if_dp_packet[0].valid) ?
	// 			if_dp_packet[0].inst : `NOP;
    // assign if_valid_dbg = if_dp_packet[0].valid;

    assign if_NPC_dbg[0]   = if_bp_packet[0].NPC;
    assign if_NPC_dbg[1]   = if_bp_packet[1].NPC;
    assign if_NPC_dbg[2]   = if_bp_packet[2].NPC;
    assign if_inst_dbg[0]  = if_bp_packet[0].inst;
    assign if_inst_dbg[1]  = if_bp_packet[1].inst;
    assign if_inst_dbg[2]  = if_bp_packet[2].inst;
    assign if_valid_dbg[0] = if_bp_packet[0].valid;
    assign if_valid_dbg[1] = if_bp_packet[1].valid;
    assign if_valid_dbg[2] = if_bp_packet[2].valid;
    //////////////////////////////////////////////////
    //                                              //
    //                  DP                          //
    //                                              //
    //////////////////////////////////////////////////
    // DP_PACKET [2:0] dp_reg;


    DP dp0 (
        // input
        .clock(clock),
        .reset(reset),
        .if_id_packet(ib_dp_packet),
        .rt_packet(rt_dp_packet),

        // output
        .dp_packet(dp_packet_out)
    );

// always_ff @(posedge clock) begin
//     if(reset) begin
//         dp_packet_out <= 0;
//     end else begin
//         dp_packet_out <= dp_reg;
//     end

// end
    

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
        .rt_packet(rt_mt_packet),
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
        .sq_tail_in(sq_tail),
        
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
                FUNC_NOP,			//func_unit
		        {$clog2(`SQ_SIZE){1'b0}}
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
		        FUNC_NOP,			//func_unit
		        {$clog2(`SQ_SIZE){1'b0}}
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
                FUNC_NOP,			//func_unit
		        {$clog2(`SQ_SIZE){1'b0}}
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

    always_comb begin
        $display("---------Enterring EX------------");
        $display("DP_packet[0].inst: %h, DP_packet[0].valid:%b, DP_packet[0].rd_mem:%b, DP_packet[0].wr_mem:%b", dp_packet_out[0].inst, dp_packet_out[0].valid, dp_packet_out[0].rd_mem, dp_packet_out[0].wr_mem);
        $display("DP_packet[1].inst: %h, DP_packet[1].valid:%b, DP_packet[1].rd_mem:%b, DP_packet[1].wr_mem:%b", dp_packet_out[1].inst, dp_packet_out[1].valid, dp_packet_out[1].rd_mem, dp_packet_out[1].wr_mem);
        $display("DP_packet[2].inst: %h, DP_packet[2].valid:%b, DP_packet[2].rd_mem:%b, DP_packet[2].wr_mem:%b", dp_packet_out[2].inst, dp_packet_out[2].valid, dp_packet_out[2].rd_mem, dp_packet_out[2].wr_mem);
        $display("----------------------------------");
    end

    EX stage_ex0(
        .clock(clock),
        .reset(reset),
        .clear(squash_flag),
        .IS_packet(is_ex_reg),
        .DP_packet(dp_packet_out),
        .RT_packet(rt_lsq_packet),
        .Dmem2proc_response(mem2proc_response),
        .Dmem2proc_data(mem2proc_data),
        .Dmem2proc_tag(mem2proc_tag),

        // Outputs
        .FU_empty_packet(fu_empty_packet),
        .EX_packet(ex_cp_packet), 
        // LSQ stuff
        .SQ_tail(sq_tail),
        .SQ_full(sq_full), // to instruction buffer
        .icache_busy(d_i_busy),
        .rt_busy(rt_busy),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        .proc2Dmem_command(proc2Dmem_command),
        .dcache_table(dcache_table_out),
        .EX_BP_packet(ex_bp_packet)
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

    stage_rt rt_stage0(
    // Inputs
    .clock(clock),
    .reset(reset),
    .rob_rt_packet_in(rob_rt_packet),
    .rt_busy(rt_busy),
    
    // Outputs
    .rt_dp_packet_out(rt_dp_packet),
    .rt_mt_packet_out(rt_mt_packet), // retire_tag, valid
    // to LSQ
    .rt_lsq_packet_out(rt_lsq_packet), // retire_tag, valid
    // when interruptions occur, clear to the last insts having finished Retire
    .valid(rt_valid),
    .NPC(rt_NPC),
    .halt(halt),
    .squash_pc(squash_pc),
    .squash_flag(squash_flag)
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
    assign pipeline_error_status = (halt) ? HALTED_ON_WFI : NO_ERROR;

    assign pipeline_commit_wr_en[0]   = rt_dp_packet[0].valid;
    assign pipeline_commit_wr_en[1]   = rt_dp_packet[1].valid;
    assign pipeline_commit_wr_en[2]   = rt_dp_packet[2].valid;
    assign pipeline_commit_wr_idx[0]  = rt_dp_packet[0].retire_reg;
    assign pipeline_commit_wr_idx[1]  = rt_dp_packet[1].retire_reg;
    assign pipeline_commit_wr_idx[2]  = rt_dp_packet[2].retire_reg;
    assign pipeline_commit_wr_data[0] = rt_dp_packet[0].value;
    assign pipeline_commit_wr_data[1] = rt_dp_packet[1].value;
    assign pipeline_commit_wr_data[2] = rt_dp_packet[2].value;
    assign pipeline_commit_NPC[0]     = (rt_valid[0]) ? rt_NPC[0] : {`XLEN{1'b0}};
    assign pipeline_commit_NPC[1]     = (rt_valid[1]) ? rt_NPC[1] : {`XLEN{1'b0}};
    assign pipeline_commit_NPC[2]     = (rt_valid[2]) ? rt_NPC[2] : {`XLEN{1'b0}};

endmodule // pipeline
