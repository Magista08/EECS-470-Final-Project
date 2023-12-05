`include "verilog/sys_defs.svh"
//`include "verilog/ISA.svh"
module ROB (
    // Inputs
    input   clock, reset, enable,
    input   logic               squash_flag,//clean all rows, set head/tail pointer
    input   CDB_ROB_PACKET    [2:0] CDB_packet_in,//value, valid, tag      
    input   DP_PACKET     [2:0] DP_packet_in,//dp_valid? dest_reg_idx   
    input   MT_ROB_PACKET [2:0] MT_packet_in,//T1_plus, T1, valid1, T2_plus, T2, valid2,   help passing V1, V2 to RS

    // Outputs
    output ROB_IF_PACKET       IF_packet_out,//to DP, emptied_lines, comb
    output  ROB_RT_PACKET  [2:0] RT_packet_out,   // At Retire stage, output 3 lines of ROB_LINE, R && V && branch_taken
    output  ROB_RS_PACKET [2:0] RS_packet_out,  //comb
    output  ROB_MT_PACKET [2:0] MT_packet_out   // At Dispatch stage, output dispatched tag, R && T && valid, comb
    //output logic	[$clog2(`ROBLEN)-1:0] head,
    //output logic [$clog2(`ROBLEN):0]                 count
);

    logic	[$clog2(`ROBLEN)-1:0] head; // head
    logic	[$clog2(`ROBLEN):0] head_plus1;
    logic	[$clog2(`ROBLEN):0] head_plus2;
    logic	[$clog2(`ROBLEN)-1:0] tail; // tail
    logic	[$clog2(`ROBLEN):0] tail_plus1;
    logic	[$clog2(`ROBLEN):0] tail_plus2;
    logic	[$clog2(`ROBLEN)-1:0] head_n; // head
    logic	[$clog2(`ROBLEN)-1:0] tail_n; // tail
    ROB_LINE [`ROBLEN-1:0]      rob_table;
    ROB_LINE [`ROBLEN-1:0]      rob_table_n;
    logic [$clog2(`ROBLEN):0]                 count;



    assign head_plus1 = head + 1;
    assign head_plus2 = head + 2;
    assign tail_plus1 = tail + 1;
    assign tail_plus2 = tail + 2;

    always_comb begin
	if(reset || squash_flag) begin
	    rob_table_n    = '{`ROBLEN {0}};
	end else begin
	    for(int i = 0; i < `ROBLEN; i++) begin
		rob_table_n[i].busy =  rob_table[i].busy;
		rob_table_n[i].value_flag =  rob_table[i].value_flag;
		rob_table_n[i].reg_id =  rob_table[i].reg_id;
		rob_table_n[i].value =  rob_table[i].value;
		rob_table_n[i].take_branch =  rob_table[i].take_branch;
		rob_table_n[i].NPC = rob_table[i].NPC;
		rob_table_n[i].halt = rob_table[i].halt;
	    end
	end

	//dispatch
	if(reset || squash_flag) begin
	    tail_n = 0;
	end else if(DP_packet_in[0].illegal) begin
	    tail_n = tail;
	end else if (DP_packet_in[1].illegal) begin
	    tail_n = tail + 1;
	    rob_table_n[tail].busy = 1;
	    rob_table_n[tail].reg_id = (DP_packet_in[0].dest_reg_valid) ? DP_packet_in[0].dest_reg_idx : 5'b00000;
	    rob_table_n[tail].rd_wr_mem = DP_packet_in[0].rd_mem || DP_packet_in[0].wr_mem;
	end else if (DP_packet_in[2].illegal) begin
	    tail_n = tail + 2;
	    rob_table_n[tail].busy = 1;
	    rob_table_n[tail].reg_id = (DP_packet_in[0].dest_reg_valid) ? DP_packet_in[0].dest_reg_idx : 5'b00000;
	    rob_table_n[tail].rd_wr_mem = DP_packet_in[0].rd_mem || DP_packet_in[0].wr_mem;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].busy = 1;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].reg_id = (DP_packet_in[1].dest_reg_valid) ? DP_packet_in[1].dest_reg_idx : 5'b00000;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem = DP_packet_in[1].rd_mem || DP_packet_in[1].wr_mem;
	end else begin
	    tail_n = tail + 3;
	    rob_table_n[tail].busy = 1;
	    rob_table_n[tail].reg_id = (DP_packet_in[0].dest_reg_valid) ? DP_packet_in[0].dest_reg_idx : 5'b00000;
	    rob_table_n[tail].rd_wr_mem = DP_packet_in[0].rd_mem || DP_packet_in[0].wr_mem;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].busy = 1;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].reg_id = (DP_packet_in[1].dest_reg_valid) ? DP_packet_in[1].dest_reg_idx : 5'b00000;
	    rob_table_n[tail_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem = DP_packet_in[1].rd_mem || DP_packet_in[1].wr_mem;
	    rob_table_n[tail_plus2[$clog2(`ROBLEN)-1:0]].busy = 1;
	    rob_table_n[tail_plus2[$clog2(`ROBLEN)-1:0]].reg_id = (DP_packet_in[2].dest_reg_valid) ? DP_packet_in[2].dest_reg_idx : 5'b00000;
	    rob_table_n[tail_plus2[$clog2(`ROBLEN)-1:0]].rd_wr_mem = DP_packet_in[2].rd_mem || DP_packet_in[2].wr_mem;
	end

	//retire

	if(reset || squash_flag) begin
	    head_n = 0;
	end else if(~rob_table[head].value_flag) begin
	    head_n = head;
	end else if ((rob_table[head].rd_wr_mem && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag) begin
	    head_n = head + 1;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	end else if (((rob_table[head].rd_wr_mem || rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].rd_wr_mem) ||  
			~rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag) begin
	    head_n = head + 2;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	end else begin
	    head_n = head + 3;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	    rob_table_n[head_plus2[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	end
/*
	if(reset || squash_flag) begin
	    head_n = 0;
	end else if(~(((rob_table[head].rd_wr_mem || rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && 
		rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].rd_wr_mem) || ((rob_table[head].rd_wr_mem) && 
		rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem)) && rob_table[head].value_flag && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag && 
		rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag) begin
	    head_n = head + 3;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	    rob_table_n[head_plus2[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	end else if (~((rob_table[head].rd_wr_mem) && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && rob_table[head].value_flag && 
		rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag) begin
	    head_n = head + 2;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].busy = 0;
	    rob_table_n[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag = 0;
	end else if (~(rob_table[head].rd_wr_mem) && rob_table[head].value_flag) begin
	    head_n = head + 1;
	    rob_table_n[head].busy = 0;
	    rob_table_n[head].value_flag = 0;
	end else begin
	    head_n = head;
	end
*/
	//complete
	if(~CDB_packet_in[0].valid || reset || squash_flag) begin
	end else if(~CDB_packet_in[1].valid) begin
	    rob_table_n[CDB_packet_in[0].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[0].tag].value = CDB_packet_in[0].value;
	    rob_table_n[CDB_packet_in[0].tag].take_branch = CDB_packet_in[0].take_branch;
	    rob_table_n[CDB_packet_in[0].tag].NPC = CDB_packet_in[0].NPC;
	    rob_table_n[CDB_packet_in[0].tag].halt = CDB_packet_in[0].halt;
	end else if(~CDB_packet_in[2].valid) begin
	    rob_table_n[CDB_packet_in[0].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[0].tag].value = CDB_packet_in[0].value;
	    rob_table_n[CDB_packet_in[0].tag].take_branch = CDB_packet_in[0].take_branch;
	    rob_table_n[CDB_packet_in[0].tag].NPC = CDB_packet_in[0].NPC;
	    rob_table_n[CDB_packet_in[0].tag].halt = CDB_packet_in[0].halt;
	    rob_table_n[CDB_packet_in[1].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[1].tag].value = CDB_packet_in[1].value;
	    rob_table_n[CDB_packet_in[1].tag].take_branch = CDB_packet_in[1].take_branch;
	    rob_table_n[CDB_packet_in[1].tag].NPC = CDB_packet_in[1].NPC;
	    rob_table_n[CDB_packet_in[1].tag].halt = CDB_packet_in[1].halt;
	end else begin
	    rob_table_n[CDB_packet_in[0].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[0].tag].value = CDB_packet_in[0].value;
	    rob_table_n[CDB_packet_in[0].tag].take_branch = CDB_packet_in[0].take_branch;
	    rob_table_n[CDB_packet_in[0].tag].NPC = CDB_packet_in[0].NPC;
	    rob_table_n[CDB_packet_in[0].tag].halt = CDB_packet_in[0].halt;
	    rob_table_n[CDB_packet_in[1].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[1].tag].value = CDB_packet_in[1].value;
	    rob_table_n[CDB_packet_in[1].tag].take_branch = CDB_packet_in[1].take_branch;
	    rob_table_n[CDB_packet_in[1].tag].NPC = CDB_packet_in[1].NPC;
	    rob_table_n[CDB_packet_in[1].tag].halt = CDB_packet_in[1].halt;
	    rob_table_n[CDB_packet_in[2].tag].value_flag = 1;
	    rob_table_n[CDB_packet_in[2].tag].value = CDB_packet_in[2].value;
	    rob_table_n[CDB_packet_in[2].tag].take_branch = CDB_packet_in[2].take_branch;
	    rob_table_n[CDB_packet_in[2].tag].NPC = CDB_packet_in[2].NPC;
	    rob_table_n[CDB_packet_in[2].tag].halt = CDB_packet_in[2].halt;
	end
    end

    assign RT_packet_out[0].dest_reg_idx = (~rob_table[head].value_flag) ? 5'b00000 : rob_table[head].reg_id;
	assign RT_packet_out[0].tag = (~rob_table[head].value_flag) ? '{$clog2(`ROBLEN) {0}}: head;
    assign RT_packet_out[0].value = rob_table[head].value;
    assign RT_packet_out[0].take_branch = (~rob_table[head].value_flag) ? 0 : rob_table[head].take_branch;
    assign RT_packet_out[0].NPC = rob_table[head].NPC;
    assign RT_packet_out[0].halt = rob_table[head].halt;
    assign RT_packet_out[0].valid = rob_table[head].value_flag;
    assign RT_packet_out[1].dest_reg_idx = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag) ? 5'b00000 : 
						rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].reg_id;
	assign RT_packet_out[1].tag = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag) ? '{$clog2(`ROBLEN) {0}} : 
						head_plus1[$clog2(`ROBLEN)-1:0];
    assign RT_packet_out[1].value = rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value;
    assign RT_packet_out[1].take_branch = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag) ? 0 : 
						rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].take_branch;
    assign RT_packet_out[1].NPC = rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].NPC;
    assign RT_packet_out[1].halt = rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].halt;
    //assign RT_packet_out[1].valid = ~((rob_table[head].rd_wr_mem) && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && rob_table[head].value_flag 
		//&& rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag;
    assign RT_packet_out[1].valid = RT_packet_out[0].valid && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag && ~(rob_table[head].rd_wr_mem && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) ;
    assign RT_packet_out[2].dest_reg_idx = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag || 
						~rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag) ? 5'b00000 : rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].reg_id;
	assign RT_packet_out[2].tag = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag || 
						~rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag) ? '{$clog2(`ROBLEN) {0}} : head_plus2[$clog2(`ROBLEN)-1:0];
    assign RT_packet_out[2].value = rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value;
    assign RT_packet_out[2].take_branch = (~rob_table[head].value_flag || ~rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag || 
						~rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag) ? 0 : rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].take_branch;
    assign RT_packet_out[2].NPC = rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].NPC;
    assign RT_packet_out[2].halt = rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].halt;
    //assign RT_packet_out[2].valid = ~(((rob_table[head].rd_wr_mem || rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && 
		//rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].rd_wr_mem) || ((rob_table[head].rd_wr_mem) && 
		//rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem)) && rob_table[head].value_flag && rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].value_flag && 
		//rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag;
    assign RT_packet_out[2].valid = RT_packet_out[1].valid && rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].value_flag && ~((rob_table[head].rd_wr_mem || rob_table[head_plus1[$clog2(`ROBLEN)-1:0]].rd_wr_mem) && 
					rob_table[head_plus2[$clog2(`ROBLEN)-1:0]].rd_wr_mem);
    


    assign RS_packet_out[0].V1 = rob_table[MT_packet_in[0].T1].value;
    assign RS_packet_out[0].V2 = rob_table[MT_packet_in[0].T2].value;
    assign RS_packet_out[0].valid1 = rob_table[MT_packet_in[0].T1].busy;
    assign RS_packet_out[0].valid2 = rob_table[MT_packet_in[0].T2].busy;
    assign RS_packet_out[0].T = tail;
    assign RS_packet_out[1].V1 = rob_table[MT_packet_in[1].T1].value;
    assign RS_packet_out[1].V2 = rob_table[MT_packet_in[1].T2].value;
    assign RS_packet_out[1].valid1 = rob_table[MT_packet_in[0].T1].busy;
    assign RS_packet_out[1].valid2 = rob_table[MT_packet_in[0].T2].busy;
    assign RS_packet_out[1].T = tail_plus1[$clog2(`ROBLEN)-1:0];
    assign RS_packet_out[2].V1 = rob_table[MT_packet_in[2].T1].value;
    assign RS_packet_out[2].V2 = rob_table[MT_packet_in[2].T2].value;
    assign RS_packet_out[2].valid1 = rob_table[MT_packet_in[0].T1].busy;
    assign RS_packet_out[2].valid2 = rob_table[MT_packet_in[0].T2].busy;
    assign RS_packet_out[2].T = tail_plus2[$clog2(`ROBLEN)-1:0];


    assign MT_packet_out[0].T = tail;
    assign MT_packet_out[0].R = (DP_packet_in[0].dest_reg_valid) ? DP_packet_in[0].dest_reg_idx : 5'b00000;
    assign MT_packet_out[0].valid = (DP_packet_in[0].illegal || ~DP_packet_in[0].dest_reg_valid) ? 0 : 1;
    assign MT_packet_out[1].T = tail_plus1[$clog2(`ROBLEN)-1:0];
    assign MT_packet_out[1].R = (DP_packet_in[1].dest_reg_valid) ? DP_packet_in[1].dest_reg_idx : 5'b00000;
    assign MT_packet_out[1].valid = (DP_packet_in[1].illegal || ~DP_packet_in[1].dest_reg_valid) ? 0 : 1;
    assign MT_packet_out[2].T = tail_plus2[$clog2(`ROBLEN)-1:0];
    assign MT_packet_out[2].R = (DP_packet_in[2].dest_reg_valid) ? DP_packet_in[2].dest_reg_idx : 5'b00000;
    assign MT_packet_out[2].valid = (DP_packet_in[2].illegal || ~DP_packet_in[2].dest_reg_valid) ? 0 : 1;


/*
    genvar i;
    for (i = 0; i < `ROBLEN; i++) begin
        assign rob_table_n[i].busy = (head_n < tail_n) ? (i >= head_n && i < tail_n) : 
					(head_n == tail_n) ? 0 : (i >= head_n || i < tail_n);
    end //can't distinguish between all full and emtpy; use empty_bit, or change busy when allocate/retire, or extra bit for head/tail

    				1'b0,         //busy
    				1'b0,         //value_flag
				5'b00000,     //reg_id
    				{`XLEN{1'b0}},//value
				1'b0	      //take_branch
				
*/    

    always_comb begin
	// $display("rob_T[0]:%h rob_R[0]:%h rob_valid[0]:%b des_reg_valid[0]:%b RS_packet_out[0].valid1:%b RS_packet_out[0].valid2:%b", MT_packet_out[0].T, MT_packet_out[0].R, MT_packet_out[0].valid, DP_packet_in[0].dest_reg_valid, RS_packet_out[0].valid1, RS_packet_out[0].valid2);
	// 	$display("rob_T[1]:%h rob_R[1]:%h rob_valid[1]:%b des_reg_valid[1]:%b", MT_packet_out[1].T, MT_packet_out[1].R, MT_packet_out[1].valid, DP_packet_in[1].dest_reg_valid);
	// 	$display("rob_T[2]:%h rob_R[2]:%h rob_valid[2]:%b des_reg_valid[2]:%b", MT_packet_out[2].T, MT_packet_out[2].R, MT_packet_out[2].valid, DP_packet_in[2].dest_reg_valid);
	// 	$display("head:%h tail:%h, count:%d", head, tail, count);
        count = 0;
        for (int k = 0; k < `ROBLEN; k++) begin
                if (~rob_table[k].busy) begin
                    count = count + 1;
                end
        end
    end
    assign IF_packet_out.empty_num = (count>3) ? 3 : count;

    always_ff @(posedge clock) begin
        if (reset || squash_flag) begin
            rob_table    <= '{`ROBLEN {0}};
            head         <=  0;
            tail         <=  0;
        //end else if (enable) begin
	end begin
            rob_table     <= rob_table_n;
            head         <=  head_n;
            tail         <=  tail_n;
        end
    end



endmodule
