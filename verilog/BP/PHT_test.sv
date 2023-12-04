`include "verilog/sys_defs.svh"
module t0();
    logic clock, reset;
    logic [2:0] wr_en;
    logic [2:0][`BHTWIDTH-1:0] bht_if_in;    // output the value stored in BHT to PHT
    logic [2:0][`BHTWIDTH-1:0] bht_ex_in;    // output the value stored in BHT to PHT
    logic [2:0] [`XLEN-1:0] ex_pc_in;  // pc from ex stage 
    logic [2:0] take_branch;    // taken or no taken from ex stage  
    logic [2:0] [`XLEN-1:0] if_pc_in;    // pc from if stage    
    logic [2:0] predict_taken;    // predict pc taken or no taken

    PHT DUT (
        .clock(clock), 
        .reset(reset),
        .wr_en_in(wr_en),
        .ex_pc_in(ex_pc_in),  // pc from ex stage 
        .taken_branch_in(take_branch),    // taken or no taken from ex stage  
        .if_pc_in(if_pc_in),    // pc from if stage 
        .bht_tag_read_in(bht_if_in),   
        .bht_tag_write_in(bht_ex_in),

        .predicted_result_out(predict_taken)    // predict pc taken or no taken
        );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        $monitor("clock=%b, reset=%b, wr_en=%b, bht_if_in=%b, bht_ex_in=%b, ex_pc_in=%b, take_branch=%b, if_pc_in=%b, predict_taken=%b", clock, reset, wr_en, bht_if_in, bht_ex_in, ex_pc_in, take_branch, if_pc_in, predict_taken);
        clock = 0;
        reset = 1;
        wr_en = 0;
        bht_if_in[2]=0;
        bht_ex_in[2] = 0;
        ex_pc_in[2] = 0;
        take_branch[2] = 0;
        if_pc_in[2] = 0;
        bht_if_in[1]=0;
        bht_ex_in[1] = 0;
        ex_pc_in[1] = 0;
        take_branch[1] = 0;
        if_pc_in[1] = 0;
        for (int i=0;i<40;i++) begin
            @(negedge clock);
            reset = 0;
            wr_en = 1;
            bht_if_in[0] =  i;
            bht_ex_in[0] = i;
            ex_pc_in[0] = i+1;
            take_branch[0] = 1;
            if_pc_in[0] = i;
        end   
        $finish;
    end

endmodule