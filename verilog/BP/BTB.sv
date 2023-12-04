`include "verilog/sys_defs.svh"
`include "verilog/ISA.svh"

module BTB #(
    parameter BTB_INDEX = $clog2(`BTBSIZE)
) (
    input  clock, reset,
    input  [2:0] wr_en,                 // write enable signal from exe.stage
    input  [2:0] [`XLEN-1:0] ex_pc,     // pc from ex stage 
    input  [2:0] [`XLEN-1:0] ex_tp,     // target pc from ex stage in 
    input  [2:0] [`XLEN-1:0] if_pc,     // pc from if stage    
    output logic [2:0] hit,             // 1 if the prediction is correct
    output logic [2:0][`XLEN-1:0] predict_pc_out
);
    logic [`TAGSIZE + `VALSIZE - 1 : 0 ] mem [`BTBSIZE - 1 : 0 ];
    logic [`BTBSIZE - 1 : 0 ] valid;    // 1 if mem stores a valid PC
   

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0;i<`BTBSIZE;i++) begin
            mem [i] <=  0;
            end
            valid <=  0;
        end
        else begin
            // if two pc return from ex stage is same, BTB will record the ex_tg_pc_in[0]
            if (wr_en[0] && wr_en[1] && wr_en[2] &&
            (ex_pc[0][2 +: BTB_INDEX] == ex_pc[1][2 +: BTB_INDEX] && ex_pc[0][2 +: BTB_INDEX] == ex_pc[2][2 +: BTB_INDEX])) begin
                mem [ex_pc[0][2 +: BTB_INDEX]] <= 
                {ex_pc[0][BTB_INDEX+2 +: `TAGSIZE], ex_tp[0][2 +: `VALSIZE]};
                valid[ex_pc[0][2 +: BTB_INDEX]] <=  1'b1;
            end else if(wr_en[0] && wr_en[1] && ex_pc[0][2 +: BTB_INDEX] == ex_pc[1][2 +: BTB_INDEX]) begin
                mem [ex_pc[0][2 +: BTB_INDEX]] <= 
                {ex_pc[0][BTB_INDEX+2 +: `TAGSIZE], ex_tp[0][2 +: `VALSIZE]};
                valid[ex_pc[0][2 +: BTB_INDEX]] <=  1'b1;
            end else if(wr_en[0] && wr_en[2] && ex_pc[0][2 +: BTB_INDEX] == ex_pc[2][2 +: BTB_INDEX]) begin
                mem [ex_pc[0][2 +: BTB_INDEX]] <= 
                {ex_pc[0][BTB_INDEX+2 +: `TAGSIZE], ex_tp[0][2 +: `VALSIZE]};
                valid[ex_pc[0][2 +: BTB_INDEX]] <=  1'b1;
            end else if(wr_en[1] && wr_en[2] && ex_pc[1][2 +: BTB_INDEX] == ex_pc[2][2 +: BTB_INDEX]) begin
                mem [ex_pc[1][2 +: BTB_INDEX]] <= 
                {ex_pc[1][BTB_INDEX+2 +: `TAGSIZE], ex_tp[1][2 +: `VALSIZE]};
                valid[ex_pc[1][2 +: BTB_INDEX]] <=  1'b1;
            end else begin
                if (wr_en[0]) begin
                    mem [ex_pc[0][2 +: BTB_INDEX]] <=  
                    {ex_pc[0][BTB_INDEX+2 +: `TAGSIZE],
                    ex_tp[0][2 +: `VALSIZE]};
                    valid[ex_pc[0][2 +: BTB_INDEX]] <=  1'b1;
                end 
                if (wr_en[1]) begin
                    mem [ex_pc[1][2 +: BTB_INDEX]] <=  
                    {ex_pc[1][BTB_INDEX+2 +: `TAGSIZE],
                    ex_tp[1][2 +: `VALSIZE]};
                    valid[ex_pc[1][2 +: BTB_INDEX]] <=  1'b1;
                end
                if (wr_en[2]) begin
                    mem [ex_pc[2][2 +: BTB_INDEX]] <=  
                    {ex_pc[2][BTB_INDEX+2 +: `TAGSIZE],
                    ex_tp[2][2 +: `VALSIZE]};
                    valid[ex_pc[2][2 +: BTB_INDEX]] <=  1'b1;
                end  
            end
        end
    end

    genvar j,k;
    for (j=0;j<3;j++) begin
    assign   predict_pc_out[j] = 
            {if_pc[j][`XLEN-1:`VALSIZE+2],
            mem[if_pc[j][BTB_INDEX+1 -: BTB_INDEX]][`VALSIZE-1:0],
            {2{1'b0}}};    
    end



    for (k=0;k<3;k++) begin
    assign  hit[k] = 
            (if_pc[k][BTB_INDEX+2 +: `TAGSIZE] == 
            mem[if_pc[k][BTB_INDEX+1-:BTB_INDEX]][`VALSIZE +: `TAGSIZE])&
            valid[if_pc[k][BTB_INDEX+1 -: BTB_INDEX]];
    end

endmodule