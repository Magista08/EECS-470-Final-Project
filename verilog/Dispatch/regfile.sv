/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "../sys_defs.svh"

// P4 TODO: update this with the new parameters from sys_defs
// module regfile (
//     input             clock, // system clock
//     // note: no system reset, register values must be written before they can be read
//     input [`N-1:0] [4:0]              read_idx_1, read_idx_2,
//     input RT_PACKET [`N-1:0] rt_packets,

//     output logic [`N-1] [`XLEN-1:0] read_out_1,
//     output logic [`N-1] [`XLEN-1:0] read_out_2
// );
//     logic [31:1] [`XLEN-1:0] registers;
    
//     logic read_reg_need_1, read_reg_need_2;


//     // Read port 1
//     always_comb begin
//         read_reg_need_1 = 1'b1;
//         read_out_1 = 0;
//         for (int i=0; i<`N; i++) begin
//             if (rt_packets[i].wr_en && rt_packets[i].dest_reg_idx == read_idx_1) begin
//                 read_out_1 = rt_packets[i].value;
//                 read_reg_need_1 = 1'b0;
//                 break;
//             end
//         end
//         if (read_reg_need_1 && read_idx_1 != `ZERO_REG) begin
//             read_out_1 = registers[count][read_idx_1];
//             $display("regfile[%d]: read %d from register %d", count, registers[count][2], read_idx_1);
//         end

        
//     end

//     // Read port 2
//     always_comb begin
//         read_reg_need_2 = 1'b1;
//         read_out_2 = 0;
//         for (int i=0; i<`N; i++) begin
//             if (rt_packets[i].wr_en && rt_packets[i].dest_reg_idx == read_idx_2) begin
//                 read_out_2 = rt_packets[i].value;
//                 read_reg_need_2 = 1'b0;
//                 // $display("regfile[%d]: read %d from register %d", count, read_out_1, read_idx_1);
//                 break;
//             end
//         end
//         if (read_reg_need_2 && read_idx_2 != `ZERO_REG) begin
//             read_out_2 = registers[count][read_idx_2];
//             $display("regfile[%d]: read %d from register %d", count, registers[count][2], read_idx_2);
//         end
//     end

//     // Write port
//     always_ff @(posedge clock) begin
//         if (write_en && write_idx != `ZERO_REG) begin
//             registers[0][write_idx] <= write_data;
//             $display("regfile: write %d to register %d", registers[0][write_idx], write_idx);
//         end
//     end

// endmodule // regfile


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

    // Write to RegFile
    always_ff @(posedge clock) begin
        for (int i = 0; i < `N; i++) begin
            if (write_en[i] && write_idx[i] != `ZERO_REG) begin
                registers[write_idx[i]] <= write_data[i];
            end
        end
    end
endmodule