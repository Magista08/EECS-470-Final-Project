`include "../sys_defs.svh"
`include "../ISA.svh"

module testbench;
    logic                           clock, reset, enable;
    logic                           clear;
    logic            [4:0]          other_dest_reg1;
    logic            [4:0]          other_dest_reg2;
    logic   [`RSLEN-1:0]   line_id;
    logic   [$clog2(`ROBLEN)-1:0]   other_T1;
    logic   [$clog2(`ROBLEN)-1:0]   other_T2;
    logic           [1:0]           my_position;
    DP_IS_PACKET 		            dp_packet_in;
    MT_RS_PACKET  	                mt_packet_in;
    ROB_RS_PACKET		            rob_packet_in;
    CDB_RS_PACKET	[2:0]	        cdb_packet_in;

    logic                           not_ready_out;
    RS_LINE                         rs_line_out;

    RS_ONE_LINE DUT( //Should correct "RS_LINE"
        //input
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear(clear),
        .other_dest_reg1(other_dest_reg1),
        .other_dest_reg2(other_dest_reg2),
        .line_id(line_id),
        .other_T1(other_T1),
        .other_T2(other_T2),
        .my_position(my_position),
        .dp_packet(dp_packet_in),
        .mt_packet(mt_packet_in),
        .rob_packet(rob_packet_in),
        .cdb_packet(cdb_packet_in),

        //output
        .not_ready(not_ready_out),
        .rs_line(rs_line_out)
    );

    always begin
        #10;
        clock = ~clock;
    end
	
	
	

    initial begin
        $monitor("time:%4.0f  clock:%b  not_ready:%b  rs_line_ID:%h  rs_line_inst:%h  busy:%h  V1:%h V2:%h",
                $time, clock, not_ready_out, rs_line_out.RSID, rs_line_out.inst, rs_line_out.busy, rs_line_out.V1, rs_line_out.V2);
        clock   = 0;
        reset   = 1;
        enable  = 1;
        clear   = 0;
        //squash_flag = 0;
        other_dest_reg1 = 5'b00000;
        other_dest_reg2 = 5'b00000;
        line_id = 0;
        other_T1 = 0;
        other_T2 = 0;
        my_position = 0;
    
        dp_packet_in  = {
            `NOP,             //NOP
            {`XLEN{1'b0}},    // PC + 4
            {`XLEN{1'b0}},     // PC

            {`XLEN{1'b0}},    // reg A value 
            {`XLEN{1'b0}},    // reg B value

            OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
            OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

            `ZERO_REG,    // destination (writeback) register index
            ALU_ADD,     // ALU function select (ALU_xxx *)
            1'b0,    //rd_mem
            1'b0,    //wr_mem
            1'b0,    //cond
            1'b0,    //uncond
            1'b0,    //halt
            1'b0,    //illegal
            1'b0,    //csr_op
            1'b1,    //valid
            1'b0,    //rs1_insn
            1'b0     //rs2_insn
        };

        mt_packet_in.T1_plus = 0;
        mt_packet_in.T2_plus = 0;
        mt_packet_in.T1      = {$clog2(`ROBLEN){1'b0}};
        mt_packet_in.T2      = {$clog2(`ROBLEN){1'b0}};
        mt_packet_in.valid1  = 0;
        mt_packet_in.valid2  = 0;

        rob_packet_in.V1     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.T      = {$clog2(`ROBLEN){1'b0}};
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 0;

        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].valid = 0;
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 1: Pass an INST ADD to one RS line                             //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////

        dp_packet_in  = {
                32'hdead_face,        // ADD
                {`XLEN{1'b0}},    // PC + 4
                {`XLEN{1'b0}},     // PC

                {`XLEN'h0000_0001},    // reg A value 
                {`XLEN'h0000_0002},    // reg B value

                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                5'b00010,    // destination (writeback) register index
                ALU_ADD,     // ALU function select (ALU_xxx *)
                1'b0,    //rd_mem
                1'b0,    //wr_mem
                1'b0,    //cond
                1'b0,    //uncond
                1'b0,    //halt
                1'b0,    //illegal
                1'b0,    //csr_op
                1'b1,    //valid
                1'b1,    //rs1_insn
                1'b1     //rs2_insn
        };

		@(negedge clock);
		enable = 0;
		@(negedge clock); 
        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 2: enable = 0                                                  //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		dp_packet_in  = {
                $random,        // ADD
                {`XLEN{1'b0}},    // PC + 4
                {`XLEN{1'b0}},     // PC

                $random,    // reg A value 
                $random,    // reg B value

                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                5'b11000,    // destination (writeback) register index
                ALU_ADD,     // ALU function select (ALU_xxx *)
                1'b0,    //rd_mem
                1'b0,    //wr_mem
                1'b0,    //cond
                1'b0,    //uncond
                1'b0,    //halt
                1'b0,    //illegal
                1'b0,    //csr_op
                1'b1,    //valid
                1'b1,    //rs1_insn
                1'b1     //rs2_insn
        };
            

        @(negedge clock);
        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 3: Clear the line                                              //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		clear = 1;
		@(negedge clock);
		clear = 0;
		@(negedge clock);
		$display("The line has been cleared!");
		$display("not_ready:%b  rs_line_ID:%h  rs_line_inst:%h  busy:%h  V1:%h V2:%h",
                not_ready_out, rs_line_out.RSID, rs_line_out.inst, rs_line_out.busy, rs_line_out.V1, rs_line_out.V2);
				
		@(negedge clock);		
		/////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 4: CDB TAG TEST                                                //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		
				
		enable = 1;
		other_dest_reg1 = 5'b00001;
        other_dest_reg2 = 5'b00010;
		other_T1 = 6'b000001;
        other_T2 = 6'b000010;
		my_position = 2'b11;
		@(negedge clock);
		$display("Cycle 1");
		dp_packet_in  = {
                32'h0020_81b3,        // R3 = R1 + R2
                {`XLEN{1'b0}},    // PC + 4
                {`XLEN{1'b0}},     // PC

                {`XLEN'h1111_1111},    // reg A value 
                {`XLEN'hcccc_cccc},    // reg B value

                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                5'b10101,    // destination (writeback) register index
                ALU_ADD,     // ALU function select (ALU_xxx *)
                1'b0,    //rd_mem
                1'b0,    //wr_mem
                1'b0,    //cond
                1'b0,    //uncond
                1'b0,    //halt
                1'b0,    //illegal
                1'b0,    //csr_op
                1'b1,    //valid
                1'b1,    //rs1_insn
                1'b1     //rs2_insn
            };
			
		mt_packet_in.T1_plus = 0;
        mt_packet_in.T2_plus = 0;
        mt_packet_in.T1      = 6'b000001;
        mt_packet_in.T2      = 6'b000010;
        mt_packet_in.valid1  = 1;
        mt_packet_in.valid2  = 1;
		
		
		rob_packet_in.V1     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.T      = 6'b000011;
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 0;

        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].valid = 0;
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;
		
		@(negedge clock);
		$display("Cycle 2");
		enable = 0;
		
		/////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 4                                                              //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		mt_packet_in.T1_plus = 1;
        mt_packet_in.T2_plus = 0;
        mt_packet_in.T1      = 6'b000001;
        mt_packet_in.T2      = 6'b000010;
        mt_packet_in.valid1  = 1;
        mt_packet_in.valid2  = 1;
		
	    rob_packet_in.V1     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.T      = 6'b000011;
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 0;

        cdb_packet_in[0].tag   = 6'b000001;
        cdb_packet_in[0].value = 32'haaaa_0000;
        cdb_packet_in[0].valid = 1;

        cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].valid = 0;
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;
		
		
		@(negedge clock);
		$display("Cycle 3");
		/////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 4:                                                             //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		mt_packet_in.T1_plus = 1;
        mt_packet_in.T2_plus = 1;
        mt_packet_in.T1      = 6'b000001;
        mt_packet_in.T2      = 6'b000010;
        mt_packet_in.valid1  = 1;
        mt_packet_in.valid2  = 1;
		
	    rob_packet_in.V1     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.T      = 6'b000011;
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 0;

        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        cdb_packet_in[1].tag   = 6'b000010;
        cdb_packet_in[1].value = 32'h0000_bbbb;
        cdb_packet_in[1].valid = 1;
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;
		@(negedge clock);
		clear = 1;
		
		@(negedge clock);
		clear = 0;
		$display("test 4 complete, rs_line is cleared");
		/////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 5:    Value from ROB                                            //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
		$display("test 5 begin, value from ROB");
		enable = 1;
		other_dest_reg1 = 5'b00001;
        other_dest_reg2 = 5'b00010;
		other_T1 = 6'b000001;
        other_T2 = 6'b000010;
		my_position = 2'b11;
		@(negedge clock);

		dp_packet_in  = {
                32'h0020_81b3,        //  R3 = R1 + R2
                {`XLEN{1'b0}},    // PC + 4
                {`XLEN{1'b0}},     // PC

                {`XLEN'h1111_1111},    // reg A value 
                {`XLEN'hcccc_cccc},    // reg B value

                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                5'b10101,    // destination (writeback) register index
                ALU_ADD,     // ALU function select (ALU_xxx *)
                1'b0,    //rd_mem
                1'b0,    //wr_mem
                1'b0,    //cond
                1'b0,    //uncond
                1'b0,    //halt
                1'b0,    //illegal
                1'b0,    //csr_op
                1'b1,    //valid
                1'b1,    //rs1_insn
                1'b1     //rs2_insn
            };
			
		mt_packet_in.T1_plus = 0;
        mt_packet_in.T2_plus = 0;
        mt_packet_in.T1      = 6'b000001;
        mt_packet_in.T2      = 6'b000010;
        mt_packet_in.valid1  = 1;
        mt_packet_in.valid2  = 1;
		
		
	    rob_packet_in.V1     = 32'haaaa_0000;
        rob_packet_in.V2     = 32'h0000_bbbb;
        rob_packet_in.T      = 6'b000011;
        rob_packet_in.valid1 = 1;
        rob_packet_in.valid2 = 1;

        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].valid = 0;
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;
		@(negedge clock);
		clear = 1;
		@(negedge clock);
		clear = 0;
		$display("test 5 complete");
        $display("@@@ Passed \n ");    
        $finish;
    end

endmodule
