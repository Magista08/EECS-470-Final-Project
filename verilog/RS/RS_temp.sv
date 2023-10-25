`include "verilog/sys_defs.svh"

module RS (
    input             		clock, reset, enable,
    input  			        squash_flag;
    input DP_RS_PACKET   	dp_packet_in,
    input MT_RS_PACKET   	mt_packet_in,
    input ROB_TABLE 	    rob_in,
    input CDB_RS_PACKET 	cdb_packet_in,
    input IS_RS_PACKET		is_packet_in,

    output RS_TABLE      rs_table_out, // ? /**/
    output DP_IS_PACKET [2:0] is_packet_out,
    output RS_DP_PACKET  dp_packet_out//to DP
);
    RS_LINE [`RSLEN-1:0] rs_line;
    RS_TABLE rs_table;
    
    logic [`RSLEN-1:0] empty;
    //RS_LINE [2:0] is_buffer;
    
    logic [`RSLEN-1:0] [1:0] sel_buffer;
    logic [`RSLEN-1:0] slot1;
    logic [`RSLEN-1:0] slot2;
    logic [`RSLEN-1:0] slot3;

    logic [$clog2(3):0] is_packet_count;
    logic [$clog2(3):0] temp_is_packet_count;
    
    generate 
        genvar i;
        for (i=0; i<`RSLEN; i++) begin
	    assign sel_buff[n] = (slot1[n]) ? 1 : (slot2[n]) ? 2 : (slot3[n]) ? 3 : 0;
            RS_LINE line(
                //input
                .clock(clock),
                .reset(reset),
                .enable(enable),
                .empty(empty[n]);
                .squash_flag(squash_flag),
                .line_id(n),
                .sel(sel_buffer[n]),
                .dp_packet(dp_packet),
                .mt_packet(mt_packet),
                .rob_packet(rob_packet),
                .cdb_packet(cdb_packet),
            //output
                .rs_line(rs_line[n])
            );
	    
        end
    endgenerate
    // Reset
    /****************************************************************************************************************************/
    always_ff @(posedge clock) begin
        if (reset);
    end

    //whether full
    always_ff @(posedge clock) begin
        rs_table.full <= 1;

        // Find any line is not busy, break
        for(int i=0; i<`RSLEN;i++) begin
            if (!rs_table.line[i].busy) begin
                rs_table.full <= 0;
                break;
            end
        end
    end
    //go through all the lines. 
    //if a line is ready, insert into is_packet_out
    // the max length of is_packet_out is 3
    always_ff @(posedge clock) begin
        // Re-init the count
        is_packet_count <= 0;

        // Check RS table 
        for(int i=0; i<`RSLEN;i++) begin
            if ((rs_table.line[i].ready) && ( is_packet_count != 3)) begin
                // FU detect hazard

                // input the result
                is_packet_out[is_packet_count].inst          <= rs_table.line[i].inst;
                is_packet_out[is_packet_count].PC            <= rs_table.line[i].PC;
                is_packet_out[is_packet_count].NPC           <= rs_table.line[i].NPC;

                is_packet_out[is_packet_count].rs1_value     <= rs_table.line[i].V1;
                is_packet_out[is_packet_count].rs2_value     <= rs_table.line[i].V2;

                is_packet_out[is_packet_count].opa_select    <= rs_table.line[i].opa_select;
                is_packet_out[is_packet_count].opb_select    <= rs_table.line[i].opb_select;
                is_packet_out[is_packet_count].dest_reg_idx  <= rs_table.line[i].dest_reg_idx;
                is_packet_out[is_packet_count].alu_func      <= rs_table.line[i].alu_func;
                is_packet_out[is_packet_count].rd_mem        <= rs_table.line[i].rd_mem;
                is_packet_out[is_packet_count].wr_mem        <= rs_table.line[i].wr_mem;
                is_packet_out[is_packet_count].cond_branch   <= rs_table.line[i].cond_branch;
                is_packet_out[is_packet_count].uncond_branch <= rs_table.line[i].uncond_branch;
                is_packet_out[is_packet_count].halt          <= rs_table.line[i].halt;
                is_packet_out[is_packet_count].illegal       <= rs_table.line[i].illegal;
                is_packet_out[is_packet_count].csr_op        <= rs_table.line[i].csr_op;
                is_packet_out[is_packet_count].valid         <= rs_table.line[i].valid;
                // clean the line in RS

                // Decrease the count
                temp_is_packet_count <= is_packet_count;
                is_packet_count      <= temp_is_packet_count + 1;
            end

            if (is_packet_count == 3) break;
        end
    end
	//empty ?? 
    
    //psel

    
endmodule 