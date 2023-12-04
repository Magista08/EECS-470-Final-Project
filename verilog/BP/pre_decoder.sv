`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"


module pre_decoder(
    input INST inst,
    input if_valid,
    input [`XLEN-1:0] pc,

    // Outputs
    output logic cond_branch, uncond_branch,
    output logic jump, link,    // JAL is jump insn JALR is link insn
    output logic [`XLEN-1:0] result_out
);

    logic [`XLEN-1:0] opb_mux_out;
    always_comb begin
        cond_branch   = `FALSE;
        uncond_branch = `FALSE;
        jump    = `FALSE;
        link    = `FALSE;
        result_out  = {`XLEN{1'b0}};
        if (if_valid) begin
            casez (inst)
            `RV32_JAL: begin
                uncond_branch = `TRUE;
                jump    = `TRUE;

                // Pre-excute to get the result of the jump PC
                opb_mux_out = `RV32_signext_Jimm(inst);
                result_out = pc + opb_mux_out;
                //$display("pre_decoder: %h", result_out);
            end
            `RV32_JALR: begin
                uncond_branch = `TRUE;
                link   = `TRUE;
            end
            `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
            `RV32_BLTU, `RV32_BGEU: begin
                cond_branch = `TRUE;
            end
            endcase
        end
    end
endmodule