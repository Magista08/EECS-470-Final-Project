`include "../sys_defs.svh"
`include "../ISA.svh"

module testbench;
    logic                           clock, reset, enable;
    logic                           clear;
    logic   [4:0]                   other_dest_reg1;
    logic   [4:0]                   other_dest_reg2;
    logic   [$clog2(`ROBLEN)-1:0]   line_id;
    logic   [$clog2(`ROBLEN)-1:0]   other_T1;
    logic   [$clog2(`ROBLEN)-1:0]   other_T2;
    logic           [1:0]           my_position;
    DP_PACKET 		            dp_packet_in;
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
        //.sel(sel),
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
        $monitor("time:%4.0f clock:%b not_ready:%b rs_line_T:%h rs_line_T1:%h rs_line_T2:%h rs_line_inst_rs1:%h rs_line_inst_rs2:%h busy:%h V1:%h V2:%h reset:%h;",
                $time, clock, not_ready_out, rs_line_out.T, rs_line_out.T1, rs_line_out.T2, rs_line_out.inst.r.rs1, rs_line_out.inst.r.rs2, rs_line_out.busy, rs_line_out.V1, rs_line_out.V2, reset);
        clock   = 0;
        reset   = 1;
        enable  = 1;
        clear   = 0;
        other_dest_reg1 = 0;
        other_dest_reg2 = 0;
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

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 1: rs1 RAW, rs2 can from CDB: f or ROB: ffff_ffff              //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////

	    // MT
        mt_packet_in.T1_plus = 0;
        mt_packet_in.T2_plus = 1;
        mt_packet_in.T1      = {$clog2(`ROBLEN){1'b0}};
        // mt_packet_in.T2      = {$clog2(`ROBLEN){1'b0}};
        mt_packet_in.T2      = 3'b111;
        mt_packet_in.valid1  = 1;// ?
        mt_packet_in.valid2  = 1;


        // ROB
        rob_packet_in.V1     = {`XLEN{1'b0}};
        // rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN'hffffffff};
        rob_packet_in.T      = {$clog2(`ROBLEN){1'b0}};
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 1;


        // CDB
        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        //cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].tag   = 3'b111;
        //cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].value = 4'b1111; // f
        cdb_packet_in[1].valid = 0; // 应该比rob优先(同时需要maptable的Tag和cdb_packet_in[1].tag匹配)
    
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;

            dp_packet_in  = {
                32'h002081b3,        // add x3, x1, x2
                {`XLEN{1'b0}},       // PC + 4
                {`XLEN{1'b0}},       // PC

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

            other_dest_reg1 = 5'b00001; // x1 should match
            other_dest_reg2 = 5'b00011; // x2 not match
            other_T1 = 3'b001; // should match and appear in rs_line tag1
            other_T2 = 3'b010; // no match and not in rs_line tag2
            my_position = 2'b10;

            $display("rs1 RAW, value doesnt matter, rs2 from ROB: ffff_ffff");

            @(negedge clock);
	        enable = 0;

            if (rs_line_out.inst.r.rs1==other_dest_reg1) begin
                $display("rs1 match");
            end else begin
                $display("rs1 not match");
            end
            if (rs_line_out.inst.r.rs2==other_dest_reg2) begin
                $display("rs2 match");
            end else begin
                $display("rs2 not match");
            end

            @(negedge clock);
            @(negedge clock);




        /////////////////////////////////////////////////////////////////////////
        //                                                                     //
        // test 2: No hazard and can ISSUE                                     //
        //                                                                     //
        /////////////////////////////////////////////////////////////////////////
	    reset = 1;
        clear = 1;
	    @(negedge clock);
        @(negedge clock);
        reset = 0;
        clear = 0;
        enable = 1;

        // MT
        mt_packet_in.T1_plus = 0;
        mt_packet_in.T2_plus = 0;
        mt_packet_in.T1      = {$clog2(`ROBLEN){1'b0}};
        mt_packet_in.T2      = {$clog2(`ROBLEN){1'b0}};
        mt_packet_in.valid1  = 0;
        mt_packet_in.valid2  = 0;


        // ROB
        rob_packet_in.V1     = {`XLEN{1'b0}};
        rob_packet_in.V2     = {`XLEN{1'b0}};
        rob_packet_in.T      = {$clog2(`ROBLEN){1'b0}};
        rob_packet_in.valid1 = 0;
        rob_packet_in.valid2 = 0;


        // CDB
        cdb_packet_in[0].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[0].value = {`XLEN{1'b0}};
        cdb_packet_in[0].valid = 0;

        cdb_packet_in[1].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[1].value = {`XLEN{1'b0}};
        cdb_packet_in[1].valid = 0; 
        cdb_packet_in[2].tag   = {$clog2(`ROBLEN){1'b0}};
        cdb_packet_in[2].value = {`XLEN{1'b0}};
        cdb_packet_in[2].valid = 0;

            dp_packet_in  = {
                32'h002081b3,        // add x3, x1, x2
                {`XLEN{1'b0}},       // PC + 4
                {`XLEN{1'b0}},       // PC

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

            other_dest_reg1 = 5'b00011; // x1 not match
            other_dest_reg2 = 5'b00011; // x2 not match
            other_T1 = 3'b001; 
            other_T2 = 3'b010; 
            my_position = 2'b10;

            $display("No hazard and can ISSUE");

            @(negedge clock);
	    enable = 0;

            if (rs_line_out.inst.r.rs1==other_dest_reg1) begin
                $display("rs1 match");
            end else begin
                $display("rs1 not match");
            end
            if (rs_line_out.inst.r.rs2==other_dest_reg2) begin
                $display("rs2 match");
            end else begin
                $display("rs2 not match");
            end

            @(negedge clock);
            @(negedge clock);	
	
        $display("Test complete! \n ");    
        $finish;
    end

endmodule
