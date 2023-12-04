module LSQ (
    input                                       clock,
    input                                       reset,
    input                                       clear,

    // From Dispatch (write in RS and SQ simultaneously)
    input DP_PACKET [2:0]                       DP_packet, // valid, wr_mem
    // From FU output
    input SQ_LINE [2:0]                         LOAD_STORE_input, // valid, SQ_position, address, mem_size
    input [2:0] [$clog2(`SQ_SIZE)-1:0]          position, // used to assign FU output to SQ line
    // From Retire (let Retire free SQ entries)
    input RT_LSQ_PACKET [2:0]                   RT_packet, // valid, retire_tag
    // From DCache (need to give LOAD value if no match)
    input DCACHE_LSQ_PACKET [1:0]               DC_SQ_packet, // busy, valid, value, address, NPC

    // To RS
    output logic [2:0] [$clog2(`SQ_SIZE)-1:0]   SQ_tail, // I need to give RS each tail so that the positions can get into FU and come back to SQ
    // Tp instruction buffer
    output logic                                SQ_full, // I need to tell instruction buffer I am full
    // To Complete (LOAD instruction need to go into complete buffer, only 1 for once?!)
    output EX_PACKET                            SQ_COMP_packet,
    // To DCache
    output LSQ_DCACHE_PACKET                    SQ_DC_packet,

    // output SQ_LINE [`SQ_SIZE-1:0]                      SQ, next_SQ,
    // output EX_PACKET                                   next_SQ_COMP_packet,
    // output LSQ_DCACHE_PACKET                           next_SQ_DC_packet,

    // output logic                                       to_DC_full, // Dcache can only have 1 input

    // output logic [$clog2(`SQ_SIZE):0]                  head, next_head, tail, next_tail,
    // output logic [$clog2(`SQ_SIZE)-1:0]                head_idx, next_head_idx, tail_idx, next_tail_idx,
    // output logic                                       head_flag, next_head_flag, tail_flag, next_tail_flag // to determin whether it has circled a cycle
);
    // Table
    logic [`SQ_SIZE-1:0]                        sq_tbl, n_sq_tbl;
    logic [$clog2(`SQ_SIZE):0]                  head, next_head, tail, next_tail;
    logic [$clog2(`SQ_SIZE)-1:0]                head_idx, next_head_idx, tail_idx, next_tail_idx;

    logic [$clog2(`SQ_SIZE)-1:0]                space_left;

    // Stall
    always_comb begin
        space_left = head[$(clog2(`SQ_SIZE))-1] - tail[$(clog2(`SQ_SIZE))-1];

        if (space_left == 0) begin
            if(head[$clog2(`SQ_SIZE)] == tail[$clog2(`SQ_SIZE)]) begin
                SQ_full = 1'b1;
            end else begin
                SQ_full = 1'b0;
            end
        end
        else begin
            if (space_left > 3) begin
                SQ_full = 1'b0;
            end else begin
                SQ_full = 1'b1;
            end
        end
    end

    // Update and write
    always_ff @(posedge clock) begin
        if (reset || clear) begin
            head <= 0;
            tail <= 0;
            sq_tbl   <= 0;
        end else begin
            head <= next_head;
            tail <= next_tail;
            sq_tbl   <= n_sq_tbl;
        end
    end
endmodule