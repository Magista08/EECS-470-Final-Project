/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline_test.sv                                    //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"

// P4 TODO: Add your own debugging framework. Basic printing of data structures
//          is an absolute necessity for the project. You can use C functions
//          like in test/pipeline_print.c or just do everything in verilog.
//          Be careful about running out of space on CAEN printing lots of state
//          for longer programs (alexnet, outer_product, etc.)


// these link to the pipeline_print.c file in this directory, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
import "DPI-C" function void open_pipeline_output_file(string file_name);
import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                        int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                           int proc2mem_addr_hi, int proc2mem_addr_lo,
                                           int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();


module testbench;
    // used to parameterize which files are used for memory and writeback/pipeline outputs
    // "./simv" uses program.mem, writeback.out, and pipeline.out
    // but now "./simv +MEMORY=<my_program>.mem" loads <my_program>.mem instead
    // use +WRITEBACK=<my_program>.wb and +PIPELINE=<my_program>.ppln for those outputs as well
    string program_memory_file;
    string writeback_output_file;
    // string pipeline_output_file;

    // variables used in the testbench
    logic        clock;
    logic        reset;
    logic [31:0] clock_count;
    logic [31:0] instr_count;
    int          wb_fileno;
    logic [63:0] debug_counter; // counter used for infinite loops, forces termination

    logic [1:0]       proc2mem_command;
    logic [`XLEN-1:0] proc2mem_addr;
    logic [63:0]      proc2mem_data;
    logic [3:0]       mem2proc_response;
    logic [63:0]      mem2proc_data;
    logic [3:0]       mem2proc_tag;
`ifndef CACHE_MODE
    MEM_SIZE          proc2mem_size;
`endif

    logic [2:0][3:0]       pipeline_completed_insts;
    EXCEPTION_CODE    pipeline_error_status;
    logic [2:0][4:0]       pipeline_commit_wr_idx;
    logic [2:0][`XLEN-1:0] pipeline_commit_wr_data;
    logic [2:0]            pipeline_commit_wr_en;
    logic [2:0][`XLEN-1:0] pipeline_commit_NPC;

    logic [2:0] [`XLEN-1:0] if_NPC_dbg;
    logic [2:0] [31:0]      if_inst_dbg;
    logic [2:0]            if_valid_dbg;
    logic [2:0] [`XLEN-1:0] is_NPC_dbg;
    logic [2:0] [31:0]      is_inst_dbg;
    logic [2:0]            is_valid_dbg;
    logic [2:0] [`XLEN-1:0] cdb_NPC_dbg;
    logic [2:0]            cdb_valid_dbg;
    logic [2:0] [`XLEN-1:0] rt_NPC_dbg;
    logic [2:0]            rt_valid_dbg;


    // Instantiate the Pipeline
    pipeline core (
        // Inputs
        .clock             (clock),
        .reset             (reset),
        .mem2proc_response (mem2proc_response),
        .mem2proc_data     (mem2proc_data),
        .mem2proc_tag      (mem2proc_tag),

        // Outputs
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
        .proc2mem_size    (proc2mem_size),

        .pipeline_completed_insts (pipeline_completed_insts),
        .pipeline_error_status    (pipeline_error_status),
        .pipeline_commit_wr_data  (pipeline_commit_wr_data),
        .pipeline_commit_wr_idx   (pipeline_commit_wr_idx),
        .pipeline_commit_wr_en    (pipeline_commit_wr_en),
        .pipeline_commit_NPC      (pipeline_commit_NPC),

        .if_NPC_dbg       (if_NPC_dbg),
        .if_inst_dbg      (if_inst_dbg),
        .if_valid_dbg     (if_valid_dbg),
        .is_NPC_dbg    (is_NPC_dbg),
        .is_inst_dbg   (is_inst_dbg),
        .is_valid_dbg  (is_valid_dbg),
        .cdb_NPC_dbg    (cdb_NPC_dbg),
        .cdb_valid_dbg  (cdb_valid_dbg),
        .rt_NPC_dbg   (rt_NPC_dbg),
        .rt_valid_dbg (rt_valid_dbg)
    );


    // Instantiate the Data Memory
    mem memory (
        // Inputs
        .clk              (clock),
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif

        // Outputs
        .mem2proc_response (mem2proc_response),
        .mem2proc_data     (mem2proc_data),
        .mem2proc_tag      (mem2proc_tag)
    );


    // Generate System Clock
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    // Task to display # of elapsed clock edges
    task show_clk_count;
        real cpi;
        begin
            cpi = (clock_count + 1.0) / instr_count;
            $display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
                      clock_count+1, instr_count, cpi);
            $display("@@  %4.2f ns total time to execute\n@@\n",
                      clock_count * `CLOCK_PERIOD);
        end
    endtask // task show_clk_count


    // Show contents of a range of Unified Memory, in both hex and decimal
    task show_mem_with_decimal;
        input [31:0] start_addr;
        input [31:0] end_addr;
        int showing_data;
        begin
            $display("@@@");
            showing_data=0;
            for(int k=start_addr;k<=end_addr; k=k+1)
                if (memory.unified_memory[k] != 0) begin
                    $display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
                                                             memory.unified_memory[k]);
                    showing_data=1;
                end else if(showing_data!=0) begin
                    $display("@@@");
                    showing_data=0;
                end
            $display("@@@");
        end
    endtask // task show_mem_with_decimal


    initial begin
        //$dumpvars;

        // P4 NOTE: You must keep memory loading here the same for the autograder
        //          Other things can be tampered with somewhat
        //          Definitely feel free to add new output files

        // set paramterized strings, see comment at start of module
        if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
            $display("Loading memory file: %s", program_memory_file);
        end else begin
            $display("Loading default memory file: program.mem");
            program_memory_file = "program.mem";
        end
        if ($value$plusargs("WRITEBACK=%s", writeback_output_file)) begin
            $display("Using writeback output file: %s", writeback_output_file);
        end else begin
            $display("Using default writeback output file: writeback.out");
            writeback_output_file = "writeback.out";
        end
        // if ($value$plusargs("PIPELINE=%s", pipeline_output_file)) begin
        //     $display("Using pipeline output file: %s", pipeline_output_file);
        // end else begin
        //     $display("Using default pipeline output file: pipeline.out");
        //     pipeline_output_file = "pipeline.out";
        // end

        clock = 1'b0;
        reset = 1'b0;

        // Pulse the reset signal
        $display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        // store the compiled program's hex data into memory
        $readmemh(program_memory_file, memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        #1;
        // This reset is at an odd time to avoid the pos & neg clock edges

        reset = 1'b0;
        $display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

        wb_fileno = $fopen(writeback_output_file);

        // Open the pipeline output file after throwing reset
        // open_pipeline_output_file(pipeline_output_file);
        // print_header("removed for line length");
    end


    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock) begin
        if(reset) begin
            clock_count <= 0;
            instr_count <= 0;
        end else begin
            clock_count <= (clock_count + 1);
            instr_count <= (instr_count + pipeline_completed_insts);
        end
    end


    always @(negedge clock) begin
        if(reset) begin
            $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
                     $realtime);
            debug_counter <= 0;
        end else begin
            #2;

            print_cycles();
