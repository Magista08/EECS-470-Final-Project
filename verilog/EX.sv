`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"
`include "verilog/FU.sv"

module EX (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input RS_IS_PACKET [2:0]                              IS_packet,

    // to RS
    output FU_EMPTY_PACKET                                FU_empty_packet,

    // to Fetch
    // output BRANCH_PACKET [2:0]                            Branch_packet, // branch_taken, bp_pc
    
    // to CDB and Fetch (maybe CDB to fetch?)
    output EX_PACKET [2:0]                                EX_packet, // tag, value, valid, NPC, halt

    // debug
    // output logic [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_result,
    // output logic [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_result,
    // output RS_IS_PACKET [`NUM_FU_ALU-1:0]                        ALU_input,
    // output RS_IS_PACKET [`NUM_FU_MULT-1:0]                       MULT_input
    // output logic [`NUM_FU_MULT-1:0]                              MULT_buffer_busy,
    // output logic [`NUM_FU_MULT-1:0]                              MULT_busy,
    output logic [`NUM_FU_ALU-1:0]                        ALU_buffer_busy,
    output logic [`NUM_FU_ALU-1:0]                        ALU_busy

    // LSQ stuff to be added

);

    logic [`NUM_FU_ALU-1:0] [$clog2(`ROBLEN)-1:0]         ALU_tag;
    logic [`NUM_FU_MULT-1:0] [$clog2(`ROBLEN)-1:0]        MULT_tag;

    RS_IS_PACKET [`NUM_FU_ALU-1:0]                        ALU_input;
    RS_IS_PACKET [`NUM_FU_MULT-1:0]                       MULT_input;

    logic [`NUM_FU_ALU-1:0] [`XLEN-1:0]                   ALU_result;
    logic [`NUM_FU_MULT-1:0] [`XLEN-1:0]                  MULT_result;

    // logic [`NUM_FU_ALU-1:0]                               ALU_busy;
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

    // logic [`NUM_FU_ALU-1:0]                               ALU_buffer_busy;
    logic [`NUM_FU_MULT-1:0]                              MULT_buffer_busy;

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
                .branch_taken(ALU_branch_taken[a])
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
                1'b0,                    // illegal
                1'b0,                    // csr_op
                1'b0,                    // valid
                FUNC_ALU                 // FUNC_UNIT
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
                1'b0,                    // illegal
                1'b0,                    // csr_op
                1'b0,                    // valid
                FUNC_ALU                 // FUNC_UNIT
            };
        end

        // They will never be busy so...
        // for (int i=0; i<3; i=i+1) begin
        //     // if (IS_packet[i].can_execute) begin
        //     if (IS_packet[i].illegal == 0) begin //???????? change to nop?
		//         if (IS_packet[i].func_unit == FUNC_ALU) begin
        //             for (int j=0; j<`NUM_FU_ALU; j=j+1) begin
        //                 if (~ALU_busy[j]) begin
        //                     ALU_input[j] = IS_packet[i];
        //                     break;
        //                 end
        //             end
        //         end else if (IS_packet[i].func_unit == FUNC_MUL) begin
        //             for (int k=0; k<`NUM_FU_MULT; k=k+1) begin
        //                 if (~MULT_busy[k]) begin
        //                     MULT_input[k] = IS_packet[i];
        //                     break;
        //                 end
        //             end
        //         end
        //     end
        // end

        // So I assign each way an FU (How can I add more FU's ?)
        for (int i=0; i<3; i=i+1) begin
            // if (IS_packet[i].illegal == 0) begin //???????? change to nop?
            if (IS_packet[i].inst != `NOP) begin
		        if (IS_packet[i].func_unit == FUNC_ALU) begin
                    ALU_input[i] = IS_packet[i];                    
                end else if (IS_packet[i].func_unit == FUNC_MUL) begin
                    MULT_input[i] = IS_packet[i];
                end
            end
        end

    end

    // put stuff into FU_empty_packet
    // assign FU_empty_packet.ALU_empty = ~(ALU_busy | ALU_buffer_busy);
    // assign FU_empty_packet.MULT_empty = ~(MULT_busy | MULT_buffer_busy);
    // assign FU_empty_packet.ALU_empty = ~(ALU_busy);
    // assign FU_empty_packet.MULT_empty = ~(MULT_busy);
    assign FU_empty_packet.ALU_empty = ~(ALU_buffer_busy);
    assign FU_empty_packet.MULT_empty = ~(MULT_buffer_busy);

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

        .CDB_halt(CDB_halt),
        .CDB_NPC(CDB_NPC),
        .CDB_tag(CDB_tag),
        .CDB_value(CDB_value),
        .CDB_valid(CDB_valid),
        .ALU_buffer_busy(ALU_buffer_busy),
        .MULT_buffer_busy(MULT_buffer_busy),
        .CDB_branch_taken(CDB_branch_taken)
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

endmodule


// No need to consider order here, just choose 3 (remember to add NPC)
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

    output logic [2:0] [$clog2(`ROBLEN)-1:0]              CDB_tag,
    output logic [2:0] [`XLEN-1:0]                        CDB_value,
    output logic [2:0]                                    CDB_valid,
    output logic [2:0]                                    CDB_branch_taken,
    output logic [2:0] [`XLEN-1:0]                        CDB_NPC,
    output logic [2:0]                                    CDB_halt,

    output logic [`NUM_FU_ALU-1:0]                        ALU_buffer_busy,
    output logic [`NUM_FU_MULT-1:0]                       MULT_buffer_busy
);

    EX_PACKET [`CompBuff_SIZE-1:0]                        buffer, next_buffer;

    logic [2:0]                                           next_CDB_halt;   
    logic [2:0] [`XLEN-1:0]                               next_CDB_NPC;
    logic [2:0] [$clog2(`ROBLEN)-1:0]                     next_CDB_tag;
    logic [2:0] [`XLEN-1:0]                               next_CDB_value;
    logic [2:0]                                           next_CDB_valid;
    logic [2:0]                                           next_CDB_branch_taken;

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
                    // break;
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
                    // break;
                end
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

        end
    end

    // // give busy information
    // always_comb begin
    //     ALU_buffer_busy = 0;
    //     MULT_buffer_busy = 0;

    //     for (int i=0; i<`NUM_FU_MULT; i=i+1) begin
    //         MULT_buffer_busy[i] = buffer[i].valid;// next or current
    //     end
    //     for (int j=0; j<`NUM_FU_ALU; j=j+1) begin
    //         ALU_buffer_busy[j] = buffer[j+`NUM_FU_MULT].valid;
    //     end
    // end

    // update buffer and CDB
    always_ff @(posedge clock) begin 
        if(reset) begin
            buffer <= 0;
            CDB_halt <= 0;
            CDB_NPC <= 0;
            CDB_tag <= 0;
            CDB_value <= 0;
            CDB_valid <= 0;
            CDB_branch_taken <= 0;
        end
        else begin
            // buffer <= next_buffer;
            // CDB_tag <= 0;   // clear CDB at every cycle
            // CDB_value <= 0;
            // CDB_valid <= 0;
            // CDB_branch_taken <= 0;

            // for (int i=0; i<3; i=i+1) begin
            //     for (int j=0; j<`CompBuff_SIZE; j=j+1) begin
            //         if (buffer[j].valid) begin
            //             CDB_tag[i] <= buffer[j].T;
            //             CDB_value[i] <= buffer[j].value;
            //             CDB_valid[i] <= buffer[j].valid; // 1
            //             CDB_branch_taken[i] <= buffer[j].branch_taken;
                        
            //             buffer[j].valid <= 0;
            //             break;
            //         end
            //     end
            // end

            buffer <= next_buffer;
            CDB_halt <= next_CDB_halt;
            CDB_NPC <= next_CDB_NPC;
            CDB_tag <= next_CDB_tag;
            CDB_value <= next_CDB_value;
            CDB_valid <= next_CDB_valid;
            CDB_branch_taken <= next_CDB_branch_taken;

        end
    end 

endmodule