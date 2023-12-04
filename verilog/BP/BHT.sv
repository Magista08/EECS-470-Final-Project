`include "verilog/sys_defs.svh"
//`include "same_idx.sv"

module BHT(
    input  clock, reset, 
    input [`N-1:0]             wr_en_in,     // cond_branch from ex stage
    input [`N-1:0]             take_branch_in, // taken or no taken from ex stage  
    input [`N-1:0] [`XLEN-1:0] ex_pc_in,    // pc from ex stage
    input [`N-1:0] [`XLEN-1:0] if_pc_in,    // pc from if stage  

    // Outputs
    output [`N-1:0] [`BHTWIDTH-1:0] bht_tag_read_out,    // output the value stored in BHT to PHT
    output [`N-1:0] [`BHTWIDTH-1:0] bht_tag_write_out    // output the value stored in BHT to PHT
);

    logic [`BHTWIDTH-1:0] bht_table [`BHTLEN-1:0];

    // Pointer
    logic [`N-1:0] [$clog2(`BHTLEN)-1:0] rptr, wptr;

    genvar bht_i;
    generate
        for (bht_i=0; bht_i<`N; bht_i++) begin
            // Output
            assign bht_tag_read_out[bht_i]  = bht_table[rptr[bht_i]];
            assign bht_tag_write_out[bht_i] = bht_table[wptr[bht_i]];
        end
    endgenerate

    always_comb begin
        for (int i=0; i<`N; i=i+1) begin
            rptr[i] = ex_pc_in[i][2 +: $clog2(`BHTLEN)];
            wptr[i] = if_pc_in[i][2 +: $clog2(`BHTLEN)];
        end
    end
    
    // Get Enable
    logic [`N-1:0] [`N-1:0] wr_en;
    DETECT_IDX_BHT det0(
        .en_in  (wr_en_in),
        .idx_in (wptr),
        
        .en_out (wr_en)
    );

    // Change the bht_table
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0; i<`BHTLEN; i=i+1) begin
                bht_table[i] <= {`BHTWIDTH{1'b0}};
            end
        end else begin
            for (int i=0; i<`N; i=i+1) begin
                // $display("take_branch_in[i]: %b", take_branch_in[i]);
                // $display("wr_en_in: %b", wr_en_in);
                // $display("wr_en[%d][2]:%b, wr_en[%d][1]:%b, wr_en[%d][0]", i, wr_en[i][2], i, wr_en[i][1], i, wr_en[i][0]);
                if (!wr_en[i]) begin
                    bht_table[wptr[i]] <= {bht_table[wptr[i]][`BHTWIDTH-2:0], take_branch_in[i]};
                end
            end
        end
    end
endmodule