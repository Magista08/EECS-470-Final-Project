`include "verilog/sys_defs.svh"

module RS (
    input             		clock, reset, enable,
    input  			        squash_flag,   // branch predictor signal
    input DP_RS_PACKET   	dp_packet_in,
    input MT_RS_PACKET   	mt_packet_in,
    input ROB_TABLE 	    rob_in,
    input CDB_RS_PACKET 	cdb_packet_in,
    input IS_RS_PACKET		is_packet_in,

    input ROB_LINE [2:0]    inst_in,

    output RS_TABLE      rs_table_out, // ? /**/
    output DP_IS_PACKET [2:0] is_packet_out,
    output RS_DP_PACKET  dp_packet_out//to DP
);
    RS_LINE [`RSLEN-1:0] rs_table;
    ROB_LINE             insert_inst;
    
    logic [`RSLEN-1:0] empty_signal;  // 0: not needed for empty 1: need to empty this line
    logic [`RSLEN-1:0] emptied_lines; // 0: not empty            1: empty
    
    logic [$clog2(3):0] sel_buffer;
    logci [$clog2(3):0] old_sel_buffer;
    logic [$clog2(3):0] [`RSLEN-1:0] slots;
    logic inst_select;

    logic [$clog2(3)-1:0] is_packet_count;
    logic [$clog2(3)-1:0] temp_is_packet_count;
    
    // Update RS Table
    always_comb begin 
        sel_buffer = {$clog2(3){1'b0}};
        for (int i=0; i<`RSLEN; i++) begin
	        // whether select
            inst_select = slots[sel_buffer][i];
        
            // Prepare for the rob file
            if (inst_select) begin
                // update sel_buffer
                old_sel_buffer = sel_buffer
                sel_buffer = old_sel_buffer + 1;

                // insert actual inst
                insert_inst = inst_in[sel_buff];
            end else begin
                // Insert nop into one line 
                insert_inst = {
                    {$clog2(`ROBLEN){1'b0}},
                    `NOP,
                    4'b0, //R
                    {`XLEN{1'b0}}
                    
                    // WAITING FOR MORE NOP
                    /************************************************************************************************/
                    /************************************************************************************************/
                }
            end

            // One Line Change
            RS_LINE line(
                //input
                .clock(clock),
                .reset(reset),
                .enable(enable),
                .empty(empty_signal[i]);
                .squash_flag(squash_flag), 
                .line_id(i),
                .dp_packet(dp_packet), // ?
                .mt_packet(mt_packet),
                .rob_packet(rs_line[sel_buffer]),
                .cdb_packet(cdb_packet),

                //output
                .rs_line(rs_table[i])
            );
	    
        end
    end
    // Reset
    /****************************************************************************************************************/
    always_ff @(posedge clock) begin
        if (reset);
    end
    /****************************************************************************************************************/

    //whether full
    /* QUSTION: since the the counter for the empty lines exist, this is meaningful or not? */
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /*
    always_ff @(posedge clock) begin
        rs_table.full <= 1;

        // Find any line is not busy, break
        for(int i=0; i<`RSLEN;i++) begin
            if (!rs_table[i].busy) begin
                rs_table.full <= 0;
                break;
            end
        end
    end
    */
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //go through all the lines. 
    //if a line is ready, insert into is_packet_out
    // the max length of is_packet_out is 3
    always_ff @(posedge clock) begin
        // Re-init
        is_packet_count <= 0;
        empty_signal    <= {`RSLEN{1'b0}};


        // Check RS table 
        for(int i=0; i<`RSLEN;i++) begin
            if ((rs_table[i].ready) && ( is_packet_count != 3)) begin
                // FU detect hazard

                // input the result
                is_packet_out[is_packet_count].inst          <= rs_table[i].inst;
                is_packet_out[is_packet_count].PC            <= rs_table[i].PC;
                is_packet_out[is_packet_count].NPC           <= rs_table[i].NPC;

                is_packet_out[is_packet_count].rs1_value     <= rs_table[i].V1;
                is_packet_out[is_packet_count].rs2_value     <= rs_table[i].V2;

                is_packet_out[is_packet_count].opa_select    <= rs_table[i].opa_select;
                is_packet_out[is_packet_count].opb_select    <= rs_table[i].opb_select;
                is_packet_out[is_packet_count].dest_reg_idx  <= rs_table[i].dest_reg_idx;
                is_packet_out[is_packet_count].alu_func      <= rs_table[i].alu_func;
                is_packet_out[is_packet_count].rd_mem        <= rs_table[i].rd_mem;
                is_packet_out[is_packet_count].wr_mem        <= rs_table[i].wr_mem;
                is_packet_out[is_packet_count].cond_branch   <= rs_table[i].cond_branch;
                is_packet_out[is_packet_count].uncond_branch <= rs_table[i].uncond_branch;
                is_packet_out[is_packet_count].halt          <= rs_table[i].halt;
                is_packet_out[is_packet_count].illegal       <= rs_table[i].illegal;
                is_packet_out[is_packet_count].csr_op        <= rs_table[i].csr_op;
                is_packet_out[is_packet_count].valid         <= rs_table[i].valid;
                // clean the line in RS

                // Pass the signal that this line is emptied
                empteid_signal[i] <= 1'b1;

                // Decrease the count
                temp_is_packet_count <= is_packet_count;
                is_packet_count      <= temp_is_packet_count + 1;
            end

            if (is_packet_count == 3) break;
        end
    end
    
    //psel
    always_ff @(posedge clock) begin
        // Empty lines count 
        for (int i=0; i<`RSLEN; i++) begin
            // The line is ready for new instr
            if (!rs_table[i].busy) begin
                emptied_lines[i] <= 1'b1;
            end else begin
                emptied_lines[i] <= 1'b0;
            end
        end

        // Clear the emptied_lines based on psel
    end
    
endmodule 