/*
            print_stage(" ", if_inst_dbg,     if_NPC_dbg    [31:0], {31'b0,if_valid_dbg});
            print_stage("|", is_inst_dbg,  is_NPC_dbg [31:0], {31'b0,is_valid_dbg});
            print_stage("|", `NOP, cdb_NPC_dbg [31:0], {31'b0,cdb_valid_dbg});
            print_stage("|", `NOP, rt_NPC_dbg[31:0], {31'b0,rt_valid_dbg});
*/
            print_reg(32'b0, pipeline_commit_wr_data[0][31:0],
                 {27'b0,pipeline_commit_wr_idx[0]}, {31'b0,pipeline_commit_wr_en[0]});
	    print_reg(32'b0, pipeline_commit_wr_data[1][31:0],
                 {27'b0,pipeline_commit_wr_idx[1]}, {31'b0,pipeline_commit_wr_en[1]});
	    print_reg(32'b0, pipeline_commit_wr_data[2][31:0],
                 {27'b0,pipeline_commit_wr_idx[2]}, {31'b0,pipeline_commit_wr_en[2]});
            print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
                 32'b0, proc2mem_addr[31:0],
                 proc2mem_data[63:32], proc2mem_data[31:0]);

            // print register write information to the writeback output file
            if (pipeline_completed_insts > 0) begin
                if(pipeline_commit_wr_en)
                    $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                              pipeline_commit_NPC - 4,
                              pipeline_commit_wr_idx,
                              pipeline_commit_wr_data);
                else
                    $fdisplay(wb_fileno, "PC=%x, ---", pipeline_commit_NPC - 4);
            end

            // deal with any halting conditions
            if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
                $display("@@@ Unified Memory contents hex on left, decimal on right: ");
                show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
                // 8Bytes per line, 16kB total

                $display("@@  %t : System halted\n@@", $realtime);

                case(pipeline_error_status)
                    LOAD_ACCESS_FAULT:
                        $display("@@@ System halted on memory error");
                    HALTED_ON_WFI:
                        $display("@@@ System halted on WFI instruction");
                    ILLEGAL_INST:
                        $display("@@@ System halted on illegal instruction");
                    default:
                        $display("@@@ System halted on unknown error code %x",
                            pipeline_error_status);
                endcase
                $display("@@@\n@@");
                show_clk_count;
                // print_close(); // close the pipe_print output file
                $fclose(wb_fileno);
                #100 $finish;
            end
            debug_counter <= debug_counter + 1;
        end // if(reset)
    end
