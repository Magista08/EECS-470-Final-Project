
// The decoder, copied from p3/stage_id.sv without changes

`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

// Decode an instruction: generate useful datapath control signals by matching the RISC-V ISA
// This module is purely combinational
module DEC (
    input INST  inst,
    input logic valid, // when low, ignore inst. Output will look like a NOP

    output ALU_OPA_SELECT opa_select,
    output ALU_OPB_SELECT opb_select,
    // output logic          has_dest, // if there is a destination register
    output logic [4:0]    dest_reg_idx,
    output ALU_FUNC       alu_func,
    output logic          rd_mem, wr_mem, cond_branch, uncond_branch,
    output logic          csr_op, // used for CSR operations, we only use this as a cheap way to get the return code out
    output logic          halt,   // non-zero on a halt
    output logic          illegal, // non-zero on an illegal instruction
    output logic          valid_out, // non-zero on an valid_out instruction

    output logic          rs1_instruction, rs2_instruction, // Whether rs1 and rs2 is in use 1: in use, 0: not in use
    output logic          dest_reg_valid, // Whether the destination register is in used 1: in use, 0: not in use
    output FUNC_UNIT      func_unit // Which functional unit is in use
);

    // Note: I recommend using an IDE's code folding feature on this block
    always_comb begin
        // Default control values (looks like a NOP)
        // See sys_defs.svh for the constants used here
        opa_select    = OPA_IS_RS1;
        opb_select    = OPB_IS_RS2;
        alu_func      = ALU_ADD;
        // has_dest      = 1'b0;
        dest_reg_idx  = `ZERO_REG;
        
        csr_op        = 1'b0;
        rd_mem        = 1'b0;
        wr_mem        = 1'b0;
        cond_branch   = 1'b0;
        uncond_branch = 1'b0;
        halt          = 1'b0;
        valid_out       = 1'b0;
        illegal       = ~valid;

        rs1_instruction = 0;
        rs2_instruction = 0;

        dest_reg_valid = valid;

        func_unit = FUNC_ALU;

        if (valid) begin
            casez (inst)
                `RV32_LUI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx = inst.r.rd;
                    opa_select   = OPA_IS_ZERO;
                    opb_select   = OPB_IS_U_IMM;
                end
                `RV32_AUIPC: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx = inst.r.rd;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_U_IMM;
                end
                `RV32_JAL: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx  = inst.r.rd;
                    opa_select    = OPA_IS_PC;
                    opb_select    = OPB_IS_J_IMM;
                    uncond_branch = `TRUE;
                end
                `RV32_JALR: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opa_select      = OPA_IS_RS1;
                    opb_select      = OPB_IS_I_IMM;
                    uncond_branch   = `TRUE;
                    rs1_instruction = 1;
                end
                `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
                `RV32_BLTU, `RV32_BGEU: begin
                    dest_reg_valid   = 0;
                    opa_select      = OPA_IS_PC;
                    opb_select      = OPB_IS_B_IMM;
                    cond_branch     = `TRUE;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_LB, `RV32_LH, `RV32_LW,
                `RV32_LBU, `RV32_LHU: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    rd_mem          = `TRUE;
                    rs1_instruction = 1;
                    func_unit       = FUNC_MEM;
                end
                `RV32_SB, `RV32_SH, `RV32_SW: begin
                    dest_reg_valid   = 0;
                    opb_select      = OPB_IS_S_IMM;
                    wr_mem          = `TRUE;
                    rs1_instruction = 1;
                    func_unit       = FUNC_MEM;
                end
                `RV32_ADDI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    rs1_instruction = 1;
                end
                `RV32_SLTI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_SLT;
                    rs1_instruction = 1;
                end
                `RV32_SLTIU: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_SLTU;
                    rs1_instruction = 1;
                end
                `RV32_ANDI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_AND;
                    rs1_instruction = 1;
                end
                `RV32_ORI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_OR;
                    rs1_instruction = 1;
                end
                `RV32_XORI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_XOR;
                    rs1_instruction = 1;
                end
                `RV32_SLLI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_SLL;
                    rs1_instruction = 1;
                end
                `RV32_SRLI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_SRL;
                    rs1_instruction = 1;
                end
                `RV32_SRAI: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    opb_select      = OPB_IS_I_IMM;
                    alu_func        = ALU_SRA;
                    rs1_instruction = 1;
                end
                `RV32_ADD: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SUB: begin
                    // dest_reg_idx = inst.r.rd
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SUB;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SLT: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SLT;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SLTU: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SLTU;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_AND: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_AND;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_OR: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_OR;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_XOR: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_XOR;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SLL: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SLL;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SRL: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SRL;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_SRA: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_SRA;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                end
                `RV32_MUL: begin
                    dest_reg_idx    = inst.r.rd;
                    alu_func        = ALU_MUL;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                    func_unit       = FUNC_MUL;
                end
                `RV32_MULH: begin
                    dest_reg_idx = inst.r.rd;
                    alu_func     = ALU_MULH;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                    func_unit       = FUNC_MUL;
                end
                `RV32_MULHSU: begin
                    dest_reg_idx = inst.r.rd;
                    alu_func     = ALU_MULHSU;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                    func_unit       = FUNC_MUL;
                end
                `RV32_MULHU: begin
                    dest_reg_idx = inst.r.rd;
                    alu_func     = ALU_MULHU;
                    rs1_instruction = 1;
                    rs2_instruction = 1;
                    func_unit       = FUNC_MUL;
                end
                `RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
                    dest_reg_valid = 0;
                    csr_op = `TRUE;
                    rs1_instruction = 1;
                end
                `WFI: begin
                    halt = `TRUE;
                end
                default: begin
                    valid_out = `TRUE;
                end
        endcase // casez (inst)
        end // if (valid)
    end // always

endmodule // decoder

