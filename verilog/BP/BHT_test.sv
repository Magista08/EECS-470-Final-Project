`include "verilog/sys_defs.svh"

module testbench;
    logic clock, reset;
    logic [`N-1:0] [`XLEN-1:0] ex_pc, ex_pc_reg, if_pc, if_pc_reg;
    logic [`N-1:0] wr_en, wr_en_reg, take_branch, take_branch_reg;
    logic [`N-1:0] [`BHTWIDTH-1:0] bht_tag_read_out, bht_tag_read_out_test, bht_tag_read_out_test_reg;
    logic [`N-1:0] [`BHTWIDTH-1:0] bht_tag_write_out, bht_tag_write_out_test, bht_tag_write_out_test_reg;

    logic [`N-1:0] correct;

    BHT bht(
        .clock(clock), 
        .reset(reset),
        .wr_en_in(wr_en_reg),
        .take_branch_in(take_branch_reg),
        .ex_pc_in(ex_pc_reg), 
        .if_pc_in(if_pc_reg),
        
        .bht_tag_read_out(bht_tag_read_out), 
        .bht_tag_write_out(bht_tag_write_out)
    );

    // Update the input
    always_ff @(posedge clock) begin
        ex_pc_reg <= ex_pc;
        if_pc_reg <= if_pc;
        wr_en_reg <= wr_en;
        take_branch_reg <= take_branch;

        bht_tag_read_out_test_reg <= bht_tag_read_out_test;
        bht_tag_write_out_test_reg <= bht_tag_write_out_test;
    end

    // Check
    // always_comb begin
    //     for (int i=0; i<`N; i=i+1) begin
    //         correct[i] = bht_tag_read_out[i] == bht_tag_read_out_test_reg[i] &&
    //                      bht_tag_write_out[i] == bht_tag_write_out_test_reg[i];
    //     end
        
    // end

    // always_ff @(negedge clock) begin
    //     for (int i=0; i<`N; i=i+1) begin
    //         if (!correct[i]) begin
    //             $display("Error!");
    //             $finish;
    //         end
    //     end
    // end

    always begin
        #5 clock = ~clock;
    end

    initial begin
        $monitor("clock=%b, bht_tag_read_out[0]=      %b, bht_tag_write_out[0]=      %b\nclock=%b, bht_tag_read_out_test[0]= %b, bht_tag_write_out_test[0]= %b\n",
                  clock, bht_tag_read_out[0], bht_tag_write_out[0], clock, bht_tag_read_out_test_reg[0], bht_tag_write_out_test_reg[0]);

        clock = 0;
        reset = 1;
        for (int i=0; i<`N; i=i+1) begin
            wr_en[i] = 0;
            take_branch[i] = 0;
            ex_pc[i] = {`XLEN{1'b0}};
            if_pc[i] = {`XLEN{1'b0}};
            bht_tag_read_out_test[i]  = {`BHTWIDTH{1'b0}};
            bht_tag_write_out_test[i] = {`BHTWIDTH{1'b0}};
        end
        take_branch[0] = 1;
        wr_en[0] = 1;
        ex_pc[0] = 'h4;
        if_pc[0] = 'h4;
        bht_tag_read_out_test[0] = 'b0;
        bht_tag_write_out_test[0] = 'b0;

        $display("---------------------------------------------------------------------Resetting---------------------------------------------------------------------");
        #10;

        reset = 0;
        $display("---------------------------------------------------------------------Test 1---------------------------------------------------------------------");
        $display("Input: wr_en[0]=%b, take_branch[0]=%b, ex_pc[0]=%b, if_pc[0]=%b", wr_en[0], take_branch[0], ex_pc[0], if_pc[0]);
        bht_tag_read_out_test[0]  = 'h1;
        bht_tag_write_out_test[0] = 'h1;
        #10;

        take_branch[0] = 0;
        bht_tag_read_out_test[0]  = 'h1;
        bht_tag_write_out_test[0] = 'h1;
        $display("---------------------------------------------------------------------Test 2---------------------------------------------------------------------");
        #10;

        take_branch[0] = 1;
        bht_tag_read_out_test[0]  = 'b10;
        bht_tag_write_out_test[0] = 'b10;
        $display("---------------------------------------------------------------------Test 3---------------------------------------------------------------------");
        #10;

        take_branch[0] = 0;
        bht_tag_read_out_test[0]  = 'b101;
        bht_tag_write_out_test[0] = 'b101;
        $display("---------------------------------------------------------------------Test 4---------------------------------------------------------------------");
        #10;

        take_branch[0] = 0;
        bht_tag_read_out_test[0]  = 'b10;
        bht_tag_write_out_test[0] = 'b10;
        $display("---------------------------------------------------------------------Test 3---------------------------------------------------------------------");
        #10;
        $finish;
    end
endmodule