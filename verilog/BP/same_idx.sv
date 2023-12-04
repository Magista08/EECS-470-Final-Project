module DETECT_IDX_BHT(
    input  [`N-1:0]             en_in,
    input  [`N-1:0] [$clog2(`BHTLEN)-1:0] idx_in,
    output [`N-1:0] [`N-1:0]    en_out
);

    genvar idx_i, idx_j, idx_k;
    generate
        for (idx_i=0; idx_i<`N; idx_i++) begin
            for (idx_k=0; idx_k<idx_i; idx_k++) begin
                assign en_out[idx_i][idx_k] = en_in[idx_i] & en_in[idx_k] &&
                                                 idx_in[idx_i] == idx_in[idx_k];
            end

            for (idx_j=idx_i; idx_j<`N; idx_j++) begin
                assign en_out[idx_i][idx_j] = !en_in[idx_i];
            end
        end
    endgenerate
endmodule

module DETECT_IDX_PHT(
    input  [`N-1:0]             en_in,
    input  [`N-1:0] [$clog2(`PHTLEN)-1:0] idx_in,
    output [`N-1:0] [`N-1:0]    en_out
);

    genvar idx_i, idx_j, idx_k;
    generate
        for (idx_i=0; idx_i<`N; idx_i++) begin
            for (idx_k=0; idx_k<idx_i; idx_k++) begin
                assign en_out[idx_i][idx_k] = en_in[idx_i] & en_in[idx_k] &&
                                                 idx_in[idx_i] == idx_in[idx_k];
            end

            for (idx_j=idx_i; idx_j<`N; idx_j++) begin
                assign en_out[idx_i][idx_j] = !en_in[idx_i];
            end
        end
    endgenerate
endmodule