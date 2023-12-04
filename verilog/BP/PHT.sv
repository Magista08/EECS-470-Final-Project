`include "verilog/sys_defs.svh"

module PHT (
    input clock, reset,
    input [`N-1:0]                  wr_en_in,
    input [`N-1:0]                  taken_branch_in,
    input [`N-1:0] [`XLEN-1:0]      ex_pc_in,
    input [`N-1:0] [`XLEN-1:0]      if_pc_in,
    input [`N-1:0] [`BHTWIDTH-1:0] bht_tag_read_in,
    input [`N-1:0] [`BHTWIDTH-1:0] bht_tag_write_in,
    
    output logic [`N-1:0]                 predicted_result_out
);
    // PHT table
    PHT_STATE pht_table [`PHTLEN-1:0] [`PHTWIDTH-1:0];
    PHT_STATE n_pht_table [`PHTLEN-1:0] [`PHTWIDTH-1:0];

    // Pointer
    logic [`N-1:0] [$clog2(`PHTLEN)-1:0] rptr, wptr;

    genvar pht_i;
    generate
        for (pht_i=0; pht_i<`N; pht_i++) begin
            // Update ptr
            assign rptr[pht_i] = if_pc_in[pht_i][2 +: $clog2(`PHTLEN)];
            assign wptr[pht_i] = ex_pc_in[pht_i][2 +: $clog2(`PHTLEN)];
            assign predicted_result_out[pht_i] = ((pht_table[if_pc_in[pht_i][2 +: $clog2(`PHTLEN)]][bht_tag_read_in[pht_i]]== T_WEAK) || 
                                                  (pht_table[if_pc_in[pht_i][2 +: $clog2(`PHTLEN)]][bht_tag_read_in[pht_i]]== T_STRONG)) ? 1 : 0;
        end
    endgenerate

    // Get Enable
    logic [`N-1:0] [`N-1:0] wr_en;

    DETECT_IDX_PHT det1(
        .en_in(wr_en_in),
        .idx_in(wptr),
        .en_out(wr_en)
    );

    // Change PHT with write info
    always_comb begin
        // Init
        n_pht_table = pht_table;

        // Change the state based on new info
        for (int i=0; i<`N; i=i+1) begin
            if (!wr_en[i]) begin
                case (pht_table[wptr[i]][bht_tag_write_in[i]])
                    T_STRONG: n_pht_table[wptr[i]][bht_tag_write_in[i]] = taken_branch_in[i] ? T_STRONG : T_WEAK;
                    T_WEAK:   n_pht_table[wptr[i]][bht_tag_write_in[i]] = taken_branch_in[i] ? T_STRONG : N_WEAK; // ?
                    N_WEAK:   n_pht_table[wptr[i]][bht_tag_write_in[i]] = taken_branch_in[i] ? T_WEAK   : N_STRONG; // ?
                    N_STRONG: n_pht_table[wptr[i]][bht_tag_write_in[i]] = taken_branch_in[i] ? N_WEAK   : N_STRONG;
                endcase
            end
        end
    end

    // Update PHT
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0; i<`PHTLEN; i=i+1) begin
                for (int j=0; j<`PHTWIDTH; j=j+1) begin
                    pht_table[i][j] <= N_WEAK;
                end
            end
        end else begin
            for (int i=0; i <`N; i++) begin
                if (!wr_en[i]) begin
                    pht_table[wptr[i]][bht_tag_write_in[i]] <= n_pht_table[wptr[i]][bht_tag_write_in[i]];
                end
            end
        end
    end
endmodule