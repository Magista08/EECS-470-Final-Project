`include "verilog/sys_defs.svh"

module stage_rt(
    // from ROB
    input   ROB_RT_PACKET   [2:0]   rob_rt_packet_in, // dest_reg_idx, value, valid, take_branch, NPC
    
    // to stage_dp
    output  RT_DP_PACKET    [2:0]   rt_dp_packet_out, // retire_reg, value, valid
    // when interruptions occur, clear to the last insts finishing Retire
    output  logic [2:0]             valid,
    output  logic [2:0] [`XLEN-1:0] NPC,
    output  logic                   halt,
    output  logic [`XLEN-1:0]       squash_pc,
    output  logic                   squash_flag
);
    
    // If there is branch or store command, then rob_rt_packet_in[n].dest_reg_idx==`ZERO_REG, not retire

    assign rt_dp_packet_out[0].retire_reg  = (rob_rt_packet_in[0].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[0].dest_reg_idx : 0; // to wr_idx in regfile
    assign rt_dp_packet_out[0].value       = (rob_rt_packet_in[0].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[0].value : 0; // to wr_data in regfile
    assign rt_dp_packet_out[0].valid       = (rob_rt_packet_in[0].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[0].valid : 0; // to wr_en in regfile

    assign rt_dp_packet_out[1].retire_reg  = (rob_rt_packet_in[1].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[1].dest_reg_idx : 0;
    assign rt_dp_packet_out[1].value       = (rob_rt_packet_in[1].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[1].value : 0;
    assign rt_dp_packet_out[1].valid       = (rob_rt_packet_in[1].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[1].valid : 0;

    assign rt_dp_packet_out[2].retire_reg  = (rob_rt_packet_in[2].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[2].dest_reg_idx : 0;
    assign rt_dp_packet_out[2].value       = (rob_rt_packet_in[2].dest_reg_idx != `ZERO_REG)                                          
                                            ? rob_rt_packet_in[2].value : 0;
    assign rt_dp_packet_out[2].valid       = (rob_rt_packet_in[2].dest_reg_idx != `ZERO_REG) 
                                            ? rob_rt_packet_in[2].valid : 0;

    // Once branch is taken in any inst, squash 
    assign squash_flag = ((rob_rt_packet_in[0].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[0].take_branch)
                        |((rob_rt_packet_in[1].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[1].take_branch)
                        |((rob_rt_packet_in[2].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[2].take_branch);

    // If inst[n] takes branch, then after squashing 'ht' should occur at this inst.
    assign squash_pc = ((rob_rt_packet_in[0].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[0].take_branch) ? rob_rt_packet_in[0].value
                      :((rob_rt_packet_in[1].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[1].take_branch) ? rob_rt_packet_in[1].value
                      :((rob_rt_packet_in[2].dest_reg_idx == `ZERO_REG) & rob_rt_packet_in[2].take_branch) ? rob_rt_packet_in[2].value
                      :0;

    // Pass-through
    assign valid[0] = rob_rt_packet_in[0].valid;
    assign valid[1] = rob_rt_packet_in[1].valid;
    assign valid[2] = rob_rt_packet_in[2].valid;
    assign NPC[0]   = rob_rt_packet_in[0].NPC;
    assign NPC[1]   = rob_rt_packet_in[1].NPC;
    assign NPC[2]   = rob_rt_packet_in[2].NPC;
    assign halt = (rob_rt_packet_in[0].halt && rob_rt_packet_in[0].valid) 
               || (rob_rt_packet_in[1].halt && rob_rt_packet_in[1].valid) 
               || (rob_rt_packet_in[2].halt && rob_rt_packet_in[2].valid);


endmodule
