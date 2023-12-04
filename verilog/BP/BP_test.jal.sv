`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module testbench;
    // Input
    logic clock, reset; 
    IF_ID_PACKET [`N-1:0] if_packet;
    EX_BP_PACKET [`N-1:0] ex_bp_packet;
    // Output
    IF_ID_PACKET [`N-1:0] bp_packet;
    logic [`XLEN-1:0] bp_npc;

    // Module call
    BP DUT(
        .clock(clock), 
        .reset(reset),
        .if_packet_in(if_packet),    // pc from if stage
        .ex_bp_packet_in(ex_bp_packet),
        
        // output logic [`N-1:0] [`XLEN-1:0] bp_pc,
        .bp_packet_out(bp_packet),
        .bp_npc_out(bp_npc)
    );

    // Clock
    always begin
        #5 clock = ~clock;
    end

    initial begin
        $monitor("clock:%b, reset:%b, bp_packet[1].npc:%h, bp_npc:%h, if_packet[2].NPC:%h", 
                  clock, reset, bp_packet[1].NPC, bp_npc, if_packet[2].NPC);
        clock = 0;
        reset = 1;
        #10;
        $display("----------------------------------------Reset----------------------------------------");

        // Initialize
        for (int i=0; i<`N; i++) begin
            if_packet[i].valid = 1;
            if_packet[i].inst = `NOP;
            if_packet[i].PC  = 4*i+4;
            if_packet[i].NPC = 4*i+8;
            ex_bp_packet[i].cond_branch_en = 0;
            ex_bp_packet[i].branch_en = 0;
            ex_bp_packet[i].cond_branch_taken = 0;
            ex_bp_packet[i].PC = 0;
            ex_bp_packet[i].target_PC = 0;
        end

        if_packet[1].valid = 1;
        if_packet[1].inst = `RV32_JAL;
        if_packet[1].inst.j.rd = 'h5;
        if_packet[1].inst.j.of = 1'b0;
        if_packet[1].inst.j.et = 'h0;
        if_packet[1].inst.j.s  = 1'b0;
        if_packet[1].inst.j.f  = 'h0;


        if_packet[1].PC = 'h4;
        if_packet[1].NPC = 'h8;

        ex_bp_packet[1].cond_branch_en = 1;
        ex_bp_packet[1].branch_en = 1;
        ex_bp_packet[1].cond_branch_taken = 0;
        ex_bp_packet[1].PC = 'h4;
        ex_bp_packet[1].target_PC = 'h18;

        reset = 0;
        $display();
        $display("----------------------------------------Start Simulation 1----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        $display();
        $display("----------------------------------------Start Simulation 2----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        $display();
        $display("----------------------------------------Start Simulation 3----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 1;
        $display();
        $display("----------------------------------------Start Simulation 4----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        $display();
        $display("----------------------------------------Start Simulation 5----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 1;
        $display();
        $display("----------------------------------------Start Simulation 6----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        if_packet[0].inst = `RV32_ADD;
        if_packet[2].inst = `RV32_BEQ;  
        $display("if_packet[0].inst: %h, if_packet[1].inst: %h, if_packet[2].inst: %h", 
                  if_packet[0].inst, if_packet[1].inst, if_packet[2].inst);
        $display("----------------------------------------Start Simulation 7----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;
        $display("bp_packet[0].inst:%h bp_packet[0].valid:%b, bp_packet[1].inst:%h, bp_packet[1].valid:%b, bp_packet[1].NPC:%h", 
                  bp_packet[0].inst, bp_packet[0].valid, bp_packet[1].inst, bp_packet[1].valid, bp_packet[1].NPC);

        $display();
        $display("----------------------------------------Start Simulation 8----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;
        $display("bp_packet[0].inst:%h bp_packet[0].valid:%b, bp_packet[1].inst:%h, bp_packet[1].valid:%b", 
                  bp_packet[0].inst, bp_packet[0].valid, bp_packet[1].inst, bp_packet[1].valid);

        ex_bp_packet[1].cond_branch_taken = 1;
        if_packet[0].inst = `NOP;
        if_packet[2].inst = `NOP;
        $display();
        $display("----------------------------------------Start Simulation 9----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        $display();
        $display("----------------------------------------Start Simulation 10----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 1;
        $display();
        $display("----------------------------------------Start Simulation 11----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        $display();
        $display("----------------------------------------Start Simulation 12----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        $display();
        $display("----------------------------------------Start Simulation 13----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 1;
        $display();
        $display("----------------------------------------Start Simulation 14----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;

        ex_bp_packet[1].cond_branch_taken = 0;
        $display();
        $display("----------------------------------------Start Simulation 15----------------------------------------");
        $display("if_packet[1].pc: %h ex_bp_packet[1].cond_branch_taken:%b ex_bp_packet[1].PC:%h, ex_bp_packet[1].target_PC:%h", 
                  if_packet[1].PC, ex_bp_packet[1].cond_branch_taken, ex_bp_packet[1].PC, ex_bp_packet[1].target_PC);
        #10;
        $finish;
    end
endmodule