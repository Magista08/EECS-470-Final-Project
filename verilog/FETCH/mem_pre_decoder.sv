`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module mem_pre_decoder(
    input INST inst, 
    input valid,

    output rd_mem,
    output wr_mem
);
     always_comb begin
        rd_mem = `FALSE;
        wr_mem = `FALSE;
        if (valid) begin
            casez (inst)
            `RV32_LB, `RV32_LH, `RV32_LW,
                `RV32_LBU, `RV32_LHU: begin
                    rd_mem = `TRUE;
                end
                `RV32_SB, `RV32_SH, `RV32_SW: begin
                    wr_mem = `TRUE;
                end
            endcase
        end
     end
endmodule