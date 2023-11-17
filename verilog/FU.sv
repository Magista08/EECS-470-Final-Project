`ifndef __FU__
`define __FU__

`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

//ALU---------------------------------------------------------------------------
// From P3
module alu (
    input [`XLEN-1:0] opa,
    input [`XLEN-1:0] opb,
    ALU_FUNC          func,

    output logic [`XLEN-1:0] result
);

    logic signed [`XLEN-1:0]   signed_opa, signed_opb;
    // logic signed [2*`XLEN-1:0] signed_mul, mixed_mul;
    // logic        [2*`XLEN-1:0] unsigned_mul;

    assign signed_opa   = opa;
    assign signed_opb   = opb;
    // assign signed_mul   = signed_opa * signed_opb;
    // assign unsigned_mul = opa * opb;
    // assign mixed_mul    = signed_opa * opb;

    always_comb begin
        case (func)
            ALU_ADD:    result = opa + opb;
            ALU_SUB:    result = opa - opb;
            ALU_AND:    result = opa & opb;
            ALU_SLT:    result = signed_opa < signed_opb;
            ALU_SLTU:   result = opa < opb;
            ALU_OR:     result = opa | opb;
            ALU_XOR:    result = opa ^ opb;
            ALU_SRL:    result = opa >> opb[4:0];
            ALU_SLL:    result = opa << opb[4:0];
            ALU_SRA:    result = signed_opa >>> opb[4:0];
            // ALU_MUL:    result = signed_mul[`XLEN-1:0];
            // ALU_MULH:   result = signed_mul[2*`XLEN-1:`XLEN];
            // ALU_MULHSU: result = mixed_mul[2*`XLEN-1:`XLEN];
            // ALU_MULHU:  result = unsigned_mul[2*`XLEN-1:`XLEN];

            default:    result = `XLEN'hfacebeec;
        endcase
    end

endmodule 

// From P3
// Conditional branch module: compute whether to take conditional branches
// This module is purely combinational
module conditional_branch (
    input [2:0]       func, // Specifies which condition to check
    input [`XLEN-1:0] rs1,  // Value to check against condition
    input [`XLEN-1:0] rs2,

    output logic take // True/False condition result
);

    logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
    assign signed_rs1 = rs1;
    assign signed_rs2 = rs2;
    always_comb begin
        case (func)
            3'b000:  take = signed_rs1 == signed_rs2; // BEQ
            3'b001:  take = signed_rs1 != signed_rs2; // BNE
            3'b100:  take = signed_rs1 < signed_rs2;  // BLT
            3'b101:  take = signed_rs1 >= signed_rs2; // BGE
            3'b110:  take = rs1 < rs2;                // BLTU
            3'b111:  take = rs1 >= rs2;               // BGEU
            default: take = `FALSE;
        endcase
    end

endmodule // conditional_branch


module FU_ALU (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input RS_IS_PACKET                                    fu_input,

    output logic [`XLEN-1:0]                              NPC,
    output logic [$clog2(`ROBLEN)-1:0]                    tag,
    output logic [`XLEN-1:0]                              result,
    output logic                                          busy,
    output logic                                          result_ready,
    output logic                                          branch_taken
);

    logic [`XLEN-1:0]                                     opa_mux_out, opb_mux_out;
    logic [`XLEN-1:0]                                     next_result;
    logic                                                 take_conditional;
    logic                                                 next_result_ready;

    // ALU opA mux
    always_comb begin
        case (fu_input.opa_select)
            OPA_IS_RS1:  opa_mux_out = fu_input.rs1_value;
            OPA_IS_NPC:  opa_mux_out = fu_input.NPC;
            OPA_IS_PC:   opa_mux_out = fu_input.PC;
            OPA_IS_ZERO: opa_mux_out = 0;
            default:     opa_mux_out = `XLEN'hdeadface;
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (fu_input.opb_select)
            OPB_IS_RS2:   opb_mux_out = fu_input.rs2_value;
            OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(fu_input.inst);
            // OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(fu_input.inst);
            OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(fu_input.inst);
            OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(fu_input.inst);
            OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(fu_input.inst);
            default:      opb_mux_out = `XLEN'hfacefeed;
        endcase
    end
  
    assign NPC = fu_input.NPC;
    assign tag = fu_input.T;  
    assign busy = (fu_input.inst!=`NOP) & (~result_ready);
    // assign busy = 0; // I think ALU can never be busy...
    assign branch_taken = fu_input.uncond_branch || (fu_input.cond_branch && take_conditional);
    assign next_result_ready = (fu_input.inst != `NOP);

    // Instantiate the ALU
    alu alu_0 (
        // Inputs
        .opa(opa_mux_out),
        .opb(opb_mux_out),
        .func(fu_input.alu_func),

        // Output
        .result(next_result)
    );

    // Instantiate the conditional branch module
    conditional_branch conditional_branch_0 (
        // Inputs
        .func(fu_input.inst.b.funct3), // instruction bits for which condition to check
        .rs1(fu_input.rs1_value),
        .rs2(fu_input.rs2_value),

        // Output
        .take(take_conditional)
    );
    
    always_ff @(posedge clock) begin
        if(reset || clear) begin
            result <= {`XLEN{1'b0}};
            result_ready <= 0;
        end else begin
            result <= next_result;
            // result_ready <= fu_input.can_execute;
            result_ready <= next_result_ready;
        end
    end

endmodule


//MULT--------------------------------------------------------------------------
// From P2
module mult_stage (
    input clock, reset, start,
    input [63:0] prev_sum, mplier, mcand,

    output logic [63:0] product_sum, next_mplier, next_mcand,
    output logic done
);

    parameter SHIFT = 64/`MULT_STAGES;

    logic [63:0] partial_product, shifted_mplier, shifted_mcand;

    assign partial_product = mplier[SHIFT-1:0] * mcand;

    assign shifted_mplier = {SHIFT'('b0), mplier[63:SHIFT]};
    assign shifted_mcand = {mcand[63-SHIFT:0], SHIFT'('b0)};

    always_ff @(posedge clock) begin
        product_sum <= prev_sum + partial_product;
        next_mplier <= shifted_mplier;
        next_mcand  <= shifted_mcand;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            done <= 1'b0;
        end else begin
            done <= start;
        end
    end

endmodule

// From P2
module mult (
    input clock, reset,
    input [63:0] mcand, mplier, // Notice here is 64 bit
    input start,

    output logic [63:0] product,
    output logic done
);

    logic [`MULT_STAGES-2:0] internal_dones;
    logic [(64*(`MULT_STAGES-1))-1:0] internal_product_sums, internal_mcands, internal_mpliers;
    logic [63:0] mcand_out, mplier_out; // unused, just for wiring

    // instantiate an array of mult_stage modules
    // this uses concatenation syntax for internal wiring, see lab 2 slides
    mult_stage mstage [`MULT_STAGES-1:0] (
        .clock (clock),
        .reset (reset),
        .start       ({internal_dones,        start}), // forward prev done as next start
        .prev_sum    ({internal_product_sums, 64'h0}), // start the sum at 0
        .mplier      ({internal_mpliers,      mplier}),
        .mcand       ({internal_mcands,       mcand}),
        .product_sum ({product,    internal_product_sums}),
        .next_mplier ({mplier_out, internal_mpliers}),
        .next_mcand  ({mcand_out,  internal_mcands}),
        .done        ({done,       internal_dones}) // done when the final stage is done
    );

endmodule


module FU_MULT (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input RS_IS_PACKET                                    fu_input,

    output logic [`XLEN-1:0]                              NPC,
    output logic [$clog2(`ROBLEN)-1:0]                    tag,
    output logic [`XLEN-1:0]                              result,
    output logic                                          busy,
    output logic                                          result_ready
    
    // debug
    // output logic                                          high_1_low_0
);

    logic [2*`XLEN-1:0] 	   mcand, mplier, product;
    logic signed [`XLEN-1:0]   signed_opa, signed_opb;
    logic                      high_1_low_0;

    assign signed_opa = fu_input.rs1_value; // add sign
    assign signed_opb = fu_input.rs2_value; // add sign

	always_comb begin
		case (fu_input.alu_func)
			ALU_MUL:    begin 
						mcand = signed_opa; // add high 0 here
						mplier = signed_opb;
                        high_1_low_0 = 0;
			end
			ALU_MULH:	begin
						mcand = signed_opa;
						mplier = signed_opb;
                        high_1_low_0 = 1;
			end
			ALU_MULHSU: begin  
						mcand = signed_opa;
						mplier = fu_input.rs2_value;
                        high_1_low_0 = 1;
			end
			ALU_MULHU:  begin  
						mcand = fu_input.rs1_value;
						mplier = fu_input.rs2_value;
                        high_1_low_0 = 1;
			end
			default:    begin
						mcand = 0;
						mplier = 0;
                        high_1_low_0 = 0;
			end
		endcase
	end

    assign busy = (fu_input.inst!=`NOP) & (~result_ready);
    assign tag = fu_input.T;
    assign NPC = fu_input.NPC;

	mult mult_0(
		.clock(clock),
		.reset(reset | clear),
		.mcand(mcand),
		.mplier(mplier),
		// .start(fu_input.can_execute), // need to consider what this is
        // .start(~fu_input.illegal),
        .start((fu_input.inst != `NOP)),

		.product(product),
		.done(result_ready)
	);

    assign result = high_1_low_0 ? product[2*`XLEN-1:`XLEN] : product[`XLEN-1:0];

endmodule


module high_1_low_0_buffer (
    input                                                 clock,
    input                                                 reset,
    input                                                 clear,
    input                                                 high_1_low_0,

    output logic                                          now1_0

);
endmodule


//LOAD--------------------------------------------------------------------------




//STORE-------------------------------------------------------------------------

`endif
