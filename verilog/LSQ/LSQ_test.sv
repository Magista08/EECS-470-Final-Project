`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module testbench;

    //---------------------- input --------------------//
    logic clock, reset, clear;
    // from Disaptch
    DP_PACKET [2:0] DP_packet_in;
    // from FU
    SQ_LINE [2:0] LOAD_STORE_input;
    logic [2:0] [$clog2(`SQ_SIZE)-1:0] position_in;
    // from Retire
    RT_LSQ_PACKET [2:0] RT_packet_in;    
    // from Dcache
    DCACHE_LSQ_PACKET [1:0] DC_SQ_packet_in;
    
    //---------------------- output ------------------//

    // to RS
    logic [2:0] [$clog2(`SQ_SIZE)-1:0] SQ_tail_out;
    // to Dispatch
    logic SQ_full_out;
    // to Complete
    EX_PACKET SQ_COMP_packet_out;
    // to DCache
    LSQ_DCACHE_PACKET SQ_DC_packet_out;

    //---------------------- debug ---------------------//
    SQ_LINE [`SQ_SIZE-1:0]               SQ, next_SQ;
    EX_PACKET                            next_SQ_COMP_packet;
    LSQ_DCACHE_PACKET                    next_SQ_DC_packet;

    logic                                to_DC_full;    

    logic [$clog2(`SQ_SIZE):0]           head, next_head, tail, next_tail;
    logic [$clog2(`SQ_SIZE)-1:0]         head_idx, next_head_idx, tail_idx, next_tail_idx;
    logic                                head_flag, next_head_flag, tail_flag, next_tail_flag; 


	// Instance declaration
    LSQ DUT(
        .clock(clock),
        .reset(reset),
        .clear(clear),
        .DP_packet(DP_packet_in),
        .LOAD_STORE_input(LOAD_STORE_input),
        .position(position_in),
        .RT_packet(RT_packet_in),
        .DC_SQ_packet(DC_SQ_packet_in),

        .SQ_tail(SQ_tail_out),
        .SQ_full(SQ_full_out),
        .SQ_COMP_packet(SQ_COMP_packet_out),
        .SQ_DC_packet(SQ_DC_packet_out),

        // Debug
        .SQ(SQ),
        .next_SQ(next_SQ),
        .next_SQ_COMP_packet(next_SQ_COMP_packet),
        .next_SQ_DC_packet(next_SQ_DC_packet),
        .to_DC_full(to_DC_full),

        .head(head),
        .next_head(next_head),
        .tail(tail),
        .next_tail(next_tail),
        .head_idx(head_idx),
        .next_head_idx(next_head_idx),
        .tail_idx(tail_idx),
        .next_tail_idx(next_tail_idx),
        .head_flag(head_flag),
        .next_head_flag(next_head_flag),
        .tail_flag(tail_flag),
        .next_tail_flag(next_tail_flag)

    );


    always begin
        #20;
        clock = ~clock;
    end

    initial begin

        // $monitor("time:%4.0f clock:%b SQ_DC_packet_out", 
        //         $time, clock, );

        // $monitor("time:%4.0f clock:%b SQ_full_out:%b next_head_idx:%b next_tail_idx:%b next_tail_idx+2:%b next_head_flag:%b next_tail_flag:%b \n\
        //         SQ_tail_out[0]:%b SQ_tail_out[1]:%b SQ_tail_out[2]:%b \n", 
        //         $time, clock, SQ_full_out, next_head_idx, next_tail_idx, next_tail_idx+3'b010, next_head_flag, next_tail_flag, SQ_tail_out[0], SQ_tail_out[1], SQ_tail_out[2]);
                 
        $monitor("time:%4.0f clock:%b SQ_full_out:%b next_head_idx:%b next_tail_idx:%b \n\
                SQ_tail_out[0]:%b SQ_tail_out[1]:%b SQ_tail_out[2]:%b \n\
                next_SQ[0].addr_cannot_to_DCache:%b next_SQ[0].retire_valid:%b LOAD_STORE_input[0].valid:%b LOAD_STORE_input[0].retire_valid:%b \n", 
                $time, clock, SQ_full_out, next_head_idx, next_tail_idx, SQ_tail_out[0], SQ_tail_out[1], SQ_tail_out[2],
                next_SQ[0].addr_cannot_to_DCache, next_SQ[0].retire_valid, LOAD_STORE_input[0].valid, LOAD_STORE_input[0].retire_valid);


        clock = 0;
        reset = 1;
        clear = 0;
        position_in[0] = 0;
        position_in[1] = 0;
        position_in[2] = 0;
        DP_packet_in[0].wr_mem = 0;
        DP_packet_in[0].rd_mem = 0;
        DP_packet_in[1].wr_mem = 0;
        DP_packet_in[1].rd_mem = 0;
        DP_packet_in[2].wr_mem = 0;
        DP_packet_in[2].rd_mem = 0;

        RT_packet_in[0] = {
            1'b0,                    // valid
            {5'b00000}               // retire_tag
        };

        RT_packet_in[1] = {
            1'b0,                    // valid
            {5'b00000}               // retire_tag
        };

        RT_packet_in[2] = {
            1'b0,                    // valid
            {5'b00000}               // retire_tag
        };        


        DC_SQ_packet_in[0] = {
            1'b0,                    // busy
            1'b0,                    // valid
            {`XLEN{1'b0}},           // value
            {`XLEN{1'b0}},           // address
            {`XLEN{1'b0}},           // NPC
            1'b0                     // st_or_ld
        };

        DC_SQ_packet_in[1] = {
            1'b0,                    // busy
            1'b0,                    // valid
            {`XLEN{1'b0}},           // value
            {`XLEN{1'b0}},           // address
            {`XLEN{1'b0}},           // NPC
            1'b0                     // st_or_ld
        };


        LOAD_STORE_input[0] = {
            1'b0,                    // valid            
            1'b0,                    // load_1_store_0
            {3'b000},                // mem_size
            {(`XLEN-2){1'b0}},       // word_addr
            2'b00,                   // res_addr
            {`XLEN{1'b0}},           // value
            {5'b00000},              // T
            1'b0,                    // retire_valid
            1'b0,                    // pre_store_done
            1'b0,                    // sent_to_CompBuff
            1'b0,                    // addr_cannot_to_DCache
            {`XLEN{1'b0}},           // NPC
            1'b0                     // halt
        };

        LOAD_STORE_input[1] = {
            1'b0,                    // valid            
            1'b0,                    // load_1_store_0
            {3'b000},                // mem_size
            {(`XLEN-2){1'b0}},       // word_addr
            2'b00,                   // res_addr
            {`XLEN{1'b0}},           // value
            {5'b00000},              // T
            1'b0,                    // retire_valid
            1'b0,                    // pre_store_done
            1'b0,                    // sent_to_CompBuff
            1'b0,                    // addr_cannot_to_DCache
            {`XLEN{1'b0}},           // NPC
            1'b0                     // halt
        };

        LOAD_STORE_input[2] = {
            1'b0,                    // valid            
            1'b0,                    // load_1_store_0
            {3'b000},                // mem_size
            {(`XLEN-2){1'b0}},       // word_addr
            2'b00,                   // res_addr
            {`XLEN{1'b0}},           // value
            {5'b00000},              // T
            1'b0,                    // retire_valid
            1'b0,                    // pre_store_done
            1'b0,                    // sent_to_CompBuff
            1'b0,                    // addr_cannot_to_DCache
            {`XLEN{1'b0}},           // NPC
            1'b0                     // halt
        };


        #20;//20

        #20;//40
        #20;//60
        $display("\nBeginning for test 1\n");
        reset = 0;
    //--------------------------------------------------------------------------
    // Test 1: 1 store, 1 load, 1 store
        DP_packet_in[0].wr_mem = 1;
        DP_packet_in[0].rd_mem = 0;
        DP_packet_in[1].wr_mem = 0;
        DP_packet_in[1].rd_mem = 1;
        DP_packet_in[2].wr_mem = 1;
        DP_packet_in[2].rd_mem = 0;

        #20;//80
        #20;//100

        DP_packet_in[0].wr_mem = 0;
        DP_packet_in[0].rd_mem = 0;
        DP_packet_in[1].wr_mem = 0;
        DP_packet_in[1].rd_mem = 0;
        DP_packet_in[2].wr_mem = 0;
        DP_packet_in[2].rd_mem = 0;

        #20;//120
        #20;//140
        position_in[0] = 0;
        position_in[1] = 1;
        position_in[2] = 2;

        // LOAD_STORE_input[0].valid = 1'b1;
        LOAD_STORE_input[0] = {
            1'b1,                    // valid            
            1'b0,                    // load_1_store_0
            {3'b010},                // mem_size
            {(`XLEN-2){1'b0}},       // word_addr
            2'b00,                   // res_addr
            {`XLEN{1'b0}},           // value
            {5'b00001},              // T
            1'b1,                    // retire_valid
            1'b0,                    // pre_store_done
            1'b0,                    // sent_to_CompBuff
            1'b0,                    // addr_cannot_to_DCache
            {`XLEN{1'b0}},           // NPC
            1'b0                     // halt
        };

        #20;//160
        #20;//180

        RT_packet_in[0] = {
            1'b1,                    // valid
            {5'b00001}               // retire_tag
        };

        #20;//200
        #20;//220


    //     DC_SQ_packet_in[0] = {
    //         1'b0,                    // busy
    //         1'b0,                    // valid
    //         {`XLEN{1'b0}},           // value
    //         {`XLEN{1'b0}},           // address
    //         {`XLEN{1'b0}},           // NPC
    //         1'b0                     // st_or_ld
    //     };

        // LOAD_STORE_input[1] = {
        //     1'b1,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {5'b00000},              // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[2] = {
        //     1'b1,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {5'b00000},              // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        #20;//160
        #20;//180
        #20;//200

        // DP_packet_in[0].wr_mem = 0;
        // DP_packet_in[0].rd_mem = 1;
        // DP_packet_in[1].wr_mem = 0;
        // DP_packet_in[1].rd_mem = 1;
        // DP_packet_in[2].wr_mem = 0;
        // DP_packet_in[2].rd_mem = 1;

        // LOAD_STORE_input[0] = {
        //     1'b1,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[1] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[2] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // #20;
        // #20;
        // #20;

        // DP_packet_in[0].wr_mem = 1;
        // DP_packet_in[0].rd_mem = 0;
        // DP_packet_in[1].wr_mem = 0;
        // DP_packet_in[1].rd_mem = 1;
        // DP_packet_in[2].wr_mem = 1;
        // DP_packet_in[2].rd_mem = 0;

        // LOAD_STORE_input[0] = {
        //     1'b1,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[1] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[2] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // #20;
        // #20;
        // #20;

        // DP_packet_in[0].wr_mem = 1;
        // DP_packet_in[0].rd_mem = 0;
        // DP_packet_in[1].wr_mem = 0;
        // DP_packet_in[1].rd_mem = 1;
        // DP_packet_in[2].wr_mem = 1;
        // DP_packet_in[2].rd_mem = 0;

        // LOAD_STORE_input[0] = {
        //     1'b1,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[1] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // LOAD_STORE_input[2] = {
        //     1'b0,                    // valid            
        //     1'b0,                    // load_1_store_0
        //     {3'b000},                // mem_size
        //     {(`XLEN-2){1'b0}},       // word_addr
        //     2'b00,                   // res_addr
        //     {`XLEN{1'b0}},           // value
        //     {6'b000000},             // T
        //     1'b0,                    // retire_valid
        //     1'b0,                    // pre_store_done
        //     1'b0,                    // sent_to_CompBuff
        //     1'b0,                    // addr_cannot_to_DCache
        //     {`XLEN{1'b0}},           // NPC
        //     1'b0                     // halt
        // };

        // #20;
        // #20;
        // #20;


        $display("@@@Passed");
        $finish;

    end

endmodule
