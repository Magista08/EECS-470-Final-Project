`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module testbench;
    logic                               clock, reset, enable;
    logic                               squash_flag;
    MT_RS_PACKET          [2:0]         mt_rs_in;
    DP_IS_PACKET          [2:0]         dp_packet_in;
    ROB_RS_PACKET         [2:0]         rob_in; 
    CDB_RS_PACKET         [2:0]         cdb_in;
   
    RS_IS_PACKET          [2:0]         is_packet_out;
    RS_DP_PACKET                        dp_packet_out;    


    RS DUT (
	    //input 
	    .clock(clock),
        .reset(reset),
        .enable(enable),
        .squash_flag(squash_flag),
        .mt_packet_in(mt_rs_in),
        .dp_packet_in(dp_packet_in),
        .rob_packet_in(rob_in),
        .cdb_packet_in(cdb_in),
        
        //output 
        .is_packet_out(is_packet_out),
        .dp_packet_out(dp_packet_out)
    );

    always begin
        #10;
        clock = ~clock;
    end
	
	// Task to clear the input
	

	
	

    initial begin
	    // $monitor("time:%4.0f  clock:%b  is_packet_out[0].inst:%h  is_packet_out[1].inst:%h  is_packet_out[2].inst:%h  dp_packet_out.empty_num:%h  is_packet_out[0].T: %h  is_packet_out[1].T: %h  is_packet_out[2].T: %h",
        //          $time, clock, is_packet_out[0].inst, is_packet_out[1].inst, is_packet_out[2].inst, dp_packet_out.empty_num, is_packet_out[0].T, is_packet_out[1].T, is_packet_out[2].T);

        $monitor("time:%4.0f  clock:%b  is_packet_out[0].inst:%h  is_packet_out[1].inst:%h  is_packet_out[2].inst:%h  dp_packet_out.empty_num:%h",
                 $time, clock, is_packet_out[0].inst, is_packet_out[1].inst, is_packet_out[2].inst, dp_packet_out.empty_num);
        clock   = 0;
        reset   = 1;
        enable  = 1;
        squash_flag = 0;


        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        //   dispatch signal                                                   //
        //                                                                     //                                                                                                                                                                                                                                                                                                                            
        /////////////////////////////////////////////////////////////////////////
            dp_packet_in[0]  = {
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

            dp_packet_in[1]  = {
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
                1'b1,     //valid
                1'b0,    //rs1_insn
                1'b0     //rs2_insn
            };

            dp_packet_in[2]  = {
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

        
        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // maptable signal                                                     //
        /////////////////////////////////////////////////////////////////////////  
            mt_rs_in[0].T1_plus = 0;
            mt_rs_in[0].T2_plus = 0;
            mt_rs_in[0].T1      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[0].T2      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[0].valid1  = 0;
            mt_rs_in[0].valid2  = 0;

            mt_rs_in[1].T1_plus = 0;
            mt_rs_in[1].T2_plus = 0;
            mt_rs_in[1].T1      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[1].T2      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[1].valid1  = 0;
            mt_rs_in[1].valid2  = 0;
        
            mt_rs_in[2].T1_plus = 0;
            mt_rs_in[2].T2_plus = 0;
            mt_rs_in[2].T1      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[2].T2      = {$clog2(`ROBLEN){1'b0}};
            mt_rs_in[2].valid1  = 0;
            mt_rs_in[2].valid2  = 0;

        
        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // rob signal                                                          //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////      
            rob_in[0].V1     = {`XLEN{1'b0}};
            rob_in[0].V2     = {`XLEN{1'b0}};
            rob_in[0].T      = {$clog2(`ROBLEN){1'b0}};
            rob_in[0].valid1 = 0;
            rob_in[0].valid2 = 0;

            rob_in[1].V1     = {`XLEN{1'b0}};
            rob_in[1].V2     = {`XLEN{1'b0}};
            rob_in[1].T      = {$clog2(`ROBLEN){1'b0}};
            rob_in[1].valid1 = 0;
            rob_in[1].valid2 = 0;

            rob_in[2].V1     = {`XLEN{1'b0}};
            rob_in[2].V2     = {`XLEN{1'b0}};
            rob_in[2].T      = {$clog2(`ROBLEN){1'b0}};
            rob_in[2].valid1 = 0;
            rob_in[2].valid2 = 0;


        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // cdb_in signal                                                       //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
            cdb_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
            cdb_in[0].value = {`XLEN{1'b0}};
            cdb_in[0].valid = 0;

            cdb_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
            cdb_in[1].value = {`XLEN{1'b0}};
            cdb_in[1].valid = 0;
        
            cdb_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
            cdb_in[2].value = {`XLEN{1'b0}};
            cdb_in[2].valid = 0;

            $display("dp_packet_in[0].inst:%h,\n dp_packet_in[1].inst:%h,\n dp_packet_in[2].insn:%h\n\n", 
                    dp_packet_in[0].inst,dp_packet_in[1].inst,dp_packet_in[2].inst );

            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            reset = 0;

        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 1: 3 NOP                                                       //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////

            for(integer k = 0; k <= 2;k ++) begin
                dp_packet_in[k]  = {
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
                    1'b0,    //rs1_inst
                    1'b0     //rs2_inst
                };

                mt_rs_in[k]      = {
                    {$clog2(`ROBLEN){1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0,
                    1'b0,
                    1'b0
                };

                rob_in[k]        = {
                    {`XLEN{1'b0}},
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0
                };
                cdb_in[k]        = {
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0
                };
            end

            $display("\ntime:   0  clock:0  dp_packet_in[0].inst:%h, dp_packet_in[1].inst:%h, dp_packet_in[2].intn:%h", 
                    dp_packet_in[0].inst,dp_packet_in[1].inst,dp_packet_in[2].inst );

            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);

           


        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 2: 3 ADD                                                       //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////

            for(integer k = 0; k <= 2;k ++) begin
                dp_packet_in[k]  = {
                    `RV32_ADD,        //ADD
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

                mt_rs_in[k]      = {
                    {$clog2(`ROBLEN){1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0,
                    1'b0,
                    1'b0
                };

                rob_in[k]        = {
                    {`XLEN{1'b0}},
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0
                };

                cdb_in[k]        = {
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0
                };
            end

            $display("dp_packet_in[0].inst:%h, dp_packet_in[1].inst:%h, dp_packet_in[2].inst:%h", 
                    dp_packet_in[0].inst,dp_packet_in[1].inst,dp_packet_in[2].inst );
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
			clear_input(
				dp_packet_in,
				cdb_in,
				rob_in,
				mt_rs_in
		    );
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);

        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 3: ADD + NOP +ADD                                              //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////

            dp_packet_in[0]  = {
                `RV32_ADD,        //ADD
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
            mt_rs_in[0]      = {
                {$clog2(`ROBLEN){1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0,
                1'b0,
                1'b0
            };
            rob_in[0]        = {
                {`XLEN{1'b0}},
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0
            };
            cdb_in[0]        = {
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0
            };

            dp_packet_in[1]  = {
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
                1'b1,     //valid
                1'b0,    //rs1_insn
                1'b0     //rs2_insn
            };
            mt_rs_in[1]      = {
                {$clog2(`ROBLEN){1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0,
                1'b0,
                1'b0
            };
            rob_in[1]        = {
                {`XLEN{1'b0}},
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0
            };
            cdb_in[1]        = {
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0
            };

            dp_packet_in[2]  = {
                `RV32_ADD,        //ADD
                {`XLEN{1'b0}},    // PC + 4
                {`XLEN{1'b0}},     // PC

                {`XLEN'h0000_0001},    // reg A value 
                {`XLEN'h0000_0002},    // reg B value

                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                5'b00011,    // destination (writeback) register index
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
            mt_rs_in[2]      = {
                {$clog2(`ROBLEN){1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0,
                1'b0,
                1'b0
            };
            rob_in[2]        = {
                {`XLEN{1'b0}},
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0,
                1'b0
            };
            cdb_in[2]        = {
                {`XLEN{1'b0}},
                {$clog2(`ROBLEN){1'b0}},
                1'b0
            };

            @(negedge clock);
			clear_input(
				dp_packet_in,
				cdb_in,
				rob_in,
				mt_rs_in
		    );
            @(negedge clock);

        	
            /////////////////////////////////////////////////////////////////////////////////
            //                                                                     //
            // test 4: 3 random insn                                                      //
            //                                                                     //
            /////////////////////////////////////////////////////////////////////////

            for(integer k = 0; k <= 2;k ++) begin
                dp_packet_in[k]  = {
                    $random,        //ADD
                    {`XLEN{1'b0}},    // PC + 4
                    {`XLEN{1'b0}},     // PC

                    $random,    // reg A value 
                    $random,    // reg B value

                    OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                    OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)

                    $random%32,    // destination (writeback) register index
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

                mt_rs_in[k]      = {
                    {$clog2(`ROBLEN){1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0,
                    1'b0,
                    1'b0
                };

                rob_in[k]        = {
                    {`XLEN{1'b0}},
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0,
                    1'b0
                };

                cdb_in[k]        = {
                    {`XLEN{1'b0}},
                    {$clog2(`ROBLEN){1'b0}},
                    1'b0
                };
            end

            $display("dp_packet_in[0].inst:%h, dp_packet_in[1].inst:%h, dp_packet_in[2].inst:%h", 
                    dp_packet_in[0].inst,dp_packet_in[1].inst,dp_packet_in[2].inst );
        
            @(negedge clock);
			clear_input(
				dp_packet_in,
				cdb_in,
				rob_in,
				mt_rs_in
		    );
            @(negedge clock);

        $display("Test complete! \n ");    
        $finish;
    end
    


endmodule