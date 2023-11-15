`include "../sys_defs.svh"
`include "../ISA.svh"

module testbench;
    // init
    logic clock, reset;
    IF_ID_PACKET [`N-1:0] if_id_packet_in, if_id_reg_in;
    RT_PACKET    [`N-1:0] rt_packet_in, re_reg_in;
    DP_PACKET    [`N-1:0] dp_packet_out, dp_packet_check, dp_reg_check;

    //??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????//
    logic inst_show, rs_value_show;

    assign inst_show = 1'b0;
    assign rs_value_show = 1'b1;

    // Check    
    logic [`N-1:0] correct_lines;
    always_comb begin
        for (int i=0; i < `N; i++) begin
            correct_lines[i] = (dp_packet_out[i].inst      == dp_reg_check[i].inst) &&
                               (dp_packet_out[i].rs1_value == dp_reg_check[i].rs1_value) &&
                               (dp_packet_out[i].rs2_value == dp_reg_check[i].rs2_value);
        end
    end

    // Print Incorrect info
    always_ff @(negedge clock) begin
        if (~correct_lines) begin
            if (inst_show) begin
                $display("@@@ Incorrect at time %4.0f\n", $time);
                $display("if_id_reg_in[0].inst:    %h if_id_reg_in[1].inst:    %h, if_id_reg_in[2].inst:    %h", if_id_reg_in[0].inst, if_id_reg_in[1].inst, if_id_reg_in[2].inst);
                $display("if_id_packet_in[0].inst: %h if_id_packet_in[1].inst: %h, if_id_packet_in[2].inst: %h", if_id_packet_in[0].inst, if_id_packet_in[1].inst, if_id_packet_in[2].inst);
                $display("dp_packet_out[0].inst:   %h dp_packet_out[1].inst:   %h, dp_packet_out[2].inst:   %h", dp_packet_out[0].inst, dp_packet_out[1].inst, dp_packet_out[2].inst);
                $display("dp_packet_check[0].inst: %h dp_packet_check[1].inst: %h, dp_packet_check[2].inst: %h", dp_packet_check[0].inst, dp_packet_check[1].inst, dp_packet_check[2].inst);
                $display("dp_reg_check[0].inst:    %h dp_reg_check[1].inst:    %h, dp_reg_check[2].inst:    %h", dp_reg_check[0].inst, dp_reg_check[1].inst, dp_reg_check[2].inst);
            end

            if (rs_value_show) begin
                $display("@@@ Incorrect at time %4.0f\n", $time);
                $display("dp_packet_out[0].rs1_value: %h dp_packet_out[1].rs1_value: %h, dp_packet_out[2].rs1_value: %h", dp_packet_out[0].rs1_value, dp_packet_out[1].rs1_value, dp_packet_out[2].rs1_value);
                $display("dp_reg_check[0].rs1_value:    %h dp_reg_check[1].rs1_value:    %h, dp_reg_check[2].rs1_value:    %h", dp_reg_check[0].inst, dp_reg_check[1].rs1_value, dp_reg_check[2].rs1_value);
                $display("dp_packet_out[0].rs2_value: %h dp_packet_out[1].rs2_value: %h, dp_packet_out[2].rs2_value: %h", dp_packet_out[0].rs2_value, dp_packet_out[1].rs2_value, dp_packet_out[2].rs2_value);
                $display("dp_reg_check[0].rs2_value:    %h dp_reg_check[1].rs2_value:    %h, dp_reg_check[2].rs2_value:    %h", dp_reg_check[0].rs2_value, dp_reg_check[1].rs2_value, dp_reg_check[2].rs2_value);
            end
            $finish;
        end

    end
    //??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????//
    always_ff @(posedge clock) begin
        if_id_reg_in <= if_id_packet_in;
        re_reg_in <= rt_packet_in;
        dp_reg_check <= dp_packet_check;
    end

    // Module
    DP dut (
        // input
        .clock(clock),
        .reset(reset),
        .if_id_packet(if_id_reg_in),
        .rt_packet(re_reg_in),

        // output
        .dp_packet(dp_packet_out)
    );

    // Change the clock
    always begin
        #15;
        clock = ~clock;
    end

    // Main part
    initial begin
        // Display Info
        $monitor("Clock:%b dp_packet_out[0].inst: %h dp_packet_out[1].inst: %h, dp_packet_out[2].inst: %h \n\
Clock:%b dp_reg_check[0].inst: %h dp_reg_check[1].inst:  %h, dp_reg_check[2].inst:%h",
                  clock, dp_packet_out[0].inst, dp_packet_out[1].inst, dp_packet_out[2].inst, 
                  clock, dp_reg_check[0].inst, dp_reg_check[1].inst, dp_reg_check[2].inst);

        // reset
        clock = 0;
        reset = 1;

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //                                                  Test 1                                                        //
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // decode for three packet with all NOP, and write the three value in dest [0-2] value into the file 
        for (int i=0; i < `N; i++) begin
            // Input
            if_id_packet_in[i] = {
                `NOP,          // inst
                {`XLEN{1'b0}}, // PC
                {`XLEN{1'b0}}, // NPC
                1'b0           // valid
            };

            // Input
            rt_packet_in[i] = {
                i+1,                       // dest_Reg_idx
                4 + i,                   // value
                {$clog2(`ROBLEN){1'b0}}, // ROB#, NOT NEED TO TEST IN THIS STAGE
                1'b1,                    // valid
                1'b1,                    // wr_en
                1'b0,                    // illegal
                1'b0,                    // Hold
                {`XLEN{1'b0}}            // PC
            };

            // Output
            dp_packet_check[i] = {
                `NOP,          // inst
                {`XLEN{1'b0}}, // PC
                {`XLEN{1'b0}}, // NPC
                {`XLEN{1'b0}}, // reg A 
                {`XLEN{1'b0}}, // reg B
                
                OPA_IS_RS1,    // opa_select
                OPB_IS_RS2,    // opb_select
                
                `ZERO_REG,     // dest_reg_idx
                ALU_ADD,       // alu_func
                
                1'b0,          // rd_mem
                1'b0,          // wr_mem
                1'b0,          // cond_branch
                1'b0,          // uncond_branch
                1'b0,          // halt
                1'b0,          // illegal
                1'b0,          // csr_op
                1'b0,          // valid
                1'b0,          // rs1_instruction
                1'b0,          // rs2_instruction
                1'b1,          // dest_reg_valid
                FUNC_ALU       // func_unit
            };
        end

        // Reset
        #30;

        // Show info
        $display("\nBeginning for test 1\n");
        reset = 0;
        #30;
        #15;

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //                                                  Test 2                                                        //
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        for (int i=0; i < `N; i++) begin
            // Input
            rt_packet_in[i] = {
                3+i,                       // dest_Reg_idx
                7+i,                   // value
                {$clog2(`ROBLEN){1'b0}}, // ROB#, NOT NEED TO TEST IN THIS STAGE
                1'b1,                    // valid
                1'b1,                    // wr_en
                1'b0,                    // illegal
                1'b0,                    // Hold
                {`XLEN{1'b0}}            // PC
            };

            // Output
            dp_packet_check[i] = {
                `RV32_ADD,          // inst
                {`XLEN{1'b0}}, // PC
                {`XLEN{1'b0}}, // NPC
                {`XLEN{1'b0}} + 3'd4, // reg A 
                {`XLEN{1'b0}}  + 3'd5, // reg B
                
                OPA_IS_RS1,    // opa_select
                OPB_IS_RS2,    // opb_select
                
                4'h3,     // dest_reg_idx
                ALU_ADD,       // alu_func
                
                1'b0,          // rd_mem
                1'b0,          // wr_mem
                1'b0,          // cond_branch
                1'b0,          // uncond_branch
                1'b0,          // halt
                1'b0,          // illegal
                1'b0,          // csr_op

                1'b1,          // valid
                1'b1,          // rs1_instruction
                1'b1,          // rs2_instruction
                1'b1,          // dest_reg_valid
                2'h1       // func_unit
            };
        end
        rt_packet_in[2].dest_reg_idx = 6;
        // Input
        if_id_packet_in[0] = {
            `RV32_ADD,          // inst
            {`XLEN{1'b0}}, // PC
            {`XLEN{1'b0}}, // NPC
            1'b1           // valid
        };
        if_id_packet_in[0].inst.r.rs1 = 1;
        if_id_packet_in[0].inst.r.rs2 = 2;
        if_id_packet_in[0].inst.r.rd  = 3;

        if_id_packet_in[1] = {
            `RV32_ADD,          // inst
            {`XLEN{1'b0}}, // PC
            {`XLEN{1'b0}}, // NPC
            1'b1           // valid
        };
        if_id_packet_in[1].inst.r.rs1 = 4;
        if_id_packet_in[1].inst.r.rs2 = 2;
        if_id_packet_in[1].inst.r.rd  = 3;

        if_id_packet_in[2] = {
            `RV32_LW,          // inst
            {`XLEN{1'b0}}, // PC
            {`XLEN{1'b0}}, // NPC
            1'b1           // valid
        };
        if_id_packet_in[2].inst.r.rs1 = 4;
        if_id_packet_in[2].inst.r.rs2 = 4;
        if_id_packet_in[2].inst.r.rd  = 3;

        // Output
        dp_packet_check[0].inst = if_id_packet_in[0].inst;
        dp_packet_check[0].rs1_value = 4;
        dp_packet_check[0].rs2_value = 5;

        dp_packet_check[1].inst = if_id_packet_in[1].inst;
        dp_packet_check[1].rs1_value = 8;
        dp_packet_check[1].rs2_value = 5;

        dp_packet_check[2].inst = if_id_packet_in[2].inst;
        dp_packet_check[2].rs1_value = 8;
        dp_packet_check[2].rs2_value = 8;

        // Test 2
        $display("\nBeginning for test 2\n");
        #30;
        #15;

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //                                                  Test 3                                                        //
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        for (int i=0; i < `N; i++) begin
            // Input
            rt_packet_in[i] = {
                4'b0,                       // dest_Reg_idx
                {`XLEN{1'b0}},                   // value
                {$clog2(`ROBLEN){1'b0}}, // ROB#, NOT NEED TO TEST IN THIS STAGE
                1'b0,                    // valid
                1'b0,                    // wr_en
                1'b0,                    // illegal
                1'b0,                    // Hold
                {`XLEN{1'b0}}            // PC
            };

            // Input
            if_id_packet_in[i] = {
                `NOP,          // inst
                {`XLEN{1'b0}}, // PC
                {`XLEN{1'b0}}, // NPC
                1'b0           // valid
            };

            // Output
            dp_packet_check[i] = {
                `NOP,          // inst
                {`XLEN{1'b0}}, // PC
                {`XLEN{1'b0}}, // NPC
                {`XLEN{1'b0}}, // reg A 
                {`XLEN{1'b0}}, // reg B
                
                OPA_IS_RS1,    // opa_select
                OPB_IS_RS2,    // opb_select
                
                `ZERO_REG,     // dest_reg_idx
                ALU_ADD,       // alu_func
                
                1'b0,          // rd_mem
                1'b0,          // wr_mem
                1'b0,          // cond_branch
                1'b0,          // uncond_branch
                1'b0,          // halt
                1'b0,          // illegal
                1'b0,          // csr_op
                1'b0,          // valid
                1'b0,          // rs1_instruction
                1'b0,          // rs2_instruction
                1'b1,          // dest_reg_valid
                FUNC_ALU       // func_unit
            };
        end

        if_id_packet_in[1] = {
            `RV32_ADD,          // inst
            {`XLEN{1'b0}}, // PC
            {`XLEN{1'b0}}, // NPC
            1'b0           // valid
        };
        if_id_packet_in[1].inst.r.rs1 = 3;
        if_id_packet_in[1].inst.r.rs2 = 6;
        if_id_packet_in[1].inst.r.rd  = 5;

        dp_packet_check[1] = {
            `RV32_ADD,          // inst
            {`XLEN{1'b0}}, // PC
            {`XLEN{1'b0}}, // NPC
            {`XLEN{1'b0}} + 3'd7, // reg A 
            {`XLEN{1'b0}} + 4'd9, // reg B
            
            OPA_IS_RS1,    // opa_select
            OPB_IS_RS2,    // opb_select
            
            `ZERO_REG,     // dest_reg_idx
            ALU_ADD,       // alu_func
            
            1'b0,          // rd_mem
            1'b0,          // wr_mem
            1'b0,          // cond_branch
            1'b0,          // uncond_branch
            1'b0,          // halt
            1'b0,          // illegal
            1'b0,          // csr_op
            1'b0,          // valid
            1'b0,          // rs1_instruction
            1'b0,          // rs2_instruction
            1'b1,          // dest_reg_valid
            FUNC_ALU       // func_unit
        };
        dp_packet_check[1].inst = if_id_packet_in[1].inst;
        
        // Test 3
        $display("\nBeginning for test 3\n");
        #30;

        $display("@@@ Passed all test cases at time %4.0f\n", $time);
        $finish;
    end
endmodule