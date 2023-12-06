`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"
// `include "psel_gen.sv"

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
    // From Complete Buffer
    input                                       LSQ_buffer_busy, // if busy, then SQ cannot send LOAD to Complete Buffer (there is only one LOAD entry in Complete Buffer)

    // To RS
    output logic [2:0] [$clog2(`SQ_SIZE)-1:0]   SQ_tail, // I need to give RS each tail so that the positions can get into FU and come back to SQ
    // Tp instruction buffer
    output logic                                SQ_full, // I need to tell instruction buffer I am full
    // To Complete (LOAD instruction need to go into complete buffer, only 1 for once?!)
    output EX_PACKET                            SQ_COMP_packet,
    // To DCache
    output LSQ_DCACHE_PACKET                    SQ_DC_packet

    // output SQ_LINE [`SQ_SIZE-1:0]                      SQ, next_SQ,
    // output EX_PACKET                                   next_SQ_COMP_packet,
    // output LSQ_DCACHE_PACKET                           next_SQ_DC_packet,

    // output logic                                       to_DC_full, // Dcache can only have 1 input

    // output logic [$clog2(`SQ_SIZE):0]                  head, next_head, tail, next_tail,
    // output logic [$clog2(`SQ_SIZE)-1:0]                head_idx, next_head_idx, tail_idx, next_tail_idx,
    // output logic                                       head_flag, next_head_flag, tail_flag, next_tail_flag // to determin whether it has circled a cycle
);

    SQ_LINE [`SQ_SIZE-1:0]                      SQ, next_SQ;
    EX_PACKET                                   next_SQ_COMP_packet;
    LSQ_DCACHE_PACKET                           next_SQ_DC_packet;

    logic                                       to_DC_full; // Dcache can only have 1 input
    logic                                       next_SQ_full;

    logic [$clog2(`SQ_SIZE):0]                  head, next_head, tail, next_tail;
    logic [$clog2(`SQ_SIZE)-1:0]                head_idx, next_head_idx, tail_idx, next_tail_idx;
    logic                                       head_flag, next_head_flag, tail_flag, next_tail_flag; // to determin whether it has circled a cycle

    // table for psel
    PSEL_TABLE                                  psel_table;
    logic [`SQ_SIZE-1:0]                        req1, gnt1, req2, gnt2;
    logic                                       store_found_in_lower, load_sent_in_lower;
    logic [`SQ_SIZE-1:0]                        pre_req1, pre_req2;

    logic [$clog2(`SQ_SIZE)-1:0]                gnt2_log_to_psel1_idx;

    logic [$clog2(`SQ_SIZE)-1:0]                gnt1_log, gnt2_log;
    // always_comb begin
    //     gnt1_log = 0;
    //     gnt2_log = 0;
    //     if (gnt1!=0) begin
    //         // gnt1_log = $clog2(gnt1);
    //         for (int i=7; i>=0; i--) begin
    //             if (gnt1[i]==1) begin
    //                 gnt1_log = i;
    //                 break;
    //             end
    //         end
    //     end
    //     if (gnt2!=0) begin
    //         // gnt2_log = $clog2(gnt2);
    //         for (int i=7; i>=0; i--) begin
    //             if (gnt2[i]==1) begin
    //                 gnt2_log = i;
    //                 break;
    //             end
    //         end
    //     end
    // end


    always_comb begin
        next_SQ = SQ;
        next_head = head;
        next_tail = tail;
        next_SQ_COMP_packet = 0;
        next_SQ_DC_packet = 0;
        to_DC_full = 0;
        psel_table = 0;
	next_SQ_full = 0;

        if (clear) begin
            next_SQ = 0;
            next_head = 0;
            next_tail = 0;
            next_SQ_COMP_packet = 0;
            next_SQ_DC_packet = 0;
            to_DC_full = 0;
            psel_table = 0;
	    next_SQ_full = 0;

        end else begin // Order of the following steps may change

            next_tail = tail + (DP_packet[0].wr_mem || DP_packet[0].rd_mem) + (DP_packet[1].wr_mem || DP_packet[1].rd_mem) + (DP_packet[2].wr_mem || DP_packet[2].rd_mem);
            // $display("next_tail: %b", next_tail);
            // $display("tail: %b", tail);
            // $display("DP_packet[0].illegal: %b, DP_packet[0].wr_mem: %b, DP_packet[0].rd_mem: %b,", DP_packet[0].illegal, DP_packet[0].wr_mem, DP_packet[0].rd_mem);
            // $display("DP_packet[1].illegal: %b, DP_packet[1].wr_mem: %b, DP_packet[1].rd_mem: %b,", DP_packet[1].illegal, DP_packet[1].wr_mem, DP_packet[1].rd_mem);
            // $display("DP_packet[2].illegal: %b, DP_packet[2].wr_mem: %b, DP_packet[2].rd_mem: %b,", DP_packet[2].illegal, DP_packet[2].wr_mem, DP_packet[2].rd_mem);

            head_idx       = head[$clog2(`SQ_SIZE)-1:0];
            next_head_idx  = next_head[$clog2(`SQ_SIZE)-1:0];
            tail_idx       = tail[$clog2(`SQ_SIZE)-1:0];
            next_tail_idx  = next_tail[$clog2(`SQ_SIZE)-1:0];

            head_flag      = head[$clog2(`SQ_SIZE)];
            next_head_flag = next_head[$clog2(`SQ_SIZE)];
            tail_flag      = tail[$clog2(`SQ_SIZE)];
            next_tail_flag = next_tail[$clog2(`SQ_SIZE)];

            // Give DP full information
            next_SQ_full = (next_tail_idx == next_head_idx && next_tail_flag != next_head_flag) || ((next_tail_idx+3'b001) == next_head_idx) || ((next_tail_idx+3'b010) == next_head_idx) || ((next_tail_idx+3'b011) == next_head_idx) || ((next_tail_idx+3'b100) == next_head_idx) || ((next_tail_idx+3'b101) == next_head_idx) || ((next_tail_idx+3'b110) == next_head_idx);
            // SQ_full = (next_tail_idx >= next_head_idx && next_tail_flag != next_head_flag) || ((next_tail_idx+3'b001) == next_head_idx) || ((next_tail_idx+3'b010) == next_head_idx);

            // Give RS tail information
            SQ_tail[0] = tail[$clog2(`SQ_SIZE)-1:0];
            SQ_tail[1] = tail[$clog2(`SQ_SIZE)-1:0] + (DP_packet[0].wr_mem || DP_packet[0].rd_mem);
            SQ_tail[2] = tail[$clog2(`SQ_SIZE)-1:0] + (DP_packet[0].wr_mem || DP_packet[0].rd_mem) + (DP_packet[1].wr_mem || DP_packet[1].rd_mem);


            // [1.] Assign entries from DP_packet (I need to give load or store information for [5] even if they are not valid now)
            for (int i=0; i<3; i=i+1) begin
                if (DP_packet[i].wr_mem) begin
                    next_SQ[SQ_tail[i]].load_1_store_0 = 0;
                end
                if (DP_packet[i].rd_mem) begin
                    next_SQ[SQ_tail[i]].load_1_store_0 = 1;
                end
            end


            // [2.] Fill in addresses from FU results
            for (int i=0; i<3; i=i+1) begin
                if (LOAD_STORE_input[i].valid==1) begin
                    // todo: give information according to the position
                    next_SQ[position[i]] = LOAD_STORE_input[i];
                    // $display("position[%0d]: %b", i, position[i]);
                    // $display("LOAD_STORE_input[%0d].tag: %b", i, LOAD_STORE_input[i].T);
                    // $display("LOAD_STORE_input[%0d].word_addr: %b", i, LOAD_STORE_input[i].word_addr);
                    // $display("LOAD_STORE_input[%0d].res_addr: %b", i, LOAD_STORE_input[i].res_addr);
                    // $display("LOAD_STORE_input[%0d].value: %b", i, LOAD_STORE_input[i].value);
                    // $display("LOAD_STORE_input[%0d].load_1_store_0: %b", i, LOAD_STORE_input[i].load_1_store_0);
                    // $display("LOAD_STORE_input[%0d].valid: %b", i, LOAD_STORE_input[i].valid);
                end    
            end


            // [3.] Assign where the addr_cannot_to_DCache=1, which means the DCache can only deal with the same address, when the latest store with same address is completed
            for (int i=0; i<`SQ_SIZE; i=i+1) begin
                next_SQ[i].addr_cannot_to_DCache = 0;
                for (int j=0; j<`SQ_SIZE; j=j+1) begin
                    if (j!=i) begin
                        psel_table.psel_1[j] = (next_SQ[j].valid==1) && (next_SQ[i].valid==1) && (next_SQ[j].word_addr[31:3]==next_SQ[i].word_addr[31:3]) && (next_SQ[j].load_1_store_0==0);
                    end
                end

                if(next_head_flag==next_tail_flag) begin // h and t in the same circle
                    // // use psel_table.psel_1
                    // for (int j=0; j<next_head_idx; j=j+1) begin // because not valid
                    //     psel_table.psel_1[j] = 0;
                    // end
                    for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                        psel_table.psel_1[j] = 0;
                    end
                    // req = psel_table.psel_1;
                    // if (gnt!=0) begin // may be wrong
                    //     next_SQ[i].addr_cannot_to_DCache = 1;
                    // end
                    if (psel_table.psel_1!=0) begin // may be wrong
                        next_SQ[i].addr_cannot_to_DCache = 1;     // for WAW and RAW hazard detection
                    end

                end else begin // h and t in different circles
                    // use psel_table.psel_2
                    if (next_tail_idx!=0) begin
                        // psel_table.psel_2 = {psel_table.psel_1[(next_tail_idx-1):0], psel_table.psel_1[(`SQ_SIZE-1):next_tail_idx]}; // concatenate
                        psel_table.psel_2 = (psel_table.psel_1 << (`SQ_SIZE-next_tail_idx)) | (psel_table.psel_1 >> (next_tail_idx));

                        if (i<next_tail_idx) begin // upper case
                            for (int j=`SQ_SIZE-1; j>i+`SQ_SIZE-next_tail_idx; j=j-1) begin // new i
                                psel_table.psel_2[j] = 0;
                            end
                        end else if (i>=next_head_idx) begin // lower case
                            for (int j=`SQ_SIZE-1; j>i-next_tail_idx; j=j-1) begin // new i
                                psel_table.psel_2[j] = 0;
                            end  
                        end

                    end else begin // next_tail_idx==0
                        psel_table.psel_2 = psel_table.psel_1;

                        for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                            psel_table.psel_2[j] = 0;
                        end
                    end

                    // req = psel_table.psel_2;
                    // if (gnt!=0) begin // may be wrong
                    //     next_SQ[i].addr_cannot_to_DCache = 1;
                    // end      
                    if (psel_table.psel_2!=0) begin // may be wrong
                        next_SQ[i].addr_cannot_to_DCache = 1;
                    end              
                end
                // $display("[3.] next_SQ[%0d].addr_cannot_to_DCache: %b", i, next_SQ[i].addr_cannot_to_DCache);
            end


            // [4.] Assign where the addr_cannot_to_DCache=0 according to DCache packet (only assign 1 entry)            
            if (next_head_flag==next_tail_flag) begin // h and t in the same circle
                for (int i=0; i<`SQ_SIZE; i=i+1) begin
                    if (i>=next_head_idx && i<next_tail_idx) begin
                        if ((next_SQ[i].valid==1) && (DC_SQ_packet[0].st_or_ld==0 && DC_SQ_packet[0].valid && DC_SQ_packet[0].address[31:3]==next_SQ[i].word_addr[31:3]) || (DC_SQ_packet[1].st_or_ld==0 && DC_SQ_packet[1].valid && DC_SQ_packet[1].address[31:3]==next_SQ[i].word_addr[31:3])) begin
                            next_SQ[i].addr_cannot_to_DCache = 0;
                            if (next_SQ[i].load_1_store_0==0) begin // set 0 until next store
                                break;
                            end
                        end
                    end
                end
            end else begin // h and t in differnet circles
                for (int i=0; i<`SQ_SIZE; i=i+1) begin
                    store_found_in_lower = 0;
                    if (i>=next_head_idx && i<`SQ_SIZE) begin
                        if ((next_SQ[i].valid==1) && (DC_SQ_packet[0].st_or_ld==0 && DC_SQ_packet[0].valid && DC_SQ_packet[0].address[31:3]==next_SQ[i].word_addr[31:3]) || (DC_SQ_packet[1].st_or_ld==0 && DC_SQ_packet[1].valid && DC_SQ_packet[1].address[31:3]==next_SQ[i].word_addr[31:3])) begin
                            next_SQ[i].addr_cannot_to_DCache = 0;
                            if (next_SQ[i].load_1_store_0==0) begin // set 0 until next store
                                store_found_in_lower = 1;
                                break;
                            end
                        end
                    end
                end
                if (store_found_in_lower==0) begin
                    for (int i=0; i<next_tail_idx; i=i+1) begin
                        if ((next_SQ[i].valid==1) && (DC_SQ_packet[0].st_or_ld==0 && DC_SQ_packet[0].valid && DC_SQ_packet[0].address[31:3]==next_SQ[i].word_addr[31:3]) || (DC_SQ_packet[1].st_or_ld==0 && DC_SQ_packet[1].valid && DC_SQ_packet[1].address[31:3]==next_SQ[i].word_addr[31:3])) begin
                            next_SQ[i].addr_cannot_to_DCache = 0;
                            if (next_SQ[i].load_1_store_0==0) begin // set 0 until next store
                                break;
                            end
                        end
                    end
                end
            end



            // [5.] Store to load forwarding
            // determine pre_store_done
            psel_table = 0;
            for (int i=0; i<`SQ_SIZE; i=i+1) begin
                if ((next_SQ[i].valid==1) && (next_SQ[i].load_1_store_0==1) && (next_SQ[i].retire_valid==0)) begin // For every load
                    next_SQ[i].pre_store_done = 1;

                    for (int j=0; j<`SQ_SIZE; j=j+1) begin
                        if (j!=i) begin
                            psel_table.psel_1[j] = (next_SQ[j].load_1_store_0==0) && (next_SQ[j].valid==0); // if there is some store with no address, then set psel 1
                        end
                    end

                    if(next_head_flag==next_tail_flag) begin // h and t in the same circle
                        for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                            psel_table.psel_1[j] = 0;
                        end
                        for (int j=0; j<next_head_idx; j=j+1) begin
                            psel_table.psel_1[j] = 0;
                        end
                        // req = psel_table.psel_1;
                        // if (gnt!=0) begin // may be wrong
                        //     next_SQ[i].pre_store_done = 0;
                        // end
                        if (psel_table.psel_1!={`SQ_SIZE{1'b0}}) begin
                            next_SQ[i].pre_store_done = 0;
                        end

                    end else begin // h and t in different circles
                        // use psel_table.psel_2
                        if (next_tail_idx!=0) begin
                            // psel_table.psel_2 = {psel_table.psel_1[(next_tail_idx-1):0], psel_table.psel_1[(`SQ_SIZE-1):next_tail_idx]}; // concatenate
                            psel_table.psel_2 = (psel_table.psel_1 << (`SQ_SIZE-next_tail_idx)) | (psel_table.psel_1 >> (next_tail_idx));

                            if (i<next_tail_idx) begin // upper case
                                for (int j=`SQ_SIZE-1; j>i+`SQ_SIZE-next_tail_idx; j=j-1) begin // new i
                                    psel_table.psel_2[j] = 0;
                                end
                                for (int j=0; j<$unsigned(next_head_idx-next_tail_idx); j=j+1) begin // new head
                                    psel_table.psel_2[j] = 0;
                                end
                            end else if (i>=next_head_idx) begin // lower case
                                for (int j=`SQ_SIZE-1; j>i-next_tail_idx; j=j-1) begin // new i
                                    psel_table.psel_2[j] = 0;
                                end
                                for (int j=0; j<$unsigned(next_head_idx-next_tail_idx); j=j+1) begin // new head
                                    psel_table.psel_2[j] = 0;
                                end
                            end
    
                        end else begin // next_tail_idx==0
                            psel_table.psel_2 = psel_table.psel_1;
    
                            for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                                psel_table.psel_2[j] = 0;
                            end
                            for (int j=0; j<next_head_idx; j=j+1) begin
                                psel_table.psel_2[j] = 0;
                            end
                        end
    
                        // req = psel_table.psel_2;
                        // if (gnt!=0) begin // may be wrong
                        //     next_SQ[i].pre_store_done = 0;
                        // end
                        if (psel_table.psel_2!={`SQ_SIZE{1'b0}}) begin
                            next_SQ[i].pre_store_done = 0;
                        end               
                    end


                    // data forwarding from queue
                    if (next_SQ[i].pre_store_done==1) begin
                        psel_table = 0;

                        for (int j=0; j<`SQ_SIZE; j=j+1) begin
                            if (j!=i) begin
                                psel_table.psel_1[j] = (next_SQ[j].load_1_store_0==0) && (next_SQ[j].valid==1) && (next_SQ[j].mem_size[1:0]==next_SQ[i].mem_size[1:0]) && (next_SQ[j].word_addr==next_SQ[i].word_addr) && (next_SQ[j].res_addr==next_SQ[i].res_addr);
                            end
                        end
                        if(next_head_flag==next_tail_flag) begin // h and t in the same circle
                            for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                                psel_table.psel_1[j] = 0;
                            end
                            for (int j=0; j<next_head_idx; j=j+1) begin
                                psel_table.psel_1[j] = 0;
                            end
                            req1 = psel_table.psel_1;

                            gnt1[`SQ_SIZE-1] = req1[`SQ_SIZE-1];
                            pre_req1[`SQ_SIZE-1] = req1[`SQ_SIZE-1];
                            for(int i=`SQ_SIZE-2; i>=0; i--)begin
                                gnt1[i] = req1[i] & ~pre_req1[i+1];
                                pre_req1[i] = req1[i] | pre_req1[i+1];
                            end

                            gnt1_log = 0;
                            if (gnt1!=0) begin
                                // gnt1_log = $clog2(gnt1);
                                for (int i=`SQ_SIZE-1; i>=0; i--) begin
                                    if (gnt1[i]==1) begin
                                        gnt1_log = i;
                                        break;
                                    end
                                end
                            end
                            // gnt1[0] = req1[0];
                            // pre_req1[0] = req1[0];
                            // for (int i=1; i<8; i++) begin
                            //     gnt1[i] = req1[i] & ~pre_req1[i-1];
                            //     pre_req1[i] = req1[i] | pre_req1[i-1];
                            // end

                            // if(gnt1 != 0) begin
                            //     next_SQ[i].value = next_SQ[gnt1_log].value; // forwarding here
                            //     $display("[5.345] gnt1: %0d", gnt1);
                            //     $display("[5.345] gnt1_log: %0d", gnt1_log); 
                            //     $display("[5.345] next_SQ[%0d].value: %b", gnt1_log, next_SQ[gnt1_log].value);                           
                            // end

                            if(gnt1 != 0) begin    
                            //if(gnt1_log != 0) begin
                                next_SQ[i].value = next_SQ[gnt1_log].value; // forwarding here
                                $display("h and t in the same circle, forwarding done!");
                                $display("next_SQ[%0d].value: %b  next_SQ[%0d].value: %b", i, next_SQ[i].value, gnt1_log, next_SQ[gnt1_log].value);
                                next_SQ[i].retire_valid = 1;
                            end else begin
                                next_SQ[i].retire_valid = 0;
                            end

                        end else begin // h and t in different circles
                            // use psel_table.psel_2
                            if (next_tail_idx!=0) begin
                                // psel_table.psel_2 = {psel_table.psel_1[(next_tail_idx-1):0], psel_table.psel_1[(`SQ_SIZE-1):next_tail_idx]}; // concatenate
                                psel_table.psel_2 = (psel_table.psel_1 << (`SQ_SIZE-next_tail_idx)) | (psel_table.psel_1 >> (next_tail_idx));

                                if (i<next_tail_idx) begin // upper case
                                    for (int j=`SQ_SIZE-1; j>i+`SQ_SIZE-next_tail_idx; j=j-1) begin // new i
                                        psel_table.psel_2[j] = 0;
                                    end
                                    for (int j=0; j<$unsigned(next_head_idx-next_tail_idx); j=j+1) begin // new head
                                        psel_table.psel_2[j] = 0;
                                    end
                                end else if (i>=next_head_idx) begin // lower case
                                    for (int j=`SQ_SIZE-1; j>i-next_tail_idx; j=j-1) begin // new i
                                        psel_table.psel_2[j] = 0;
                                    end
                                    for (int j=0; j<$unsigned(next_head_idx-next_tail_idx); j=j+1) begin // new head
                                        psel_table.psel_2[j] = 0;
                                    end
                                end

                            end else begin // next_tail_idx==0
                                psel_table.psel_2 = psel_table.psel_1;

                                for (int j=`SQ_SIZE-1; j>i; j=j-1) begin
                                    psel_table.psel_2[j] = 0;
                                end
                                for (int j=0; j<next_head_idx; j=j+1) begin
                                    psel_table.psel_2[j] = 0;
                                end
                            end

                            req2 = psel_table.psel_2;

                            gnt2[`SQ_SIZE-1] = req2[`SQ_SIZE-1];
                            pre_req2[`SQ_SIZE-1] = req2[`SQ_SIZE-1];
                            for(int i=`SQ_SIZE-2; i>=0; i--)begin
                                gnt2[i] = req2[i] & ~pre_req2[i+1];
                                pre_req2[i] = req2[i] | pre_req2[i+1];
                            end

                            gnt2_log = 0;
                            if (gnt2!=0) begin
                                // gnt1_log = $clog2(gnt1);
                                for (int i=`SQ_SIZE-1; i>=0; i--) begin
                                    if (gnt2[i]==1) begin
                                        gnt2_log = i;
                                        break;
                                    end
                                end
                            end

                            // gnt2[0] = req2[0];
                            // pre_req2[0] = req2[0];
                            // for (int i=1; i<8; i++) begin
                            //     gnt2[i] = req2[i] & ~pre_req2[i-1];
                            //     pre_req2[i] = req2[i] | pre_req2[i-1];
                            // end


                            // if(gnt2 != 0) begin
                            //     next_SQ[i].value = next_SQ[gnt2_log].value; // forwarding here
                            // end


                            if ((`SQ_SIZE-gnt2_log) <= next_tail_idx) begin // gnt2_log in upper range in psel_1
                                gnt2_log_to_psel1_idx = gnt2_log + next_tail_idx - `SQ_SIZE;
                            end else begin // gnt2_log in lower range in psel_1
                                gnt2_log_to_psel1_idx = gnt2_log + next_tail_idx;
                            end







                            if(gnt2 != 0) begin
                            //if(gnt2_log != 0) begin
                               

                                next_SQ[i].value = next_SQ[gnt2_log_to_psel1_idx].value; // forwarding here
                                $display("h and t in the different circle, forwarding done!");
                                $display("next_SQ[%0d].value: %b  next_SQ[%0d].value: %b", i, next_SQ[i].value, gnt2_log_to_psel1_idx, next_SQ[gnt2_log_to_psel1_idx].value);
                                next_SQ[i].retire_valid = 1;
                                // $display("[5.356] gnt2_log: %0d", gnt2_log);
                                // $display("[5.356] next_SQ[%0d].value: %b  next_SQ[%0d].value: %b", i, next_SQ[i].value, gnt2_log, next_SQ[gnt2_log].value);
                            end else begin
                                next_SQ[i].retire_valid = 0;
                            end       

                        end

                        // get data from DCache or send data to DCache
                        if (next_SQ[i].retire_valid==0) begin
                            if ((DC_SQ_packet[0].st_or_ld==1) && (DC_SQ_packet[0].valid==1) && (DC_SQ_packet[0].address=={next_SQ[i].word_addr, next_SQ[i].res_addr}) && (DC_SQ_packet[0].T == next_SQ[i].T)) begin
                                next_SQ[i].value = DC_SQ_packet[0].value;
                                next_SQ[i].retire_valid = 1;    

                            end else if ((DC_SQ_packet[1].st_or_ld==1) && (DC_SQ_packet[1].valid==1) && (DC_SQ_packet[1].address=={next_SQ[i].word_addr, next_SQ[i].res_addr}) && (DC_SQ_packet[1].T == next_SQ[i].T)) begin
                                next_SQ[i].value = DC_SQ_packet[1].value;
                                next_SQ[i].retire_valid = 1;

                            end else if ((next_SQ[i].load_sent_to_DCache==0) && (to_DC_full==0) && ((DC_SQ_packet[0].busy==0) && (DC_SQ_packet[1].busy==0) && (next_SQ[i].addr_cannot_to_DCache==0))) begin                                           
                                next_SQ_DC_packet.valid = 1;
                                next_SQ_DC_packet.address = {next_SQ[i].word_addr, next_SQ[i].res_addr};
                                next_SQ_DC_packet.value = 0; // should be useless
                                next_SQ_DC_packet.st_or_ld = 1;
                                next_SQ_DC_packet.mem_size = next_SQ[i].mem_size[1:0];
                                next_SQ_DC_packet.T = next_SQ[i].T;

                               
                                to_DC_full = 1;
                                next_SQ[i].load_sent_to_DCache = 1;
                                
                            end
                        end
                    end
                end
            end                             // for loop end, may we need to add to_DC_full=0 here?


            // [6.] Send load to complete buffer according to retire_valid (send only 1 load here)
            if (next_head_flag==next_tail_flag) begin // h and t in the same circle
                for (int i=0; i<`SQ_SIZE; i=i+1) begin
                    if (i>=next_head_idx && i<next_tail_idx) begin
                        if ((next_SQ[i].valid==1) && (next_SQ[i].load_1_store_0==1) && (next_SQ[i].retire_valid==1) && (next_SQ[i].sent_to_CompBuff==0) && (LSQ_buffer_busy==0)) begin
                            next_SQ_COMP_packet.T = next_SQ[i].T;
                            next_SQ_COMP_packet.value = next_SQ[i].value;
                            next_SQ_COMP_packet.valid = next_SQ[i].valid;
                            next_SQ_COMP_packet.branch_taken = 0;
                            next_SQ_COMP_packet.NPC = next_SQ[i].NPC;
                            next_SQ_COMP_packet.halt = next_SQ[i].halt;

                            next_SQ[i].sent_to_CompBuff = 1;
                            break;
                        end
                    end
                end
            end else begin // h and t in differnet circles
                for (int i=0; i<`SQ_SIZE; i=i+1) begin
                    load_sent_in_lower = 0;             
                    if (i>=next_head_idx && i<`SQ_SIZE) begin
                        if ((next_SQ[i].valid==1) && (next_SQ[i].load_1_store_0==1) && (next_SQ[i].retire_valid==1) && (next_SQ[i].sent_to_CompBuff==0) && (LSQ_buffer_busy==0)) begin
                            next_SQ_COMP_packet.T = next_SQ[i].T;
                            next_SQ_COMP_packet.value = next_SQ[i].value;
                            next_SQ_COMP_packet.valid = next_SQ[i].valid;
                            next_SQ_COMP_packet.branch_taken = 0;
                            next_SQ_COMP_packet.NPC = next_SQ[i].NPC;
                            next_SQ_COMP_packet.halt = next_SQ[i].halt;

                            next_SQ[i[$clog2(`SQ_SIZE)-1:0]].sent_to_CompBuff = 1;
                            load_sent_in_lower = 1;
                            break;
                        end
                    end
                end
                if (load_sent_in_lower==0) begin
                    for (int i=0; i<next_tail_idx; i=i+1) begin
                        if ((next_SQ[i].valid==1) && (next_SQ[i].load_1_store_0==1) && (next_SQ[i].retire_valid==1) && (next_SQ[i].sent_to_CompBuff==0) && (LSQ_buffer_busy==0)) begin
                            next_SQ_COMP_packet.T = next_SQ[i].T;
                            next_SQ_COMP_packet.value = next_SQ[i].value;
                            next_SQ_COMP_packet.valid = next_SQ[i].valid;
                            next_SQ_COMP_packet.branch_taken = 0;
                            next_SQ_COMP_packet.NPC = next_SQ[i].NPC;
                            next_SQ_COMP_packet.halt = next_SQ[i].halt;

                            next_SQ[i].sent_to_CompBuff = 1;
                            break;
                        end
                    end
                end
            end


            // [7.] Give the head retire_valid (ROB only give me 1 load or store each cycle)
            for (int i=0; i<3; i=i+1) begin
                if ((next_SQ[next_head_idx].valid==1) && (RT_packet[i].retire_tag==next_SQ[next_head_idx].T) && (RT_packet[i].valid==1)) begin//RT_packet[i].valid==1
                    next_SQ[next_head_idx].retire_valid = 1;
                    break;
                end
            end

            // [8.] Retire the head (the DCache can only have 1 input in our design, and we also need to consider the previous load in [5])
            if ((next_SQ[next_head_idx].valid==1) && (next_SQ[next_head_idx].load_1_store_0==0) && (next_SQ[next_head_idx].retire_valid==1) && (to_DC_full==0) && (DC_SQ_packet[0].busy==0) && (DC_SQ_packet[1].busy==0) && (next_SQ[next_head_idx].addr_cannot_to_DCache==0)) begin
                next_SQ_DC_packet.valid = 1;
                next_SQ_DC_packet.address = {next_SQ[next_head_idx].word_addr, next_SQ[next_head_idx].res_addr};
                next_SQ_DC_packet.value = next_SQ[next_head_idx].value;
                next_SQ_DC_packet.st_or_ld = 0;
                next_SQ_DC_packet.mem_size = next_SQ[next_head_idx].mem_size[1:0];
                next_SQ_DC_packet.T = next_SQ[next_head_idx].T;

                
                // Free the retired store
                next_SQ[next_head_idx] = 0;
                next_head = head + 1;

            end else if ((next_SQ[next_head_idx].valid==1) && (next_SQ[next_head_idx].load_1_store_0==1) && (next_SQ[next_head_idx].retire_valid==1) && (next_SQ[next_head_idx].sent_to_CompBuff==1)) begin
                // Free the retired load (here I "retire" the load earliar because of design of [3][4])
                // Also, we should have sent the first retire_valid load to Buffer so we can retire safely
                next_SQ[next_head_idx] = 0;
                next_head = head + 1;
            end
                to_DC_full = 0;
        end  
    end


    // PSEL_1bit PSEL_1bit_1 (
    //     .req(req1),
    //     .gnt(gnt1)
    // );

    // PSEL_1bit PSEL_1bit_2 (
    //     .req(req2),
    //     .gnt(gnt2)
    // );

    // always_ff @(posedge clock) begin
    //     for (int i=0; i<3; i=i+1) begin
    //         if (LOAD_STORE_input[i].valid==1) begin
    //             // todo: give information according to the position
    //             $display("position[%0d]: %b", i, position[i]);
    //             $display("LOAD_STORE_input[%0d].tag: %b", i, LOAD_STORE_input[i].T);
    //             $display("LOAD_STORE_input[%0d].word_addr: %b", i, LOAD_STORE_input[i].word_addr);
    //             $display("LOAD_STORE_input[%0d].res_addr: %b", i, LOAD_STORE_input[i].res_addr);
    //             $display("LOAD_STORE_input[%0d].value: %b", i, LOAD_STORE_input[i].value);
    //             $display("LOAD_STORE_input[%0d].load_1_store_0: %b", i, LOAD_STORE_input[i].load_1_store_0);
    //             $display("LOAD_STORE_input[%0d].valid: %b", i, LOAD_STORE_input[i].valid);
    //         end    
    //     end
    // end

                 



    always_ff @(posedge clock) begin

            $display("next_head: %b LOAD_STORE_input.valid:%b%b%b", next_head, LOAD_STORE_input[0].valid, LOAD_STORE_input[1].valid, LOAD_STORE_input[2].valid);
            $display("next_tail: %b position:%b", next_tail, position);  
            $display("LSQ_buffer_busy: %b", LSQ_buffer_busy);   
        for (int i=0; i<`SQ_SIZE; i=i+1) begin
            //$display("next_SQ[%0d].addr_cannot_to_DCache: %b", i, next_SQ[i].addr_cannot_to_DCache);
            //$display("next_SQ[%0d].pre_store_done: %b", i, next_SQ[i].pre_store_done);
            //$display("next_SQ[%0d].retire_valid: %b", i, next_SQ[i].retire_valid);
            //$display("next_SQ[%0d].sent_to_CompBuff: %b", i, next_SQ[i].sent_to_CompBuff);
            //$display("next_SQ[%0d].load_sent_to_DCache: %b", i, next_SQ[i].load_sent_to_DCache);
            $display("next_SQ[%0d].valid: %b", i, next_SQ[i].valid);
            $display("next_SQ[%0d].T: %b", i, next_SQ[i].T);
            $display("next_SQ[%0d].word_addr: %b", i, next_SQ[i].word_addr);
            $display("next_SQ[%0d].res_addr: %b", i, next_SQ[i].res_addr);
            $display("next_SQ[%0d].value: %h", i, next_SQ[i].value);
            $display("next_SQ[%0d].load_1_store_0: %b", i, next_SQ[i].load_1_store_0);
            $display("next_SQ[%0d].mem_size: %b", i, next_SQ[i].mem_size);
            $display("next_SQ[%0d].NPC: %h", i, next_SQ[i].NPC);

        end

        if (reset || clear) begin
            SQ <= 0;
            head <= 0;
            tail <= 0;
            SQ_COMP_packet <= 0;
            SQ_DC_packet <= 0;
	    SQ_full <= 0;

        end else begin
            SQ <= next_SQ;
            head <= next_head;
            tail <= next_tail;
            SQ_COMP_packet <= next_SQ_COMP_packet;
            SQ_DC_packet <= next_SQ_DC_packet;
	    SQ_full <= next_SQ_full;
        end
    end

endmodule


// module PSEL_1bit (
//     input logic [7:0] req,
//     output logic [7:0] gnt
// );

//     logic [7:0] pre_req;

//     assign gnt[7] = req[7];
//     assign pre_req[7] = req[7];
//     genvar i;
//     for(i = 6; i>=0; i--)begin
//         assign gnt[i] = req[i] & ~pre_req[i+1];
//         assign pre_req[i] = req[i] | pre_req[i+1];
//     end
// endmodule 
