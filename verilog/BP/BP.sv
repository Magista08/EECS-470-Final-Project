`include "verilog/sys_defs.svh"

module BP(
    input  clock, reset,
    input  squash_flag,
    input  logic [`XLEN-1:0] squash_pc,
    input IF_ID_PACKET [`N-1:0] if_packet_in,    // pc from if stage
    input EX_BP_PACKET [`N-1:0] ex_bp_packet_in,
    
    // output logic [`N-1:0] [`XLEN-1:0] bp_pc,
    output IF_ID_PACKET [`N-1:0]    bp_packet_out,
    output logic        [`XLEN-1:0] bp_npc_out
    // output logic        [`N-1:0]    bp_taken_out
);
    // Input Prepare
    logic [`N-1:0]              if_valid;
    logic [`N-1:0] [`XLEN-1:0]  if_pc;

    logic [`N-1:0]              cond_branch_en;
    logic [`N-1:0]              branch_en;
    logic [`N-1:0]              branch_taken;
    logic [`N-1:0] [`XLEN-1:0]  ex_pc;
    logic [`N-1:0] [`XLEN-1:0]  ex_tpc;

    // Pre-decode
    logic [`N-1:0] cond_branch_de, uncond_branch_de;
    logic [`N-1:0] jump, link;
    logic [`N-1:0] [`XLEN-1:0] result;

    // BHT 2 PHT
    logic [`N-1:0] [`BHTWIDTH-1:0] bht_tag_read, bht_tag_write;
    logic [`N-1:0]                  bp_taken;

    // BTB
    logic [`N-1:0] hit;
    logic [`N-1:0] [`XLEN-1:0] predict_pc;
    
    // RAS
    logic push, pop;
    logic [`XLEN-1:0] return_address;

    // output
    // logic [`N-1:0] [`XLEN-1:0] bp_pc, bp_npc_out;
    logic [`N-1:0]    bp_taken_out;
    logic [`XLEN-1:0] bp_last_valid_npc;
    // logic [`XLEN-1:0] bp_npc_out;

    genvar bp_i;
    generate
        for (bp_i=0; bp_i<`N; bp_i++) begin
            assign if_valid[bp_i] = if_packet_in[bp_i].valid;
            assign if_pc[bp_i]    = if_packet_in[bp_i].PC;

            assign cond_branch_en[bp_i] = ex_bp_packet_in[bp_i].cond_branch_en;
            assign branch_en[bp_i]      = ex_bp_packet_in[bp_i].branch_en;
            assign branch_taken[bp_i]   = ex_bp_packet_in[bp_i].cond_branch_taken;
            assign ex_pc[bp_i]          = ex_bp_packet_in[bp_i].PC;
            assign ex_tpc[bp_i]         = ex_bp_packet_in[bp_i].target_PC;
        end
    endgenerate    

    // Pre-decode
    genvar bp_j;
    generate
        for (bp_j=0; bp_j<`N; bp_j++) begin
            pre_decoder PRE_DEC0(
                // Inputs
                .inst(if_packet_in[bp_j].inst),
                .if_valid(if_packet_in[bp_j].valid),
                .pc(if_packet_in[bp_j].PC),

                .cond_branch(cond_branch_de[bp_j]),
                .uncond_branch(uncond_branch_de[bp_j]),
                .jump(jump[bp_j]),
                .link(link[bp_j]),
                .result_out(result[bp_j])
            );
        end
    endgenerate

    // BHT
    BHT bht0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .wr_en_in(cond_branch_en),
        .take_branch_in(branch_taken),
        .ex_pc_in(ex_pc),
        .if_pc_in(if_pc),

        // Outputs
        .bht_tag_read_out(bht_tag_read),
        .bht_tag_write_out(bht_tag_write)
    );

    // PHT
    PHT pht0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .wr_en_in(cond_branch_en),
        .taken_branch_in(branch_taken),
        .ex_pc_in(ex_pc),
        .if_pc_in(if_pc),
        .bht_tag_read_in(bht_tag_read),
        .bht_tag_write_in(bht_tag_write),

        // Outputs
        .predicted_result_out(bp_taken)
    );

    // BTB
    BTB btb0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .wr_en(branch_en),
        .ex_pc(ex_pc),
        .ex_tp(ex_tpc),
        .if_pc(if_pc),

        // Outputs
        .hit(hit),
        .predict_pc_out(predict_pc)
    );

    // RAS
    // push & pop 
    always_comb begin
        push = 1'b0;
        pop  = 1'b0;
        for (int i=0; i<`N; i++) begin
            if (jump[i]) begin
                push = if_packet_in[i].valid;
                pop  = 0;
                break;
            end else if (link[i]) begin
                push = 0;
                pop  = if_packet_in[i].valid;
                break;
            end else begin
                push = 0;
                pop  = 0;
            end
        end
    end

    // Relative PC
    logic [`XLEN-1:0] link_pc;
    assign link_pc = jump[0] ?  ex_tpc[0] : jump[1] ? ex_tpc[1] : ex_tpc[2];
    
    RAS ras0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .push(push),
        .pop(pop),
        .pc(link_pc),

        // Outputs
        .return_addr(return_address)
    );

    // Generate outputs
    // To Fetch
 
                       
    always_comb begin
        bp_taken_out = {`N{1'b0}};
        bp_npc_out = bp_last_valid_npc;

        for (int i=0; i<`N; i++) begin
            if (link[i]) begin
                bp_packet_out[i].PC  = if_pc[i];
                bp_packet_out[i].NPC = return_address;
                bp_taken_out[i] = 1'b1;
            end else if (jump[i] && hit[i]) begin
                bp_packet_out[i].PC  = if_pc[i];
                bp_packet_out[i].NPC = predict_pc[i];
                bp_taken_out[i] = 1'b1;
            end else if (cond_branch_de[i] && bp_taken[i] && hit[i]) begin
                bp_packet_out[i].PC  = if_pc[i];
                bp_packet_out[i].NPC = predict_pc[i];
                bp_taken_out[i] = 1'b1;
            end else begin
                bp_packet_out[i].PC  = if_pc[i];
                bp_packet_out[i].NPC = if_packet_in[i].NPC;
                if (i == 0) begin
                    bp_taken_out[i] = 1'b0;
                end else begin
                    bp_taken_out[i] = bp_taken_out[i-1];
                end
            end

            if (i == 0 && bp_taken_out[i]) begin
                bp_npc_out = bp_packet_out[i].NPC;
            end else if(bp_taken_out[i] && !bp_taken_out[i-1]) begin
                bp_npc_out = bp_packet_out[i].NPC;
            end else if(if_packet_in[i].valid) begin
                if (i == 0) begin
                    bp_npc_out = if_packet_in[i].NPC;
                end else if (!bp_taken_out[i-1]) begin
                    bp_npc_out = if_packet_in[i].NPC;
                end
                
            end 
            // $display("if_packet_in[0].inst: %h if_packet_in[0].valid: %d, if_packet_in[0].PC:%h if_bp_npc_out: %h, bp_taken_out:%b", 
            //           if_packet_in[0].inst,    if_packet_in[0].valid,     if_packet_in[0].PC,    bp_npc_out, bp_taken_out);
            // $display("if_packet_in[1].inst: %h if_packet_in[1].valid: %d, if_packet_in[1].PC:%h if_bp_npc_out: %h, bp_taken_out:%b", 
            //           if_packet_in[1].inst,    if_packet_in[1].valid,     if_packet_in[1].PC,    bp_npc_out, bp_taken_out);
            // $display("if_packet_in[2].inst: %h if_packet_in[2].valid: %d, if_packet_in[2].PC:%h if_bp_npc_out: %h, bp_taken_out:%b",
            //           if_packet_in[2].inst,    if_packet_in[2].valid,     if_packet_in[2].PC,    bp_npc_out, bp_taken_out);

            // $display("predict_pc[%d]:%h, bp_taken[%d]: %b, hit[%d]: %b, cond_branch_de[%d]: %b, bp_pc[%d]: %h, bp_npc_out[%d]: %h", 
            //           i, predict_pc[i], i, bp_taken[i], i, hit[i], i, cond_branch_de[i], i, bp_packet_out[i].PC, i, bp_packet_out[i].NPC );
            // $display("bp_taken[%d]: %b, bht_tag_read[%d]: %h, bp_npc_out[%d]: %h", i, bp_taken[i], i, bht_tag_read[1], i, bp_packet_out[i].NPC);
        end
    end

    // To Cache
    genvar bp_k;
    generate
        assign bp_packet_out[0].inst  = if_packet_in[0].inst;
        assign bp_packet_out[0].valid = if_packet_in[0].valid && bp_packet_out[0].inst != `NOP;
        for (bp_k=1; bp_k<`N; bp_k++) begin
            assign bp_packet_out[bp_k].inst  = bp_taken_out[bp_k-1] ? `NOP : if_packet_in[bp_k].inst;
            assign bp_packet_out[bp_k].valid = if_packet_in[bp_k].valid && !bp_taken_out[bp_k-1] && bp_packet_out[bp_k].inst != `NOP;
        end
    endgenerate

    // NPC Buffer Update
    always_ff @(posedge clock) begin
        if (reset) begin
            bp_last_valid_npc <= {`XLEN{1'b0}};
        end else if (squash_flag) begin
            bp_last_valid_npc <= squash_pc; 
        end else begin
            bp_last_valid_npc <= bp_npc_out;
            // $display("bp_npc_out_out: %h", bp_npc_out);
        end
    end
endmodule