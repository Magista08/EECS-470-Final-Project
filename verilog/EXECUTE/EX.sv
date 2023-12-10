`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module EX (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input RS_IS_PACKET [2:0]                              IS_packet,
    // LSQ stuff
    input DP_PACKET [2:0]                                 DP_packet,
    input RT_LSQ_PACKET [2:0]                             RT_packet,
    
    input [3:0] Dmem2proc_response,
    input [63:0] Dmem2proc_data,
    input [3:0] Dmem2proc_tag,


    // to RS
    output FU_EMPTY_PACKET                                FU_empty_packet,

    // to Fetch
    // output BRANCH_PACKET [2:0]                            Branch_packet, // branch_taken, bp_pc
    
    // to CDB and Fetch (maybe CDB to fetch?)
    output EX_PACKET [2:0]                                EX_packet, // tag, value, valid, NPC, halt

    // // debug
    // output logic [`NUM_FU_ALU-1:0] [`XLEN-1:0]            ALU_result,
    // output logic [`NUM_FU_MULT-1:0] [`XLEN-1:0]           MULT_result,
    // output RS_IS_PACKET [`NUM_FU_ALU-1:0]                 ALU_input,
    // output RS_IS_PACKET [`NUM_FU_MULT-1:0]                MULT_input
    // output logic [`NUM_FU_MULT-1:0]                       MULT_buffer_busy,
    // output logic [`NUM_FU_MULT-1:0]                       MULT_busy,
    // output logic [`NUM_FU_ALU-1:0]                        ALU_buffer_busy,
    // output logic [`NUM_FU_ALU-1:0]                        ALU_busy

    // LSQ stuff
    output logic [2:0] [$clog2(`SQ_SIZE)-1:0]             SQ_tail, // to RS
    output logic                                          SQ_full, // to instruction buffer

    output logic icache_busy,
    output logic rt_busy,
    output logic rob_busy,
    output logic [`XLEN-1:0] proc2Dmem_addr,
    output logic [63:0] proc2Dmem_data,
    output logic [1:0] proc2Dmem_command,
    output DCACHE_SET [`DCACHE_SET_NUM-1:0] dcache_table,
    output EX_BP_PACKET [2:0]                             EX_BP_packet

);

    logic [`NUM_FU_ALU-1:0] [$clog2(`ROBLEN)-1:0]         ALU_tag;
    logic [`NUM_FU_MULT-1:0] [$clog2(`ROBLEN)-1:0]        MULT_tag;

    RS_IS_PACKET [`NUM_FU_ALU-1:0]                        ALU_input;
    RS_IS_PACKET [`NUM_FU_MULT-1:0]                       MULT_input;

    logic [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_result;
    logic [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_result;

    logic [`NUM_FU_ALU-1:0]                               ALU_busy;
    logic [`NUM_FU_MULT-1:0]                              MULT_busy;

    logic [`NUM_FU_ALU-1:0]                               ALU_result_ready;
    logic [`NUM_FU_MULT-1:0]                              MULT_result_ready;

    logic [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_NPC; // PC + 4
    logic [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_NPC; // PC + 4

    logic [`NUM_FU_ALU-1:0]                               ALU_halt; // stop
    logic [`NUM_FU_MULT-1:0]                              MULT_halt; // stop

    logic [2:0]                                           ALU_branch_taken; // emm


    logic [2:0]                                           CDB_halt;
    logic [2:0] [`XLEN-1:0]                               CDB_NPC;
    logic [2:0] [$clog2(`ROBLEN)-1:0]                     CDB_tag;
    logic [2:0] [`XLEN-1:0]                               CDB_value;
    logic [2:0]                                           CDB_valid;
    logic [2:0]                                           CDB_branch_taken; // emm

    logic [`NUM_FU_ALU-1:0]                               ALU_buffer_busy;
    logic [`NUM_FU_MULT-1:0]                              MULT_buffer_busy;
    logic [`NUM_FU_MEM-1:0]                               MEM_buffer_busy;
    logic                                                 LSQ_buffer_busy;

    // FU_load_store stuff
    RS_IS_PACKET [`NUM_FU_MEM-1:0]                        FU_LOAD_STORE_in;
    SQ_LINE [`NUM_FU_MEM-1:0]                             FU_LOAD_STORE_out;
    logic [2:0] [$clog2(`SQ_SIZE)-1:0]                    sq_position;
    // SQ stuff
    EX_PACKET                                             SQ_COMP_packet;
    LSQ_DCACHE_PACKET                                     SQ_DC_packet;
    DCACHE_LSQ_PACKET [1:0]                               DC_SQ_packet;

    logic [`NUM_FU_MEM-1:0] [`XLEN-1:0]                   ST_NPC;
    logic [`NUM_FU_MEM-1:0] [`XLEN-1:0]                   ST_result;
    logic [`NUM_FU_MEM-1:0]                               ST_result_ready;
    logic [`NUM_FU_MEM-1:0]                               ST_halt;
    logic [`NUM_FU_MEM-1:0] [$clog2(`ROBLEN)-1:0]         ST_tag;


    logic [`XLEN-1:0] ld_in_num;
    logic [`XLEN-1:0] st_in_num;
    logic [`XLEN-1:0] n_ld_in_num;
    logic [`XLEN-1:0] n_st_in_num;

    // generate FU's
    genvar a;
    generate
        for (a=0; a<`NUM_FU_ALU; a=a+1) begin
            FU_ALU FU_ALU_0 ( 
                .clock(clock), 
                .reset(reset), 
                .clear(clear),
                .fu_input(ALU_input[a]),

                .halt(ALU_halt[a]),
                .NPC(ALU_NPC[a]),
                .tag(ALU_tag[a]),
                .result(ALU_result[a]), 
                .busy(ALU_busy[a]),
                .result_ready(ALU_result_ready[a]),
                .branch_taken(ALU_branch_taken[a]),
                .EX_BP_packet_out(EX_BP_packet[a])
            );
        end
    endgenerate

    genvar b;
    generate
        for (b=0; b<`NUM_FU_MULT; b=b+1) begin
            FU_MULT FU_MULT_0 ( 
                .clock(clock), 
                .reset(reset), 
                .clear(clear),
                .fu_input(MULT_input[b]),

                .halt(MULT_halt[b]),
                .NPC(MULT_NPC[b]),
                .tag(MULT_tag[b]),
                .result(MULT_result[b]), 
                .busy(MULT_busy[b]),
                .result_ready(MULT_result_ready[b])
            );
        end
    endgenerate

    genvar c;
    generate
        for (c=0; c<`NUM_FU_MEM; c=c+1) begin
            FU_LOAD_STORE FU_LOAD_STORE_0 (
                .clock(clock), 
                .reset(reset), 
                .clear(clear),
                .fu_input(FU_LOAD_STORE_in[c]),


                .halt(ST_halt[c]),
                .NPC(ST_NPC[c]),
                .tag(ST_tag[c]),
                .result(ST_result[c]),
                .result_ready(ST_result_ready[c]),

                .FU_LOAD_STORE_out(FU_LOAD_STORE_out[c]),
                .sq_position(sq_position[c])
            );
        end
    endgenerate


    // give each FU input
    always_comb begin
        // set initial values to avoid latch
        for (int jj=0; jj<`NUM_FU_ALU; jj=jj+1) begin
            ALU_input[jj] = {
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
                1'b0,                    // valid
                FUNC_ALU,                 // FUNC_UNIT
		        {$clog2(`SQ_SIZE){1'b0}}
            };
        end
        for (int kk=0; kk<`NUM_FU_MULT; kk=kk+1) begin
            MULT_input[kk] = {
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
                1'b0,                    // valid
                FUNC_ALU,                 // FUNC_UNIT
		        {$clog2(`SQ_SIZE){1'b0}}
            };
        end

        for (int mem_i=0; mem_i<`NUM_FU_MEM; mem_i=mem_i+1) begin
            FU_LOAD_STORE_in[mem_i] = {
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
                1'b0,                    // valid
                FUNC_ALU,                 // FUNC_UNIT
		        {$clog2(`SQ_SIZE){1'b0}}
            };
        end

        // They will never be busy so...
        // So I assign each way an FU (How can I add more FU's ?)
        n_ld_in_num = ld_in_num;
	n_st_in_num = st_in_num;
        for (int i=0; i<3; i=i+1) begin
            // if (IS_packet[i].illegal == 0) begin // change to nop?
            if (!IS_packet[i].illegal) begin // Maybe they don't want me to use NOP
		        if (IS_packet[i].func_unit == FUNC_ALU) begin
                    ALU_input[i] = IS_packet[i];  
                    // $display("-------ALU--------");                  
                end else if (IS_packet[i].func_unit == FUNC_MUL) begin
                    MULT_input[i] = IS_packet[i];
                    // $display("-------mul--------");
                end else if (IS_packet[i].func_unit == FUNC_MEM) begin
                    FU_LOAD_STORE_in[i] = IS_packet[i];
		    if(IS_packet[i].rd_mem == 1) begin
			n_ld_in_num = n_ld_in_num+1;
		    end 
		    if(IS_packet[i].wr_mem == 1) begin
			n_st_in_num = n_st_in_num+1;
		    end
                    // $display("-------mem--------");
                end
            end
        end

    end

    // always_comb begin
    //     $display("---From EX---");
    //     $display("DP_packet[0].NPC:%h, DP_packet[0].inst:%h, DP_packet[0].wr_en:%b DP_packet[0].rd_en:%b", DP_packet[0].NPC, DP_packet[0].inst, DP_packet[0].wr_mem, DP_packet[0].rd_mem);
    //     $display("DP_packet[1].NPC:%h, DP_packet[1].inst:%h, DP_packet[1].wr_en:%b DP_packet[1].rd_en:%b", DP_packet[1].NPC, DP_packet[1].inst, DP_packet[1].wr_mem, DP_packet[1].rd_mem);
    //     $display("DP_packet[2].NPC:%h, DP_packet[2].inst:%h, DP_packet[2].wr_en:%b DP_packet[2].rd_en:%b", DP_packet[2].NPC, DP_packet[2].inst, DP_packet[2].wr_mem, DP_packet[2].rd_mem);
    //     $display("--------------------------------");
    // end

    // put stuff into SQ
    LSQ lsq_0 (
        .clock(clock),
        .reset(reset),
        .clear(clear),
        .DP_packet(DP_packet),
        .LOAD_STORE_input(FU_LOAD_STORE_out),
        .position(sq_position),
        .RT_packet(RT_packet),
        .DC_SQ_packet(DC_SQ_packet),
        .LSQ_buffer_busy(LSQ_buffer_busy),
        
        .SQ_tail(SQ_tail),
        .SQ_full(SQ_full),
        .SQ_COMP_packet(SQ_COMP_packet),
        .SQ_DC_packet(SQ_DC_packet)
    );

    // DCache to be added
    DCACHE DCache_0 (
        .clock(clock),
        .reset(reset),
        .squash_flag(clear),
        .lsq_packet_in(SQ_DC_packet),
        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_tag(Dmem2proc_tag),

        .lsq_packet_out(DC_SQ_packet),
        .icache_busy(icache_busy),
        .rt_busy(rt_busy),
        .rob_busy(rob_busy),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        .proc2Dmem_command(proc2Dmem_command),
        .dcache_table(dcache_table)
    );


    // put stuff into FU_empty_packet
    assign FU_empty_packet.ALU_empty = ~(ALU_buffer_busy);
    assign FU_empty_packet.MULT_empty = ~(MULT_buffer_busy);
    assign FU_empty_packet.MEM_empty = ~(MEM_buffer_busy);
    assign FU_empty_packet.LSQ_empty = ~(LSQ_buffer_busy);

    // put stuff into EX_packet
    complete_buffer complete_buffer_0 (
        .clock(clock),
        .reset(reset),
        .clear(clear),
        .ALU_result(ALU_result),
        .MULT_result(MULT_result),
        .ALU_result_ready(ALU_result_ready),
        .MULT_result_ready(MULT_result_ready),
        .ALU_tag(ALU_tag),
        .MULT_tag(MULT_tag),
        .ALU_branch_taken(ALU_branch_taken),
        .ALU_NPC(ALU_NPC),
        .MULT_NPC(MULT_NPC),
        .ALU_halt(ALU_halt),
        .MULT_halt(MULT_halt),
        .SQ_COMP_packet(SQ_COMP_packet), // LSQ (LD)
        .ST_NPC(ST_NPC), // FU ST
        .ST_result(ST_result), // FU ST
        .ST_result_ready(ST_result_ready), // FU ST
        .ST_halt(ST_halt), // FU ST
        .ST_tag(ST_tag), // FU ST

        .CDB_halt(CDB_halt),
        .CDB_NPC(CDB_NPC),
        .CDB_tag(CDB_tag),
        .CDB_value(CDB_value),
        .CDB_valid(CDB_valid),
        .CDB_branch_taken(CDB_branch_taken),
        .ALU_buffer_busy(ALU_buffer_busy),
        .MULT_buffer_busy(MULT_buffer_busy),
        .MEM_buffer_busy(MEM_buffer_busy), // ST
        .LSQ_buffer_busy(LSQ_buffer_busy) // LD
    );

    assign EX_packet[0].T = CDB_tag[0];
    assign EX_packet[1].T = CDB_tag[1];
    assign EX_packet[2].T = CDB_tag[2];

    assign EX_packet[0].value = CDB_value[0];
    assign EX_packet[1].value = CDB_value[1];
    assign EX_packet[2].value = CDB_value[2];

    assign EX_packet[0].valid = CDB_valid[0];
    assign EX_packet[1].valid = CDB_valid[1];
    assign EX_packet[2].valid = CDB_valid[2];

    assign EX_packet[0].branch_taken = CDB_branch_taken[0];
    assign EX_packet[1].branch_taken = CDB_branch_taken[1];
    assign EX_packet[2].branch_taken = CDB_branch_taken[2];

    assign EX_packet[0].NPC = CDB_NPC[0];
    assign EX_packet[1].NPC = CDB_NPC[1];
    assign EX_packet[2].NPC = CDB_NPC[2];

    assign EX_packet[0].halt = CDB_halt[0];
    assign EX_packet[1].halt = CDB_halt[1];
    assign EX_packet[2].halt = CDB_halt[2];


    always_ff @(posedge clock) begin
	if(reset) begin
		ld_in_num <= 0;
	  	st_in_num <= 0;
	end else begin
		ld_in_num <= n_ld_in_num;
		st_in_num <= n_st_in_num;
	end
	$display("ld_in_num:%h st_in_num:%h", ld_in_num, st_in_num);
    end

endmodule


// No need to consider order here, just choose 3
module complete_buffer (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_result,
    input [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_result,
    input [`NUM_FU_ALU-1:0]                               ALU_result_ready,
    input [`NUM_FU_MULT-1:0]                              MULT_result_ready,
    input [`NUM_FU_ALU-1:0] [$clog2(`ROBLEN)-1:0]         ALU_tag,
    input [`NUM_FU_MULT-1:0] [$clog2(`ROBLEN)-1:0]        MULT_tag,
    input [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_NPC,
    input [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_NPC,
    input [`NUM_FU_ALU-1:0]                               ALU_halt,
    input [`NUM_FU_MULT-1:0]                              MULT_halt,
    input [`NUM_FU_ALU-1:0]                               ALU_branch_taken,
    // LSQ stuff
    input EX_PACKET                                       SQ_COMP_packet,
    input [`NUM_FU_MEM-1:0] [`XLEN-1:0]                   ST_NPC,
    input [`NUM_FU_MEM-1:0] [`XLEN-1:0]                   ST_result,
    input [`NUM_FU_MEM-1:0]                               ST_result_ready,
    input [`NUM_FU_MEM-1:0]                               ST_halt,
    input [`NUM_FU_MEM-1:0] [$clog2(`ROBLEN)-1:0]         ST_tag,
    

    output logic [2:0] [$clog2(`ROBLEN)-1:0]              CDB_tag,
    output logic [2:0] [`XLEN-1:0]                        CDB_value,
    output logic [2:0]                                    CDB_valid,
    output logic [2:0]                                    CDB_branch_taken,
    output logic [2:0] [`XLEN-1:0]                        CDB_NPC,
    output logic [2:0]                                    CDB_halt,

    output logic                                          LSQ_buffer_busy,
    output logic [`NUM_FU_ALU-1:0]                        ALU_buffer_busy,
    output logic [`NUM_FU_MULT-1:0]                       MULT_buffer_busy,
    output logic [`NUM_FU_MEM-1:0]                        MEM_buffer_busy
);

    EX_PACKET [`CompBuff_SIZE-1:0]                        buffer, next_buffer;
    logic     [`CompBuff_SIZE-1:0]                        buffer_halt;

    logic [2:0]                                           next_CDB_halt;   
    logic [2:0] [`XLEN-1:0]                               next_CDB_NPC;
    logic [2:0] [$clog2(`ROBLEN)-1:0]                     next_CDB_tag;
    logic [2:0] [`XLEN-1:0]                               next_CDB_value;
    logic [2:0]                                           next_CDB_valid;
    logic [2:0]                                           next_CDB_branch_taken;
    
    genvar cp_i;
    generate
        for (cp_i=0; cp_i<`CompBuff_SIZE; cp_i=cp_i+1) begin
            assign buffer_halt[cp_i] = buffer[cp_i].valid;
        end
    endgenerate

    always_ff @(posedge clock) begin
        $display("buffer_halt: %b", buffer_halt);
    end
	logic [`XLEN-1:0] ld_out_num;
    logic [`XLEN-1:0] st_out_num;
    logic [`XLEN-1:0] n_ld_out_num;
    logic [`XLEN-1:0] n_st_out_num;

    // assign function unit outputs to the buffer
    always_comb begin
        next_buffer = buffer;
        next_CDB_halt = 0;
        next_CDB_NPC = 0;
        next_CDB_tag = 0; // clear CDB at every cycle
        next_CDB_value = 0;
        next_CDB_valid = 0;
        next_CDB_branch_taken = 0;

        ALU_buffer_busy = 0;
        MULT_buffer_busy = 0;

        if (clear) begin
            next_buffer = 0;
            next_CDB_halt = 0;
            next_CDB_NPC = 0;
            next_CDB_tag = 0;
            next_CDB_value = 0;
            next_CDB_valid = 0;
            next_CDB_branch_taken = 0;

        end else begin
            for (int i=0; i<`NUM_FU_MULT; i=i+1) begin
                if (MULT_result_ready[i] && ~next_buffer[i].valid) begin
                    next_buffer[i].halt = MULT_halt[i];
                    next_buffer[i].NPC = MULT_NPC[i];
                    next_buffer[i].T = MULT_tag[i];
                    next_buffer[i].value = MULT_result[i];
                    next_buffer[i].valid = 1;
                    next_buffer[i].branch_taken = 0;
			        $display("--------MULT------------");
                end
            end
            for (int j=0; j<`NUM_FU_ALU; j=j+1) begin
                if (ALU_result_ready[j] && ~next_buffer[j+`NUM_FU_MULT].valid) begin
                    next_buffer[j+`NUM_FU_MULT].halt = ALU_halt[j];
                    next_buffer[j+`NUM_FU_MULT].NPC = ALU_NPC[j];
                    next_buffer[j+`NUM_FU_MULT].T = ALU_tag[j];
                    next_buffer[j+`NUM_FU_MULT].value = ALU_result[j];
                    next_buffer[j+`NUM_FU_MULT].valid = 1;
                    next_buffer[j+`NUM_FU_MULT].branch_taken = ALU_branch_taken[j];
			        $display("--------ALU------------");
                end
            end
		n_ld_out_num = ld_out_num;
		n_st_out_num = st_out_num;
            // LSQ stuff (3 ST for retire and 1 for LD)
            for (int k=0; k<`NUM_FU_MEM; k=k+1) begin
                if (ST_result_ready[k] && ~next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].valid) begin
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].halt = ST_halt[k];
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].NPC = ST_NPC[k];
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].T = ST_tag[k];
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].value = ST_result[k];
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].valid = 1;
                    next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].branch_taken = 0;
		n_st_out_num = n_st_out_num + 1;
                    //$display("--------STfromFU------------");
                end
            end
            if (SQ_COMP_packet.valid && ~next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].valid) begin
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].halt = SQ_COMP_packet.halt;
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].NPC = SQ_COMP_packet.NPC;
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].T = SQ_COMP_packet.T;
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].value = SQ_COMP_packet.value;
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].valid = 1;
                next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].branch_taken = 0;
		n_ld_out_num = n_ld_out_num + 1;
		        //$display("--------LDfromLSQ------------");
            end

            // give information to next CDB and set buffer not valid
            for (int i=0; i<3; i=i+1) begin
                for (int j=0; j<`CompBuff_SIZE; j=j+1) begin
                    if (next_buffer[j].valid) begin
                        next_CDB_halt[i] = next_buffer[j].halt;
                        next_CDB_NPC[i] = next_buffer[j].NPC;
                        next_CDB_tag[i] = next_buffer[j].T;
                        next_CDB_value[i] = next_buffer[j].value;
                        next_CDB_valid[i] = 1;
                        next_CDB_branch_taken[i] = next_buffer[j].branch_taken;

                        next_buffer[j].valid = 0;
			// $display("---------------------------------------------------caonnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnmmmmmmm---------------------------------------------");
                        break;
                    end
                end
            end 

            // give busy information
            for (int i=0; i<`NUM_FU_MULT; i=i+1) begin
                MULT_buffer_busy[i] = next_buffer[i].valid;// next or current
            end
            for (int j=0; j<`NUM_FU_ALU; j=j+1) begin
                ALU_buffer_busy[j] = next_buffer[j+`NUM_FU_MULT].valid;
            end
            for (int k=0; k<`NUM_FU_MEM; k=k+1) begin
                MEM_buffer_busy[k] = next_buffer[k+`NUM_FU_MULT+`NUM_FU_ALU].valid;
            end
            LSQ_buffer_busy = next_buffer[`NUM_FU_MULT+`NUM_FU_ALU+`NUM_FU_MEM].valid; // only one LSQ output here
        end
    end

    // update buffer and CDB
    always_ff @(posedge clock) begin 
        $display("next_buffer[0].value = %h, next_buffer[1].value = %h, next_buffer[2].value = %h, next_buffer[3].value = %h, next_buffer[4].value = %h, next_buffer[5].value = %h, next_buffer[6].value = %h, next_buffer[7].value = %h,next_buffer[8].value = %h,next_buffer[9].value = %h,",next_buffer[0].value, next_buffer[1].value, next_buffer[2].value, next_buffer[3].value, next_buffer[4].value, next_buffer[5].value, next_buffer[6].value, next_buffer[7].value, next_buffer[8].value, next_buffer[9].value);
	    // $display("------next_CDB_valid:%b---------", next_CDB_valid);
        if(reset || clear) begin
            buffer <= 0;
            CDB_halt <= 0;
            CDB_NPC <= 0;
            CDB_tag <= 0;
            CDB_value <= 0;
            CDB_valid <= 0;
            CDB_branch_taken <= 0;
	    ld_out_num <= 0;
	    st_out_num <= 0;
        end
        else begin
            buffer <= next_buffer;
            CDB_halt <= next_CDB_halt;
            CDB_NPC <= next_CDB_NPC;
            CDB_tag <= next_CDB_tag;
            CDB_value <= next_CDB_value;
            CDB_valid <= next_CDB_valid;
	        // $display("------next_CDB_valid:%b---------", next_CDB_valid);
            CDB_branch_taken <= next_CDB_branch_taken;
	    ld_out_num <= n_ld_out_num;
	    st_out_num <= n_st_out_num;
        end
	$display("ld_out_num:%h st_out_num:%h", ld_out_num, st_out_num);
    end 

endmodule
