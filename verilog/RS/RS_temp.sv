`include "verilog/sys_defs.svh"

module RS (
    input             		clock, reset, enable,
    input  			        squash_flag;
    input DP_RS_PACKET   	dp_packet_in,
    input MT_RS_PACKET   	mt_packet_in,
    input ROB_TABLE 	    rob_in,
    input CDB_RS_PACKET 	cdb_packet_in,
    input IS_RS_PACKET		is_packet_in,

    output RS_TABLE  rs_table_out, // ? /**/
    output DP_IS_PACKET  is_packet_out,
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
        rs_table.full = 1;

        // Find any line is not busy, break
        for(int i=0; i<`RSLEN;i++) begin
            if (!rs_table.line[i].busy) begin
                rs_table.full = 0;
                break;
            end
        end
    end
    //go through all the lines. 
    //if a line is ready, insert into is_packet_out
    // the max length of is_packet_out is 3
    always_ff @(posedge clock) begin
        for(int i=0; i<`RSLEN;i++) begin
            if(rs_table.line[i].ready) begin
                // input the result
                // clean the line
            end
        end
    end
	//empty ?? 
    
    //psel

    // FU detect hazard
endmodule 