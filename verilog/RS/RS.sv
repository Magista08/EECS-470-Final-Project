`include "../sys_defs.svh"

module PSEL (
    input logic [`RSLEN-1:0]     req0,
    output logic [`RSLEN-1:0]    gnt0,
    output logic [`RSLEN-1:0]    gnt1,
    output logic [`RSLEN-1:0]    gnt2
);
    logic [`RSLEN-1:0] req1;
    logic [`RSLEN-1:0] req2;
    logic [`RSLEN-1:0] pre_req0;
    logic [`RSLEN-1:0] pre_req1;
    logic [`RSLEN-1:0] pre_req2;

    assign req1 = req0 | gnt0;
    assign req2 = req1 | gnt1;

	
    assign gnt0[0] = ~req0[0];
    assign pre_req0[0] = req0[0];
    assign gnt1[0] = ~req1[0];
    assign pre_req1[0] = req1[0];
    assign gnt2[0] = ~req2[0];
    assign pre_req2[0] = req2[0];
    genvar i;
    for(i = 1; i<`RSLEN; i++)begin
        assign gnt0[i] = ~req0[i] & pre_req0[i-1];  
        assign pre_req0[i] = req0[i] & pre_req0[i-1];
        assign gnt1[i] = ~req1[i] & pre_req1[i-1];  
        assign pre_req1[i] = req1[i] & pre_req1[i-1];
        assign gnt2[i] = ~req2[i] & pre_req2[i-1];  
        assign pre_req2[i] = req2[i] & pre_req2[i-1];
    end    
endmodule 

module RS (
    input             		  clock, reset, enable,
    input  			          squash_flag,   // branch predictor signal
    input DP_IS_PACKET [2:0]  dp_packet_in,
    input MT_RS_PACKET [2:0]  mt_packet_in,
    input ROB_RS_PACKET [2:0] rob_packet_in,
    input CDB_RS_PACKET [2:0] cdb_packet_in,
    //input IS_RS_PACKET	  is_packet_in,
   
    output RS_IS_PACKET [2:0] is_packet_out,
    output RS_DP_PACKET       dp_packet_out//to DP
);
    RS_LINE [`RSLEN-1:0]      rs_table;
    
    // Find lines that are empty and that are needed to be emptied 
    logic [`RSLEN-1:0] clear_signal;  // 0: not needed for empty 1: need to empty this line
    logic [`RSLEN-1:0] emptied_lines; // 0: empty                1: Not empty
    
    // Select the line to insert
    logic [`RSLEN-1:0] [$clog2(3)-1:0] sel_buffer;
    logic [2:0] [`RSLEN-1:0] slots;   // 0: Cannot insert        1: Able to insert

    // Determine which instr to output
    logic       [`RSLEN-1:0]    not_ready;
    logic [2:0] [`RSLEN-1:0]    rs_is_posi;
    logic [`RSLEN-1:0]          read_inst_sig;

    logic [`RSLEN-1:0] [$clog2(`ROBLEN)-1:0]	other_T1;
    logic [`RSLEN-1:0] [$clog2(`ROBLEN)-1:0]	other_T2;
    logic [`RSLEN-1:0] [4:0]                 other_dest_reg1;
    logic [`RSLEN-1:0] [4:0]                 other_dest_reg2;

    logic [$clog2(`RSLEN):0]                 count;
    logic [`RSLEN-1:0]                       out_busy;

    
    // Record the final destination
    /*
    CURRENT_MT_TABLE [2:0] new_mt_table;
    assign new_mt_table[0].dest_reg_idx = dp_packet_in[0].dest_reg_idx;
    assign new_mt_table[1].dest_reg_idx = dp_packet_in[1].dest_reg_idx;
    assign new_mt_table[2].dest_reg_idx = dp_packet_in[2].dest_reg_idx;

    assign new_mt_table[0].T            = mt_packet_in[0].T;
    assign new_mt_table[1].T            = mt_packet_in[1].T;
    assign new_mt_table[2].T            = mt_packet_in[2].T;
    */




    // Update RS Table
    genvar i;
    generate
        
        for (i=0; i<`RSLEN; i++) begin
	        // whether select
            assign sel_buffer[i] = slots[0][i] ? 2 :
                                   slots[1][i] ? 1 :
                                   slots[2][i] ? 0 : 3;
            assign read_inst_sig[i] = (sel_buffer[i] != 3) ? 1'b1 : 1'b0;
            assign other_T1[i] = ((sel_buffer[i] == 1) || (sel_buffer[i] == 2)) ? rob_packet_in[0].T : 0;
            assign other_T2[i] = (sel_buffer[i] == 2) ? rob_packet_in[1].T : 0;
            //assign other_inst1 = ((sel_buffer[i] == 1) || (sel_buffer[i] == 2)) ? dp_packet_in[0].inst : `NOP;
            //assign other_inst2 = (sel_buffer[i] == 2) ? dp_packet_in[1].inst : `NOP;
            assign other_dest_reg1[i] = ((sel_buffer[i] == 1) || (sel_buffer[i] == 2)) ? dp_packet_in[0].dest_reg_idx : 0;
            assign other_dest_reg2[i] = (sel_buffer[i] == 2) ? dp_packet_in[1].dest_reg_idx : 0;

            // One Line Change
            
            RS_ONE_LINE RSL(
                //input
                .clock(clock),
                .reset(reset),
                .enable(enable && read_inst_sig[i]),
                .clear(clear_signal[i]),
                .line_id(i),
                .dp_packet(dp_packet_in[sel_buffer[i]%3]), 
                .mt_packet(mt_packet_in[sel_buffer[i]%3]),
                .rob_packet(rob_packet_in[sel_buffer[i]%3]),
                .cdb_packet(cdb_packet_in),
                .other_T1(other_T1[i]),
                .other_T2(other_T2[i]),
                .other_dest_reg1(other_dest_reg1[i]),
                .other_dest_reg2(other_dest_reg2[i]),
                .my_position(sel_buffer[i]),
                
                //output
                .not_ready(not_ready[i]),
                .rs_line(rs_table[i]),
                .out_busy(out_busy[i])
            );  
        end
    endgenerate
    
    // Psel for ready bit
    PSEL is_psel(
        // input
        .req0(not_ready),

        // output
        .gnt0(rs_is_posi[0]),
        .gnt1(rs_is_posi[1]),
        .gnt2(rs_is_posi[2])
    );
    always_ff @(posedge clock) begin
        // Re-init
        //is_packet_count <= 0;
        /*
        if(squash_flag) begin
            clear_signal    <= {`RSLEN{1'b1}};
        end else begin
            clear_signal    <= {`RSLEN{1'b0}};
        end
        */
        clear_signal <= {`RSLEN{squash_flag}};
        
        // Send to IS
        // $display("not_ready = %b", not_ready);
        for (int i=0; i<3; i++) begin
            // FU detect hazard

            // Packet out
            if (rs_is_posi[i] == 0) begin
                //posi[i] <= 0;
                is_packet_out[i] <={
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
                    1'b0                     // valid
                };
            end else begin
                // posi[i] <= $clog2(rs_is_posi[i]); 
                // $display("posi[%d] = %d", i, $clog2(rs_is_posi[i]));
                // $display("posi[%d] = %d", i, posi[i]);
                is_packet_out[i].T             <= rs_table[$clog2(rs_is_posi[i])].T;
                is_packet_out[i].inst          <= rs_table[$clog2(rs_is_posi[i])].inst;
                is_packet_out[i].PC            <= rs_table[$clog2(rs_is_posi[i])].PC;
                is_packet_out[i].NPC           <= rs_table[$clog2(rs_is_posi[i])].NPC;

                is_packet_out[i].rs1_value     <= rs_table[$clog2(rs_is_posi[i])].V1;
                is_packet_out[i].rs2_value     <= rs_table[$clog2(rs_is_posi[i])].V2;

                is_packet_out[i].opa_select    <= rs_table[$clog2(rs_is_posi[i])].opa_select;
                is_packet_out[i].opb_select    <= rs_table[$clog2(rs_is_posi[i])].opb_select;
                is_packet_out[i].dest_reg_idx  <= rs_table[$clog2(rs_is_posi[i])].dest_reg_idx;
                is_packet_out[i].alu_func      <= rs_table[$clog2(rs_is_posi[i])].alu_func;
                is_packet_out[i].rd_mem        <= rs_table[$clog2(rs_is_posi[i])].rd_mem;
                is_packet_out[i].wr_mem        <= rs_table[$clog2(rs_is_posi[i])].wr_mem;
                is_packet_out[i].cond_branch   <= rs_table[$clog2(rs_is_posi[i])].cond_branch;
                is_packet_out[i].uncond_branch <= rs_table[$clog2(rs_is_posi[i])].uncond_branch;
                is_packet_out[i].halt          <= rs_table[$clog2(rs_is_posi[i])].halt;
                is_packet_out[i].illegal       <= rs_table[$clog2(rs_is_posi[i])].illegal;
                is_packet_out[i].csr_op        <= rs_table[$clog2(rs_is_posi[i])].csr_op;
                is_packet_out[i].valid         <= rs_table[$clog2(rs_is_posi[i])].valid;

                // Pass the signal that this line is emptied
                clear_signal[$clog2(rs_is_posi[i])] <= 1'b1;
            end
        end
    end
    
    // Empty lines count 
    genvar j;
    for (j=0; j<`RSLEN; j++) begin
        assign emptied_lines[j] = rs_table[j].busy ? 1'b1 : 1'b0;
    end

    always_comb begin
        count = 0;
        for (int k = 0; k < `RSLEN; k++) begin
                if (~out_busy[k]) begin
                count = count + 1;
                end
        end
    end
    assign dp_packet_out.empty_num = (count>3) ? 3 : count;

    // Clear the emptied_lines based on psel
    PSEL clean_psel(
        // input
        .req0(emptied_lines),
        
        // output
        .gnt0(slots[0]),
        .gnt1(slots[1]),
        .gnt2(slots[2])
    );

    
    
endmodule 