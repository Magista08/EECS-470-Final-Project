`include "../sys_defs.svh"

module DP(
    // input
    input clock, reset,
    input IF_ID_PACKET [`N-1:0] if_id_packet,
    input RT_PACKET [`N-1:0] rt_packet,

    // output
    output DP_PACKET [`N-1:0] dp_packet 
);


// Decode the instruction
genvar de;
generate
    for (de = 0; de < `N; de = de + 1) begin: de_0
        assign dp_packet[de].inst = if_id_packet[de].inst;
        assign dp_packet[de].PC   = if_id_packet[de].PC;
        assign dp_packet[de].NPC  = if_id_packet[de].NPC;
        
        DEC deco(
            // Input
            .inst(if_id_packet[de].inst),
            .valid(if_id_packet[de].valid && !reset),

            // Output
            .opa_select(dp_packet[de].opa_select),
            .opb_select(dp_packet[de].opb_select),
            .dest_reg_idx(dp_packet[de].dest_reg_idx),
            .alu_func(dp_packet[de].alu_func),
            .rd_mem(dp_packet[de].rd_mem),
            .wr_mem(dp_packet[de].wr_mem),
            .cond_branch(dp_packet[de].cond_branch),
            .uncond_branch(dp_packet[de].uncond_branch),
            .csr_op(dp_packet[de].csr_op),
            .halt(dp_packet[de].halt),
            .illegal(dp_packet[de].illegal),
            .rs1_instruction(dp_packet[de].rs1_instruction),
            .rs2_instruction(dp_packet[de].rs2_instruction),
            .dest_reg_valid(dp_packet[de].dest_reg_valid),
            .func_unit(dp_packet[de].func_unit)
        );
    end
endgenerate

// All units that need to read from the register file
logic [`N-1:0] [4:0] read_idxes_1;
logic [`N-1:0] [4:0] read_idxes_2;

logic [`N-1:0] [`XLEN-1:0] result_1;
logic [`N-1:0] [`XLEN-1:0] result_2;

// All units that need to write to the register file
logic [`N-1:0]       write_en;
logic [`N-1:0] [4:0] write_idxes;
logic [`N-1:0] [`XLEN-1:0] write_data; 
genvar regf;
generate
    for (regf = 0; regf < `N; regf = regf + 1) begin: regf_0
        // Read
        assign read_idxes_1[regf] = dp_packet[regf].inst.r.rs1;
        assign read_idxes_2[regf] = dp_packet[regf].inst.r.rs2;

        assign dp_packet[regf].rs1_value = result_1[regf];
        assign dp_packet[regf].rs2_value = result_2[regf];

        // Write
        assign write_en[regf]    = rt_packet[regf].wr_en;
        assign write_idxes[regf] = rt_packet[regf].dest_reg_idx;
        assign write_data[regf]  = rt_packet[regf].value;
    end
endgenerate


// Read from the register file
regfile reg_0(
    // Input
    .clock(clock),
    //Read
    .read_idx_1(read_idxes_1),
    .read_idx_2(read_idxes_2),
    // Write
    .write_en(write_en),
    .write_idx(write_idxes),
    .write_data(write_data),


    // Output
    .read_out_1(result_1),
    .read_out_2(result_2)
);
endmodule