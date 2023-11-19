`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module MT(
    input                           clock,reset,
    input                           squash_flag,    // for precise state
    input  ROB_MT_PACKET [2:0]      rob_packet,
    input  DP_PACKET     [2:0]      dp_packet,      // signal from dispatch stage to decide to start renewing
    input  CDB_MT_PACKET    [2:0]   cdb_packet,     // result from exe stage to write into ROB and CDB

    output MT_RS_PACKET  [2:0]      mt_rs_packet,
    output MT_ROB_PACKET [2:0]      mt_rob_packet
);

    logic    [$clog2(`ROBLEN)-1:0] MAP_TABLE [30:0]; 
    logic    [$clog2(`ROBLEN)-1:0] N_MAP_TABLE [30:0];
    logic    [30:0]                       PLUS_BIT;
    logic    [30:0]                       N_PLUS_BIT;
    logic    [30:0]                       N_VALID;
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

    always_comb begin
        if (squash_flag || reset) begin      // precise state
            for (int i=0; i <= 30; i++) begin
                MAP_TABLE[i] = {$clog2(`ROBLEN){1'b0}};
            end
            PLUS_BIT  [30:0] = 31'b0;
            VALID     [30:0] = 31'b0;

            for(int m=0; m<3; m++) begin
                mt_rob_packet[m] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };

                mt_rs_packet[m] = '{
                    {$clog2(`ROBLEN){1'b0}},        // T1
                    {$clog2(`ROBLEN){1'b0}},        // T2
                    1'b0,                           // T1_plus
                    1'b0,                           // T2_plus
                    1'b0,                           // valid1
                    1'b0                            // valid2
                };
            end

        end else begin                                          // squash_flag = 0 and reset = 0
            for (int line=0; line<31; line++) begin             // compare tag in mt with tag in cdb ???如果mt中有overwritten怎么办（rs_line中解决了）
                if ((cdb_packet[0].valid && MAP_TABLE[line] == cdb_packet[0].Tag) || (cdb_packet[1].valid && MAP_TABLE[line] == cdb_packet[1].Tag) || (cdb_packet[2].valid && MAP_TABLE[line] == cdb_packet[2].Tag)) begin //判断cdb是否有值并且和每一行mt比较
                    PLUS_BIT[line] = 1;
                    VALID[line] = 1;
                end
            end

            for (int i=0; i<3; i++) begin
                if (dp_packet[i].valid && !dp_packet[i].illegal) begin                                            // 可以插入inst 且 inst != 'NOOP
                    if (!rob_packet[i].valid) begin                                                                // rob_mt.packet里的rd为空
                        MAP_TABLE[30:0] = N_MAP_TABLE[30:0];                                                        // mt里的tag值保持不变
                        VALID[30:0] = N_VALID [30:0];
                        PLUS_BIT[30:0] = N_PLUS_BIT[30:0];
                    end else begin                                                                                //插入的指令rd != empty时
                        MAP_TABLE[rob_packet[i].R - 5'b00001] = rob_packet[i].T;                                          // ??????assign tag to corresponding register 
                        PLUS_BIT[rob_packet[i].R - 5'b00001] = 0;
                        VALID[rob_packet[i].R - 5'b00001] = 1;                                                            // indicates the line is occupied
                        if (!VALID[dp_packet[i].inst.r.rs1 - 5'b00001] && !VALID[dp_packet[i].inst.r.rs2 - 5'b00001]) begin   //需要的两个rs对应的mt都为空
                            mt_rs_packet[i] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };

                            mt_rob_packet[i] = '{
                            {$clog2(`ROBLEN){1'b0}},        // T1
                            {$clog2(`ROBLEN){1'b0}},        // T2
                            1'b0,                           // T1_plus
                            1'b0,                           // T2_plus
                            1'b0,                           // valid1
                            1'b0                            // valid2
                            };
                        end else if (!VALID[dp_packet[i].inst.r.rs1 - 5'b00001]) begin       // only rs1 mt is empty
                            if (PLUS_BIT[dp_packet[i].inst.r.rs2 - 5'b00001]) begin          // rs2对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[i] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[i] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b1,
                                    1'b0,
                                    1'b1
                                };
                            end else begin                                                 // rs2对应的plus_bit = 0
                                mt_rob_packet[i] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };

                                mt_rs_packet[i] = '{
                                    {$clog2(`ROBLEN){1'b0}},
                                    MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                    1'b0,
                                    1'b0,
                                    1'b0,
                                    1'b1
                                };
                            end
                        end else if (!VALID[dp_packet[i].inst.r.rs2 - 5'b00001]) begin        // only rs2 mt is empty
                            if (PLUS_BIT[dp_packet[i].inst.r.rs1 - 5'b00001]) begin           // rs1对应的plus_bit = 1,我应该先检查cdb（在one_line中解决了）
                                mt_rob_packet[i] = '{
                                    MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[i] = '{
                                    MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b1,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                            end else begin                                                 // rs1对应的plus_bit = 0
                                mt_rob_packet[i] = '{
                                    MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };

                                mt_rs_packet[i] = '{
                                    MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                    {$clog2(`ROBLEN){1'b0}},
                                    1'b0,
                                    1'b0,
                                    1'b1,
                                    1'b0
                                };
                            end
                        end else begin                                                     // both rs1 and rs2 mt are not empty
                            mt_rob_packet[i] = '{
                                MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b1
                            };

                            mt_rs_packet[i] = '{
                                MAP_TABLE[dp_packet[i].inst.r.rs1 - 5'b00001],
                                MAP_TABLE[dp_packet[i].inst.r.rs2 - 5'b00001],
                                1'b0,
                                1'b0,
                                1'b1,
                                1'b1
                            };
                        end
                    end
                end else begin                                                          // if inserted inst. valid =0 or illegal =1    
                    mt_rs_packet[i] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };

                    mt_rob_packet[i] = '{
                        {$clog2(`ROBLEN){1'b0}},        // T1
                        {$clog2(`ROBLEN){1'b0}},        // T2
                        1'b0,                           // T1_plus
                        1'b0,                           // T2_plus
                        1'b0,                           // valid1
                        1'b0                            // valid2
                    };
                end 
            end
        end
    end

    always_ff @(posedge clock) begin
        $display("rs_T1[0]:%h rs_T2[0]:%h rs_T1+:%h rs_T2+:%h rs_valid1:%h rs_valid2:%h", mt_rs_packet[0].T1, mt_rs_packet[0].T2, mt_rs_packet[0].T1_plus, mt_rs_packet[0].T2_plus, mt_rs_packet[0].valid1, mt_rs_packet[0].valid2);
        $display("rs_T1[1]:%h rs_T2[1]:%h rs_T1+:%h rs_T2+:%h rs_valid1:%h rs_valid2:%h", mt_rs_packet[1].T1, mt_rs_packet[1].T2, mt_rs_packet[1].T1_plus, mt_rs_packet[1].T2_plus, mt_rs_packet[1].valid1, mt_rs_packet[1].valid2);
        $display("rs_T1[2]:%h rs_T2[2]:%h rs_T1+:%h rs_T2+:%h rs_valid1:%h rs_valid2:%h", mt_rs_packet[2].T1, mt_rs_packet[2].T2, mt_rs_packet[2].T1_plus, mt_rs_packet[2].T2_plus, mt_rs_packet[2].valid1, mt_rs_packet[2].valid2);
        if (squash_flag || reset) begin
           /* mt_rs_packet[0] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            };

            mt_rs_packet[1] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            };

            mt_rs_packet[2] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            };

            mt_rob_packet[0] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            };

            mt_rob_packet[1] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            };

            mt_rob_packet[2] <= '{
            {$clog2(`ROBLEN){1'b0}},        // T1
            {$clog2(`ROBLEN){1'b0}},        // T2
            1'b0,                           // T1_plus
            1'b0,                           // T2_plus
            1'b0,                           // valid1
            1'b0                            // valid2
            }; */

            for (int i=0; i <= 30; i++) begin
                N_MAP_TABLE[i] <= {$clog2(`ROBLEN){1'b0}};
            end
            N_VALID [30:0] <= 0;
            N_PLUS_BIT [30:0] <= 0;
        end else begin                                      //？？？？？这里的enable信号我该怎么写
            // mt_rs_packet[0] <= mt_rs_packet[0];
            // mt_rs_packet[1] <= mt_rs_packet[1];
            // mt_rs_packet[2] <= mt_rs_packet[2];
            // mt_rob_packet[0] <= mt_rob_packet[0];
            // mt_rob_packet[1] <= mt_rob_packet[1];
            // mt_rob_packet[2] <= mt_rob_packet[2];
            N_MAP_TABLE [30:0] <= MAP_TABLE [30:0];
            N_VALID [30:0] <= VALID [30:0];
            N_PLUS_BIT [30:0] <= PLUS_BIT[30:0];
        end
    end 
endmodule  