/*
    always @(posedge clock) begin
        $display("-----------------------");
	$display("if_NPC[0]:%h if_inst[0]:%h if_valid[0]:%b || if_NPC[1]:%h if_inst[1]:%h if_valid[1]:%b || if_NPC[2]:%h if_inst[2]:%h if_valid[2]:%b",
		 if_NPC_dbg[0], if_inst_dbg[0], if_valid_dbg[0], if_NPC_dbg[1], if_inst_dbg[1], if_valid_dbg[1], if_NPC_dbg[2], if_inst_dbg[2], if_valid_dbg[2]);
	$display("is_NPC[0]:%h is_inst[0]:%h is_valid[0]:%b || is_NPC[1]:%h is_inst[1]:%h is_valid[1]:%b || is_NPC[2]:%h is_inst[2]:%h is_valid[2]:%b", 
		is_NPC_dbg[0], is_inst_dbg[0], is_valid_dbg[0], is_NPC_dbg[1], is_inst_dbg[1], is_valid_dbg[1], is_NPC_dbg[2], is_inst_dbg[2], is_valid_dbg[2]);
	$display("cdb_NPC[0]:%h cdb_valid[0]:%b || cdb_NPC[1]:%h cdb_valid[1]:%b || cdb_NPC[2]:%h cdb_valid[2]:%b", 
		cdb_NPC_dbg[0], cdb_valid_dbg[0], cdb_NPC_dbg[1], cdb_valid_dbg[1], cdb_NPC_dbg[2], cdb_valid_dbg[2]);
	$display("rt_NPC[0]:%h rt_valid[0]:%b || rt_NPC[1]:%h rt_valid[1]:%b || rt_NPC[2]:%h rt_valid[2]:%b", 
		rt_NPC_dbg[0], rt_valid_dbg[0], rt_NPC_dbg[1], rt_valid_dbg[1], rt_NPC_dbg[2], rt_valid_dbg[2]);
	$display("wr_idx[0]:%h wr_data[0]:%h wr_en[0]:%b || wr_idx[1]:%h wr_data[1]:%h wr_en[1]:%b || wr_idx[2]:%h wr_data[2]:%h wr_en[2]:%b", 
		pipeline_commit_wr_idx[0], pipeline_commit_wr_data[0], pipeline_commit_wr_en[0], 
		pipeline_commit_wr_idx[1], pipeline_commit_wr_data[1], pipeline_commit_wr_en[1],
		pipeline_commit_wr_idx[2], pipeline_commit_wr_data[2], pipeline_commit_wr_en[2]); 
    end
*/
/*
    always @(posedge clock) begin
        $display("-----------------------");
	$display("if_NPC[0]:%h if_inst[0]:%h if_valid[0]:%b", if_NPC_dbg[0], if_inst_dbg[0], if_valid_dbg[0]);
	$display("if_NPC[1]:%h if_inst[1]:%h if_valid[1]:%b", if_NPC_dbg[1], if_inst_dbg[1], if_valid_dbg[1]);
	$display("if_NPC[2]:%h if_inst[2]:%h if_valid[2]:%b", if_NPC_dbg[2], if_inst_dbg[2], if_valid_dbg[2]);
	$display("is_NPC[0]:%h is_inst[0]:%h is_valid[0]:%b", is_NPC_dbg[0], is_inst_dbg[0], is_valid_dbg[0]);
	$display("is_NPC[1]:%h is_inst[1]:%h is_valid[1]:%b", is_NPC_dbg[1], is_inst_dbg[1], is_valid_dbg[1]);
	$display("is_NPC[2]:%h is_inst[2]:%h is_valid[2]:%b", is_NPC_dbg[2], is_inst_dbg[2], is_valid_dbg[2]);
	$display("cdb_NPC[0]:%h cdb_valid[0]:%b", cdb_NPC_dbg[0], cdb_valid_dbg[0]);
	$display("cdb_NPC[1]:%h cdb_valid[1]:%b", cdb_NPC_dbg[1], cdb_valid_dbg[1]);
	$display("cdb_NPC[2]:%h cdb_valid[2]:%b", cdb_NPC_dbg[2], cdb_valid_dbg[2]);
	$display("rt_NPC[0]:%h rt_valid[0]:%b", rt_NPC_dbg[0], rt_valid_dbg[0]);
	$display("rt_NPC[1]:%h rt_valid[1]:%b", rt_NPC_dbg[1], rt_valid_dbg[1]);
	$display("rt_NPC[2]:%h rt_valid[2]:%b", rt_NPC_dbg[2], rt_valid_dbg[2]);
	$display("wr_idx[0]:%h wr_data[0]:%h wr_en[0]:%b", pipeline_commit_wr_idx[0], pipeline_commit_wr_data[0], pipeline_commit_wr_en[0]); 
	$display("wr_idx[1]:%h wr_data[1]:%h wr_en[1]:%b", pipeline_commit_wr_idx[1], pipeline_commit_wr_data[1], pipeline_commit_wr_en[1]); 
	$display("wr_idx[2]:%h wr_data[2]:%h wr_en[2]:%b", pipeline_commit_wr_idx[2], pipeline_commit_wr_data[2], pipeline_commit_wr_en[2]); 
    end
*/

    /*$monitor("-----------------------\ntime:%4.0f  clock:%b\nif_NPC:%h if_inst:%h if_valid:%b\nis_NPC:%h is_inst:%h is_valid:%b\ncdb_NPC:%h cdb_valid:%b\nrt_NPC:%h rt_valid:%b\nwr_idx[0]:%h wr_data[0]:%h wr_en[0]:%b\nwr_idx[1]:%h wr_data[1]:%h wr_en[1]:%b\nwr_idx[2]:%h wr_data[2]:%h wr_en[2]:%b\n",$time, clock, if_NPC_dbg, if_inst_dbg, if_valid_dbg, is_NPC_dbg, is_inst_dbg, is_valid_dbg, cdb_NPC_dbg, cdb_valid_dbg, rt_NPC_dbg, rt_valid_dbg, pipeline_commit_wr_idx[0], pipeline_commit_wr_data[0], pipeline_commit_wr_en[0], pipeline_commit_wr_idx[1], pipeline_commit_wr_data[1], pipeline_commit_wr_en[1], pipeline_commit_wr_idx[2], pipeline_commit_wr_data[2], pipeline_commit_wr_en[2]);*/

endmodule // testbench
