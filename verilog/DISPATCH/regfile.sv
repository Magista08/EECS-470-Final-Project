/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"

module regfile(
    // Input
    input logic clock,
    // Read
    input logic [`N-1:0] [4:0] read_idx_1, read_idx_2,
    // Write
    input logic [`N-1:0]             write_en,
    input logic [`N-1:0] [4:0]       write_idx,
    input logic [`N-1:0] [`XLEN-1:0] write_data,

    // Output
    output logic [`N-1:0] [`XLEN-1:0] read_out_1,
    output logic [`N-1:0] [`XLEN-1:0] read_out_2
);
    logic [31:1] [`XLEN-1:0] registers;

    logic read_reg_need_1, read_reg_need_2;

    // Read port 1
    always_comb begin
        for (int i=0; i<`N; i++) begin
            read_out_1[i] = {`XLEN{1'b0}};
            read_reg_need_1 = 1'b1;
            
            // Directly read from write port
            for (int j = 0; j <`N; j++) begin    
                if (write_en[j] && write_idx[j] == read_idx_1[i]) begin
                    read_out_1[i] = write_data[j];
                    read_reg_need_1 = 1'b0;
                    break;
                end
            end

            // Read from register
            if (read_reg_need_1 && read_idx_1[i] != `ZERO_REG) begin
                read_out_1[i] = registers[read_idx_1[i]];
            end
        end
    end

    // Read port 2
    always_comb begin
        for (int i=0; i<`N; i++) begin
            read_out_2[i] = {`XLEN{1'b0}};
            read_reg_need_2 = 1'b1;
            
            // Directly read from write port
            for (int j = 0; j <`N; j++) begin    
                if (write_en[j] && write_idx[j] == read_idx_2[i]) begin
                    read_out_2[i] = write_data[j];
                    read_reg_need_2 = 1'b0;
                    break;
                end
            end

            // Read from register
            if (read_reg_need_2 && read_idx_2[i] != `ZERO_REG) begin
                read_out_2[i] = registers[read_idx_2[i]];
            end
        end
    end

    logic [`N-1:0] write_idx_same;
    assign write_idx_same[2] = write_en[2];
    assign write_idx_same[1] = write_en[1] && ~(write_en[2] && (write_idx[1] == write_idx[2]));
    assign write_idx_same[0] = write_en[0] && ~(write_en[1] && (write_idx[0] == write_idx[1])) && ~(write_en[2] && (write_idx[0] == write_idx[2]));
    // Write to RegFile
    always_ff @(posedge clock) begin
        for (int i = 0; i < `N; i++) begin
            if (write_idx[i] != `ZERO_REG && write_idx_same[i]) begin
                registers[write_idx[i]] <= write_data[i];
            end
        end
    end
endmodule
