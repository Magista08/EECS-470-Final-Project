`include "verilog/sys_defs.svh"

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
    input DP_PACKET [2:0]  dp_packet_in,
    input MT_RS_PACKET [2:0]  mt_packet_in,
    input ROB_RS_PACKET [2:0] rob_packet_in,
    input CDB_RS_PACKET [2:0] cdb_packet_in,
    input FU_EMPTY_PACKET	  fu_empty_packet,
   
    output RS_IS_PACKET [2:0] is_packet_out,
    output RS_IF_PACKET       dp_packet_out//to DP
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

    logic [2:0] [`RSLEN-1:0]    rs_is_posi_line;

    logic [1:0]                 alu_empty_count;
    //logic [1:0]                 mult_empty_count;
    logic [$clog2(`RSLEN):0]                 alu_num;
    //logic [$clog2(`RSLEN):0]                 mult_num;
    logic [`RSLEN-1:0]    masked_not_ready;
    




    // Update RS Table
    genvar i;
    generate
        
        for (i=0; i<`RSLEN; i++) begin
	        // whether select
            assign sel_buffer[i] = slots[0][i] ? 0 :
                                   slots[1][i] ? 1 :
                                   slots[2][i] ? 2 : 3;
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

    always_comb begin
        alu_empty_count = 0;
	alu_num = 0;
	//mult_empty_count = 0;
	//mult_num = 0;
        for (int n = 0; n < 3; n++) begin
            if (fu_empty_packet.ALU_empty[n]) begin
                alu_empty_count = alu_empty_count + 1;
            end
	    // if (fu_empty_packet.MULT_empty[n]) begin
        //         mult_empty_count = mult_empty_count + 1;
        //     end
        end
	for (int l = 0; l < `RSLEN; l++) begin
	    alu_num = (~not_ready[l] && (rs_table[l].func_unit == FUNC_ALU)) ? alu_num + 1 : alu_num;
	    //mult_num = (~not_ready[l] && (rs_table[l].func_unit == FUNC_MUL)) ? mult_num + 1 : mult_num;
	    masked_not_ready[l] = (not_ready[l]) ? 1 : 
		(((alu_num > alu_empty_count) && (rs_table[l].func_unit == FUNC_ALU))) ? 1 : 0;
	end
    end


    PSEL is_psel(
        // input
        .req0(masked_not_ready),

        // output
        .gnt0(rs_is_posi[0]),
        .gnt1(rs_is_posi[1]),
        .gnt2(rs_is_posi[2])
    );

   assign rs_is_posi_line = rs_is_posi[0] | rs_is_posi[1] | rs_is_posi[2];
    /*
    always_comb begin
        if(reset || squash_flag) begin
            clear_signal = {`ROBLEN{1'b0}};
        end else begin
            clear_signal = rs_is_posi_line;
        end
    end
    */
    assign clear_signal = (reset || squash_flag) ? {`ROBLEN{1'b0}} : rs_is_posi_line;

    always_comb begin
        is_packet_out[0] ={
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
		    FUNC_NOP			//func_unit
        };
        for (int i=0; i<`RSLEN; i++) begin
            // Packet out
            if (rs_is_posi[0][i] == 1 && ~reset) begin
                //posi[i] <= 0;
                is_packet_out[0].T             = rs_table[i].T;
                is_packet_out[0].inst          = rs_table[i].inst;
                is_packet_out[0].PC            = rs_table[i].PC;
                is_packet_out[0].NPC           = rs_table[i].NPC;

                is_packet_out[0].rs1_value     = rs_table[i].V1;
                is_packet_out[0].rs2_value     = rs_table[i].V2;

                is_packet_out[0].opa_select    = rs_table[i].opa_select;
                is_packet_out[0].opb_select    = rs_table[i].opb_select;
                is_packet_out[0].dest_reg_idx  = rs_table[i].dest_reg_idx;
                is_packet_out[0].alu_func      = rs_table[i].alu_func;
                is_packet_out[0].rd_mem        = rs_table[i].rd_mem;
                is_packet_out[0].wr_mem        = rs_table[i].wr_mem;
                is_packet_out[0].cond_branch   = rs_table[i].cond_branch;
                is_packet_out[0].uncond_branch = rs_table[i].uncond_branch;
                is_packet_out[0].halt          = rs_table[i].halt;
                is_packet_out[0].illegal       = 1'b0;
                is_packet_out[0].csr_op        = rs_table[i].csr_op;
                is_packet_out[0].valid         = rs_table[i].valid;
		        is_packet_out[0].func_unit     = rs_table[i].func_unit;
            end 
        end
    end

    always_comb begin
        is_packet_out[1] ={
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
		    FUNC_NOP                 //func_unit
        };
        for (int j=0; j<`RSLEN; j++) begin
            // Packet out
            if (rs_is_posi[1][j] == 1 && ~reset) begin
                //posi[i] <= 0;
                is_packet_out[1].T             = rs_table[j].T;
                is_packet_out[1].inst          = rs_table[j].inst;
                is_packet_out[1].PC            = rs_table[j].PC;
                is_packet_out[1].NPC           = rs_table[j].NPC;

                is_packet_out[1].rs1_value     = rs_table[j].V1;
                is_packet_out[1].rs2_value     = rs_table[j].V2;

                is_packet_out[1].opa_select    = rs_table[j].opa_select;
                is_packet_out[1].opb_select    = rs_table[j].opb_select;
                is_packet_out[1].dest_reg_idx  = rs_table[j].dest_reg_idx;
                is_packet_out[1].alu_func      = rs_table[j].alu_func;
                is_packet_out[1].rd_mem        = rs_table[j].rd_mem;
                is_packet_out[1].wr_mem        = rs_table[j].wr_mem;
                is_packet_out[1].cond_branch   = rs_table[j].cond_branch;
                is_packet_out[1].uncond_branch = rs_table[j].uncond_branch;
                is_packet_out[1].halt          = rs_table[j].halt;
                is_packet_out[1].illegal       = 1'b0;
                is_packet_out[1].csr_op        = rs_table[j].csr_op;
                is_packet_out[1].valid         = rs_table[j].valid;
                is_packet_out[1].func_unit     = rs_table[j].func_unit;
            end 
        end
        // $display("not_ready = %b", not_ready); 
    end

    always_comb begin
        is_packet_out[2] ={
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
	 	    FUNC_NOP                 //func_unit
        };
        for (int k=0; k<`RSLEN; k++) begin
            // Packet out
            if (rs_is_posi[2][k] == 1 && ~reset) begin
                //posi[i] <= 0;
                is_packet_out[2].T             = rs_table[k].T;
                is_packet_out[2].inst          = rs_table[k].inst;
                is_packet_out[2].PC            = rs_table[k].PC;
                is_packet_out[2].NPC           = rs_table[k].NPC;

                is_packet_out[2].rs1_value     = rs_table[k].V1;
                is_packet_out[2].rs2_value     = rs_table[k].V2;

                is_packet_out[2].opa_select    = rs_table[k].opa_select;
                is_packet_out[2].opb_select    = rs_table[k].opb_select;
                is_packet_out[2].dest_reg_idx  = rs_table[k].dest_reg_idx;
                is_packet_out[2].alu_func      = rs_table[k].alu_func;
                is_packet_out[2].rd_mem        = rs_table[k].rd_mem;
                is_packet_out[2].wr_mem        = rs_table[k].wr_mem;
                is_packet_out[2].cond_branch   = rs_table[k].cond_branch;
                is_packet_out[2].uncond_branch = rs_table[k].uncond_branch;
                is_packet_out[2].halt          = rs_table[k].halt;
                is_packet_out[2].illegal       = 1'b0;
                is_packet_out[2].csr_op        = rs_table[k].csr_op;
                is_packet_out[2].valid         = rs_table[k].valid;
		        is_packet_out[2].func_unit     = rs_table[k].func_unit;
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
        for (int m = 0; m < `RSLEN; m++) begin
                if (~out_busy[m]) begin
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
