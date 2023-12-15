module DETECT_IDX_BHT(
    input  [`N-1:0] 		          en_in,
    input  [`N-1:0] [$clog2(`BHTLEN)-1:0] idx_in,
    output [`N-1:0] [`N-1:0]		  en_out
);
    assign en_out[0][0] = !en_in[0];
    assign en_out[0][1] = !en_in[0];
    assign en_out[0][2] = !en_in[0];

    assign en_out[1][0] = en_in[0] && en_in[1] && idx_in[0] == idx_in[1];
    assign en_out[1][1] = !en_in[1];
    assign en_out[1][2] = !en_in[1];
    
    assign en_out[2][0] = en_in[0] && en_in[2] && idx_in[0] == idx_in[2];
    assign en_out[2][1] = en_in[1] && en_in[2] && idx_in[1] == idx_in[2];
    assign en_out[2][2] = !en_in[2];
endmodule


module DETECT_IDX_PHT(
    input  [`N-1:0] 		          en_in,
    input  [`N-1:0] [$clog2(`PHTLEN)-1:0] idx_in,
    output [`N-1:0] [`N-1:0]		  en_out
);
    assign en_out[0][0] = !en_in[0];
    assign en_out[0][1] = !en_in[0];
    assign en_out[0][2] = !en_in[0];

    assign en_out[1][0] = en_in[0] && en_in[1] && idx_in[0] == idx_in[1];
    assign en_out[1][1] = !en_in[1];
    assign en_out[1][2] = !en_in[1];
    
    assign en_out[2][0] = en_in[0] && en_in[2] && idx_in[0] == idx_in[2];
    assign en_out[2][1] = en_in[1] && en_in[2] && idx_in[1] == idx_in[2];
    assign en_out[2][2] = !en_in[2];
endmodule
