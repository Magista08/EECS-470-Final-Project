`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module MT(
    input                           clock,reset,
    input                           squash_flag,    // for precise state
    input  ROB_MT_PACKET [2:0]      rob_packet,
    input  DP_PACKET     [2:0]      dp_packet,      // signal from dispatch stage to decide to start renewing
    input  RT_MT_PACKET  [2:0]      rt_packet,
    input  CDB_MT_PACKET    [2:0]   cdb_packet,     // result from exe stage to write into ROB and CDB

    output MT_RS_PACKET  [2:0]      mt_rs_packet,
    output MT_ROB_PACKET [2:0]      mt_rob_packet,
    output  logic        [4:0]      my_case [2:0],
    output logic    [30:0]                       N_VALID
);

    logic    [$clog2(`ROBLEN)-1:0] MAP_TABLE [30:0]; 
    logic    [$clog2(`ROBLEN)-1:0] N_MAP_TABLE [30:0];
    logic    [30:0]                       PLUS_BIT;
    logic    [30:0]                       N_PLUS_BIT;
    //logic    [30:0]                       N_VALID;
    logic    [30:0]                       VALID;

    // MT_RS_PACKET  [2:0]                  mt_rs_packet; 
    // MT_ROB_PACKET [2:0]                  mt_rob_packet;

    /*initial begin                            // MT is empty when begin
        //MAP_TABLE [30:0] = {5'b11111{$clog2(`ROBLEN){1'b0}}};
        for (int i=0; i <= 30; i++) begin
            MAP_TABLE[i] = {$clog2(`ROBLEN){1'b0}};
        end

        PLUS_BIT  [30:0] = 31'b0;
        VALID     [30:0] = 31'b0;

        mt_rs_packet[0] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };

        mt_rs_packet[1] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };

        mt_rs_packet[2] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };

        mt_rob_packet[0] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };

        mt_rob_packet[1] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };

        mt_rob_packet[2] = '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
        };
    end */

    always_comb begin                                                           // for renewing inner MAP_TABLE
        if (squash_flag || reset) begin
            for (int i=0; i <= 30; i++) begin
                MAP_TABLE[i] = {$clog2(`ROBLEN){1'b0}};
            end
            PLUS_BIT  [30:0] = 31'b0;
            VALID     [30:0] = 31'b0;
        end else begin
            MAP_TABLE[30:0] = N_MAP_TABLE[30:0];
            VALID[30:0] = N_VALID [30:0];
            PLUS_BIT[30:0] = N_PLUS_BIT[30:0];                                   // squash_flag = 0 and reset = 0
            for (int line=0; line<31; line++) begin             // compare tag in mt with tag in cdb ???如果mt中有overwritten怎么办（rs_line中解决了）
                //if(cdb_packet[0] != 0 && cdb_packet[1] != 0 && cdb_packet[2] != 0) begin
                if ((cdb_packet[0].valid && MAP_TABLE[line] == cdb_packet[0].Tag) || (cdb_packet[1].valid && MAP_TABLE[line] == cdb_packet[1].Tag) || (cdb_packet[2].valid && MAP_TABLE[line] == cdb_packet[2].Tag)) begin //判断cdb是否有值并且和每一行mt比较
                    PLUS_BIT[line] = 1;
                    //VALID[line] = 1;
                end 
                // end else if(cdb_packet[0] == 0) begin
                    
                // end else if(cdb_packet[1] == 0) begin
                // end else if(cdb_packet[2] == 0) begin
                // end
                if (rt_packet[0].valid && MAP_TABLE[line] == rt_packet[0].retire_tag) begin
                    VALID[line] = 0;
                    PLUS_BIT[line] = 0;
                end else if (rt_packet[1].valid && MAP_TABLE[line] == rt_packet[1].retire_tag) begin
                    VALID[line] = 0;
                    PLUS_BIT[line] = 0;
                end else if (rt_packet[2].valid && MAP_TABLE[line] == rt_packet[2].retire_tag) begin
                    VALID[line] = 0;
                    PLUS_BIT[line] = 0;
                end
            end
            for (int i=0; i<3; i++) begin
                if (rob_packet[i].valid) begin                                                                                //插入的指令rd != empty时
                        MAP_TABLE[rob_packet[i].R - 5'b00001] = rob_packet[i].T;                                          // ??????assign tag to corresponding register 
                        PLUS_BIT[rob_packet[i].R - 5'b00001] = 0;
                        VALID[rob_packet[i].R - 5'b00001] = 1;   
                end  
            end
        end 
    end 

    always_comb begin                               // for updating output
        if (squash_flag || reset) begin             // precise state
            mt_rob_packet[0] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };

            mt_rs_packet[0] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };
            my_case[0]=5'b0;
        end else begin       
            if (!dp_packet[0].illegal) begin  
                if(dp_packet[0].inst.r.rs1 != 5'd0 && dp_packet[0].inst.r.rs2 != 5'd0)begin                                                               // rs1 and rs2 are not ZERO reg
                    if(dp_packet[0].rs1_instruction && dp_packet[0].rs2_instruction) begin                                        //rs1 and rs2 have been used
                        if (!N_VALID[dp_packet[0].inst.r.rs1 - 5'b00001] && !N_VALID[dp_packet[0].inst.r.rs2 - 5'b00001]) begin   //需要的两个rs对应的mt都为空
                            mt_rs_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };

                            mt_rob_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };
                            my_case[0] = 5'b00001;
                        end else if (!N_VALID[dp_packet[0].inst.r.rs1 - 5'b00001]) begin       // only rs1 mt is empty
                            if (N_PLUS_BIT[dp_packet[0].inst.r.rs2 - 5'b00001]) begin          // rs2对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                                my_case[0] = 5'b10;
                            end else begin                                                 // rs2对应的plus_bit = 0
                                mt_rob_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[0] = 5'b11;
                            end
                        end else if (!N_VALID[dp_packet[0].inst.r.rs2 - 5'b00001]) begin        // only rs2 mt is empty
                            if (N_PLUS_BIT[dp_packet[0].inst.r.rs1 - 5'b00001]) begin           // rs1对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[0] = '{
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[0] = '{
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[0] = 5'b100;
                            end else begin                                                 // rs1对应的plus_bit = 0
                                mt_rob_packet[0] = '{
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[0] = '{
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[0] = 5'b101;
                            end
                        end else begin                                                     // both rs1 and rs2 mt are not empty
                            mt_rob_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[0].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[0].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                            
                            mt_rs_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[0].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[0].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                                my_case[0] = 5'b110;
                        end
                    end else if(dp_packet[0].rs1_instruction) begin                      // only rs1 is used
                        if(!N_VALID[dp_packet[0].inst.r.rs1 - 5'b00001]) begin           // rs1 in mt has not been taken
                            mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };
                            my_case[0] = 5'b10111;
                        end else begin                                                    // rs1 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[0].inst.r.rs1 - 5'b00001]) begin      // PLUS_bit for rs1 is 1
                                mt_rob_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            end else begin                                                  // PLUS_BIT for rs1 is 0
                                mt_rob_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            my_case[0] = 5'b11100;
                            end
                        end
                    end else if(dp_packet[0].rs2_instruction) begin                      // only rs2 has been used
                        if(!N_VALID[dp_packet[0].inst.r.rs2 - 5'b00001]) begin           // rs2 in mt has not been taken
                            mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            my_case[0] = 5'b11111;
                        end else begin                                                    // rs2 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[0].inst.r.rs2 - 5'b00001]) begin      // PLUS_bit for rs2 is 1
                                mt_rob_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                            end else begin                                                  // PLUS_BIT for rs2 is 0
                                mt_rob_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[0] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[0] = 5'b11110;
                            end
                        end
                    end else begin                                                      // rs1 and rs2 have not been used
                        mt_rob_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };

                        mt_rs_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };
                    end
                end else if(dp_packet[0].inst.r.rs1 == 5'd0) begin
                    if(dp_packet[0].rs2_instruction) begin
                        if(!N_VALID[dp_packet[0].inst.r.rs2 - 5'b00001]) begin
                            mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                            my_case[0] = 5'b11101;
                        end else begin
                            if(N_PLUS_BIT[dp_packet[0].inst.r.rs2 - 5'b00001]) begin
                                mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end else begin
                                mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[0].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else if(dp_packet[0].inst.r.rs2 == 5'd0) begin
                    if(dp_packet[0].rs1_instruction) begin
                        if(!N_VALID[dp_packet[0].inst.r.rs1 - 5'b00001]) begin
                            mt_rs_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[0] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                        end else begin
                            if(N_PLUS_BIT[dp_packet[0].inst.r.rs1 - 5'b00001]) begin
                                mt_rs_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end else begin
                                mt_rs_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[0] = '{
                                N_MAP_TABLE[dp_packet[0].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[0] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else begin                              // rs1 and rs2 are both ZERO REG
                    mt_rs_packet[0] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };

                    mt_rob_packet[0] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };    
                end

            end else begin                                                          // if inserted inst. valid =0 or illegal =1    
                mt_rs_packet[0] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };

                mt_rob_packet[0] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };
                my_case[0] = 5'b111;
            end 
        end
    end

    always_comb begin                               // for updating output
        if (squash_flag || reset) begin             // precise state
            mt_rob_packet[1] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };

            mt_rs_packet[1] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };
            my_case[1]=5'b0;
        end else begin       
            if (!dp_packet[1].illegal) begin  
                if(dp_packet[1].inst.r.rs1 != 5'd0 && dp_packet[1].inst.r.rs2 != 5'd0)begin                                                               // rs1 and rs2 are not ZERO reg
                    if(dp_packet[1].rs1_instruction && dp_packet[1].rs2_instruction) begin                                        //rs1 and rs2 have been used
                        if (!N_VALID[dp_packet[1].inst.r.rs1 - 5'b00001] && !N_VALID[dp_packet[1].inst.r.rs2 - 5'b00001]) begin   //需要的两个rs对应的mt都为空
                            mt_rs_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };

                            mt_rob_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };
                            my_case[1] = 5'b00001;
                        end else if (!N_VALID[dp_packet[1].inst.r.rs1 - 5'b00001]) begin       // only rs1 mt is empty
                            if (N_PLUS_BIT[dp_packet[1].inst.r.rs2 - 5'b00001]) begin          // rs2对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                                my_case[1] = 5'b10;
                            end else begin                                                 // rs2对应的plus_bit = 0
                                mt_rob_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[1] = 5'b11;
                            end
                        end else if (!N_VALID[dp_packet[1].inst.r.rs2 - 5'b00001]) begin        // only rs2 mt is empty
                            if (N_PLUS_BIT[dp_packet[1].inst.r.rs1 - 5'b00001]) begin           // rs1对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[1] = '{
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[1] = '{
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[1] = 5'b100;
                            end else begin                                                 // rs1对应的plus_bit = 0
                                mt_rob_packet[1] = '{
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[1] = '{
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[1] = 5'b101;
                            end
                        end else begin                                                     // both rs1 and rs2 mt are not empty
                            mt_rob_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[1].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[1].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                            
                            mt_rs_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[1].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[1].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                                my_case[1] = 5'b110;
                        end
                    end else if(dp_packet[1].rs1_instruction) begin                      // only rs1 is used
                        if(!N_VALID[dp_packet[1].inst.r.rs1 - 5'b00001]) begin           // rs1 in mt has not been taken
                            mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };
                            my_case[1] = 5'b10111;
                        end else begin                                                    // rs1 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[1].inst.r.rs1 - 5'b00001]) begin      // PLUS_bit for rs1 is 1
                                mt_rob_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            end else begin                                                  // PLUS_BIT for rs1 is 0
                                mt_rob_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            my_case[1] = 5'b11100;
                            end
                        end
                    end else if(dp_packet[1].rs2_instruction) begin                      // only rs2 has been used
                        if(!N_VALID[dp_packet[1].inst.r.rs2 - 5'b00001]) begin           // rs2 in mt has not been taken
                            mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            my_case[1] = 5'b11111;
                        end else begin                                                    // rs2 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[1].inst.r.rs2 - 5'b00001]) begin      // PLUS_bit for rs2 is 1
                                mt_rob_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                            end else begin                                                  // PLUS_BIT for rs2 is 0
                                mt_rob_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[1] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[1] = 5'b11110;
                            end
                        end
                    end else begin                                                      // rs1 and rs2 have not been used
                        mt_rob_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };

                        mt_rs_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };
                    end
                end else if(dp_packet[1].inst.r.rs1 == 5'd0) begin
                    if(dp_packet[1].rs2_instruction) begin
                        if(!N_VALID[dp_packet[1].inst.r.rs2 - 5'b00001]) begin
                            mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                            my_case[1] = 5'b11101;
                        end else begin
                            if(N_PLUS_BIT[dp_packet[1].inst.r.rs2 - 5'b00001]) begin
                                mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end else begin
                                mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[1].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else if(dp_packet[1].inst.r.rs2 == 5'd0) begin
                    if(dp_packet[1].rs1_instruction) begin
                        if(!N_VALID[dp_packet[1].inst.r.rs1 - 5'b00001]) begin
                            mt_rs_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[1] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                        end else begin
                            if(N_PLUS_BIT[dp_packet[1].inst.r.rs1 - 5'b00001]) begin
                                mt_rs_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end else begin
                                mt_rs_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[1] = '{
                                N_MAP_TABLE[dp_packet[1].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[1] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else begin                              // rs1 and rs2 are both ZERO REG
                    mt_rs_packet[1] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };

                    mt_rob_packet[1] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };    
                end

            end else begin                                                          // if inserted inst. valid =0 or illegal =1    
                mt_rs_packet[1] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };

                mt_rob_packet[1] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };
                my_case[1] = 5'b111;
            end 
        end
    end

    always_comb begin                               // for updating output
        if (squash_flag || reset) begin             // precise state
            mt_rob_packet[2] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };

            mt_rs_packet[2] = '{
                {$clog2(`ROBLEN){1'b0}},        // T1
                {$clog2(`ROBLEN){1'b0}},        // T2
                1'b0,                           // T1_plus
                1'b0,                           // T2_plus
                1'b0,                           // valid1
                1'b0                            // valid2
            };
            my_case[2]=5'b0;
        end else begin       
            if (!dp_packet[2].illegal) begin  
                if(dp_packet[2].inst.r.rs1 != 5'd0 && dp_packet[2].inst.r.rs2 != 5'd0)begin                                                               // rs1 and rs2 are not ZERO reg
                    if(dp_packet[2].rs1_instruction && dp_packet[2].rs2_instruction) begin                                        //rs1 and rs2 have been used
                        if (!N_VALID[dp_packet[2].inst.r.rs1 - 5'b00001] && !N_VALID[dp_packet[2].inst.r.rs2 - 5'b00001]) begin   //需要的两个rs对应的mt都为空
                            mt_rs_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };

                            mt_rob_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };
                            my_case[2] = 5'b00001;
                        end else if (!N_VALID[dp_packet[2].inst.r.rs1 - 5'b00001]) begin       // only rs1 mt is empty
                            if (N_PLUS_BIT[dp_packet[2].inst.r.rs2 - 5'b00001]) begin          // rs2对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                                my_case[2] = 5'b10;
                            end else begin                                                 // rs2对应的plus_bit = 0
                                mt_rob_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[2] = 5'b11;
                            end
                        end else if (!N_VALID[dp_packet[2].inst.r.rs2 - 5'b00001]) begin        // only rs2 mt is empty
                            if (N_PLUS_BIT[dp_packet[2].inst.r.rs1 - 5'b00001]) begin           // rs1对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[2] = '{
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[2] = '{
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[2] = 5'b100;
                            end else begin                                                 // rs1对应的plus_bit = 0
                                mt_rob_packet[2] = '{
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[2] = '{
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                                my_case[2] = 5'b101;
                            end
                        end else begin                                                     // both rs1 and rs2 mt are not empty
                            mt_rob_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[2].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[2].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                            
                            mt_rs_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                N_PLUS_BIT[dp_packet[2].inst.r.rs1 - 5'b00001],
                                N_PLUS_BIT[dp_packet[2].inst.r.rs2 - 5'b00001],
                                1'b1,
                                1'b1
                                };
                                my_case[2] = 5'b110;
                        end
                    end else if(dp_packet[2].rs1_instruction) begin                      // only rs1 is used
                        if(!N_VALID[dp_packet[2].inst.r.rs1 - 5'b00001]) begin           // rs1 in mt has not been taken
                            mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };
                            my_case[2] = 5'b10111;
                        end else begin                                                    // rs1 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[2].inst.r.rs1 - 5'b00001]) begin      // PLUS_bit for rs1 is 1
                                mt_rob_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b1,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            end else begin                                                  // PLUS_BIT for rs1 is 0
                                mt_rob_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };

                            mt_rs_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b0
                            };
                            my_case[2] = 5'b11100;
                            end
                        end
                    end else if(dp_packet[2].rs2_instruction) begin                      // only rs2 has been used
                        if(!N_VALID[dp_packet[2].inst.r.rs2 - 5'b00001]) begin           // rs2 in mt has not been taken
                            mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},
                                {$clog2(`ROBLEN){1'b0}},
                                1'b0,
                                1'b0,
                                1'b0,
                                1'b0
                            };

                            my_case[2] = 5'b11111;
                        end else begin                                                    // rs2 in mt has been taken
                            if(N_PLUS_BIT[dp_packet[2].inst.r.rs2 - 5'b00001]) begin      // PLUS_bit for rs2 is 1
                                mt_rob_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                            end else begin                                                  // PLUS_BIT for rs2 is 0
                                mt_rob_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[2] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                                my_case[2] = 5'b11110;
                            end
                        end
                    end else begin                                                      // rs1 and rs2 have not been used
                        mt_rob_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };

                        mt_rs_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},
                            {$clog2(`ROBLEN){1'b0}},
                            1'b0,
                            1'b0,
                            1'b0,
                            1'b0
                        };
                    end
                end else if(dp_packet[2].inst.r.rs1 == 5'd0) begin
                    if(dp_packet[2].rs2_instruction) begin
                        if(!N_VALID[dp_packet[2].inst.r.rs2 - 5'b00001]) begin
                            mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                            my_case[2] = 5'b11101;
                        end else begin
                            if(N_PLUS_BIT[dp_packet[2].inst.r.rs2 - 5'b00001]) begin
                                mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b1,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end else begin
                                mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                                mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                N_MAP_TABLE[dp_packet[2].inst.r.rs2 - 5'b00001],        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b1                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else if(dp_packet[2].inst.r.rs2 == 5'd0) begin
                    if(dp_packet[2].rs1_instruction) begin
                        if(!N_VALID[dp_packet[2].inst.r.rs1 - 5'b00001]) begin
                            mt_rs_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };

                            mt_rob_packet[2] = '{
                                {$clog2(`ROBLEN){1'b0}},        // T1
                                {$clog2(`ROBLEN){1'b0}},        // T2
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b0,                           // valid1
                                1'b0                            // valid2
                            };
                        end else begin
                            if(N_PLUS_BIT[dp_packet[2].inst.r.rs1 - 5'b00001]) begin
                                mt_rs_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b1,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end else begin
                                mt_rs_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };

                                mt_rob_packet[2] = '{
                                N_MAP_TABLE[dp_packet[2].inst.r.rs1 - 5'b00001],
                                {$clog2(`ROBLEN){1'b0}},       
                                1'b0,                           // T1_plus
                                1'b0,                           // T2_plus
                                1'b1,                           // valid1
                                1'b0                            // valid2
                                };
                            end 
                        end
                    end else begin
                        mt_rs_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };

                        mt_rob_packet[2] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                        };
                    end 
                end else begin                              // rs1 and rs2 are both ZERO REG
                    mt_rs_packet[2] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };

                    mt_rob_packet[2] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };    
                end

            end else begin                                                          // if inserted inst. valid =0 or illegal =1    
                mt_rs_packet[2] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };

                mt_rob_packet[2] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };
                my_case[2] = 5'b111;
            end 
        end
    end

    always_ff @(posedge clock) begin
        // $display("mt_rs_T1[0]:%h mt_rs_T1_plus[0]:%h mt_rs_valid1[0]:%h mt_rs_T2[0]:%h mt_rs_T2_plus[0]:%h mt_rs_valid2[0]:%h dp_packet[0].rs1:%h dp_packet[0].rs2:%h dp_packet[0].rs1_value:%h dp_packet[0].rs2_value:%h MAP_TABLE[rs1][0]:%h N_VALID[rs1][0]:%h N_PLUS_BIT[rs1][0]:%h MAP_TABLE[rs2][0]:%h N_VALID[rs2][0]:%h N_PLUS_BIT[rs2][0]:%h", mt_rs_packet[0].T1, mt_rs_packet[0].T1_plus, mt_rs_packet[0].valid1, mt_rs_packet[0].T2, mt_rs_packet[0].T2_plus, mt_rs_packet[0].valid2, dp_packet[0].inst.r.rs1, dp_packet[0].inst.r.rs2, dp_packet[0].rs1_value, dp_packet[0].rs2_value, N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3], N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3]);
        // $display("mt_rs_T1[1]:%h mt_rs_T1_plus[1]:%h mt_rs_valid1[1]:%h mt_rs_T2[1]:%h mt_rs_T2_plus[1]:%h mt_rs_valid2[1]:%h dp_packet[1].rs1:%h dp_packet[1].rs2:%h dp_packet[1].rs1_value:%h dp_packet[1].rs2_value:%h MAP_TABLE[rs1][1]:%h N_VALID[rs1][1]:%h N_PLUS_BIT[rs1][1]:%h MAP_TABLE[rs2][1]:%h N_VALID[rs2][1]:%h N_PLUS_BIT[rs2][1]:%h", mt_rs_packet[1].T1, mt_rs_packet[1].T1_plus, mt_rs_packet[1].valid1, mt_rs_packet[1].T2, mt_rs_packet[1].T2_plus, mt_rs_packet[1].valid2, dp_packet[1].inst.r.rs1, dp_packet[1].inst.r.rs2, dp_packet[1].rs1_value, dp_packet[1].rs2_value, N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3], N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3]);
        // $display("mt_rs_T1[2]:%h mt_rs_T1_plus[2]:%h mt_rs_valid1[2]:%h mt_rs_T2[2]:%h mt_rs_T2_plus[2]:%h mt_rs_valid2[2]:%h dp_packet[2].rs1:%h dp_packet[2].rs2:%h dp_packet[2].rs1_value:%h dp_packet[2].rs2_value:%h MAP_TABLE[rs1][2]:%h N_VALID[rs1][2]:%h N_PLUS_BIT[rs1][2]:%h MAP_TABLE[rs2][2]:%h N_VALID[rs2][2]:%h N_PLUS_BIT[rs2][2]:%h", mt_rs_packet[2].T1, mt_rs_packet[2].T1_plus, mt_rs_packet[2].valid1, mt_rs_packet[2].T2, mt_rs_packet[2].T2_plus, mt_rs_packet[2].valid2, dp_packet[2].inst.r.rs1, dp_packet[2].inst.r.rs2, dp_packet[2].rs1_value, dp_packet[2].rs2_value, N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3], N_MAP_TABLE[3], N_VALID[3], N_PLUS_BIT[3]);
        if (squash_flag || reset) begin
            for (int i=0; i <= 30; i++) begin
                N_MAP_TABLE[i] <= {$clog2(`ROBLEN){1'b0}};
            end
            N_VALID [30:0] <= 0;
            N_PLUS_BIT [30:0] <= 0;
        end else begin                                      //？？？？？这里的enable信号我该怎么写
            N_MAP_TABLE [30:0] <= MAP_TABLE [30:0];
            N_VALID [30:0] <= VALID [30:0];
            N_PLUS_BIT [30:0] <= PLUS_BIT[30:0];
        end
    end 
endmodule  