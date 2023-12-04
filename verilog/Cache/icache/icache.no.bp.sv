
`include "verilog/sys_defs.svh"

// Internal macros, no other file should need these
`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

typedef struct packed {
    logic [63:0]                  data;
    // (13 bits) since only need 16 bits to access all memory and 3 are the offset
    logic [12-`CACHE_LINE_BITS:0] tags;
    logic                         valid;
} ICACHE_ENTRY;


module icache (
    input clock,
    input reset,
	// From Dcache
	input Dcache_on_bus,
    // From memory
    input [3:0]  Imem2proc_response, // Should be zero unless there is a response
    input [63:0] Imem2proc_data,
    input [3:0]  Imem2proc_tag,

    // From fetch stage
    input [`XLEN-1:0] proc2Icache_addr,

    // To memory
    output logic [1:0]       proc2Imem_command,
    output logic [`XLEN-1:0] proc2Imem_addr,

    // To fetch stage
    output logic [63:0] Icache_data_out, // Data is mem[proc2Icache_addr]
    output logic        Icache_valid_out // When valid is high
);

    // ---- Cache data ---- //

    ICACHE_ENTRY [`CACHE_LINES-1:0] icache_data;

    // ---- Addresses and final outputs ---- //

    // Note: cache tags, not memory tags
    logic [12-`CACHE_LINE_BITS:0] current_tag, last_tag;
    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;

    assign {current_tag, current_index} = proc2Icache_addr[15:3];

    assign Icache_data_out = icache_data[current_index].data;
    assign Icache_valid_out = icache_data[current_index].valid &&
                              (icache_data[current_index].tags == current_tag);


    logic [3:0] current_mem_tag;
    logic miss_outstanding;

    wire got_mem_data = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);

    wire changed_addr = (current_index != last_index) || (current_tag != last_tag);

    wire update_mem_tag = changed_addr || miss_outstanding || got_mem_data;

    wire unanswered_miss = changed_addr ? !Icache_valid_out
                                        : miss_outstanding && (Imem2proc_response == 0);

    assign proc2Imem_command = (miss_outstanding && !changed_addr && Dcache_on_bus) ? BUS_LOAD : BUS_NONE;
    assign proc2Imem_addr    = {proc2Icache_addr[31:3],3'b0};


    always_ff @(posedge clock) begin
        if (reset) begin
            last_index       <= -1; // These are -1 to get ball rolling when
            last_tag         <= -1; // reset goes low because addr "changes"
            current_mem_tag  <= 0;
            miss_outstanding <= 0;
            icache_data      <= 0; // Set all cache data to 0 (including valid bits)
        end else begin
            last_index       <= current_index;
            last_tag         <= current_tag;
            miss_outstanding <= unanswered_miss;
            if (update_mem_tag) begin
                current_mem_tag <= Imem2proc_response;
            end
            if (got_mem_data) begin // If data came from memory, meaning tag matches
                icache_data[current_index].data  <= Imem2proc_data;
                icache_data[current_index].tags  <= current_tag;
                icache_data[current_index].valid <= 1;
				
            end
        end
    end

endmodule // icache

//////////////////////////////////////
//                                  //
//      icache without prefatch     //
//                                  //
//////////////////////////////////////

module icache_2way(
	input clock,
	input reset,
	
	//From mem
	input [3:0]         Imem2Icache_response,
	input [63:0]        Imem2Icache_data,
	input [3:0]         Imem2Icache_tag,
	
	//From Fetch
	input [2:0][`XLEN-1:0] proc2Icache_addr,
	//From Dcache
	input               Dcache_on_bus,
	// To mem
	output [1:0]         Icache2Imem_command,
	output [`XLEN-1:0]    Icache2Imem_addr,
	
	// To fetch
	//output [2:0][XLEN-1] Icache_inst,
	//output [2:0]         Icache_inst_valid
	output ICACHE_IF_PACKET [2:0] icache_if_packet_out
);

	
    //////////////////////////
	//                      //
	//	    Icache 0        //
	//                      //
	//////////////////////////
	logic   [3:0]    Imem2Icache0_response;
	logic [`XLEN-1:0] if2Icache0_addr;
	logic   [1:0]    Icache02Imem_command;
	logic [`XLEN-1:0] Icache02Imem_addr;
	ICACHE_PACKET Icache0_packet_out;
	/*
	logic [XLEN-1:0] Icache02mem_addr;
	logic            Icache0_valid_out;
	*/
	icache icache0(
	.clock(clock),
	.reset(reset),
	.Dcache_on_bus(Dcache_on_bus),
	.Imem2proc_response(Imem2Icache0_response),
	.Imem2proc_data(Imem2Icache_data),
	.Imem2proc_tag(Imem2Icache_tag),
	.proc2Icache_addr(if2Icache0_addr),
	
	.proc2Imem_command(Icache02Imem_command),
	.proc2Imem_addr(Icache02Imem_addr),
	
	.Icache_data_out(Icache0_packet_out.data),
	.Icache_valid_out(Icache0_packet_out.valid)
	);
	
	//////////////////////////
	//                      //
	//	    Icache 1        //
	//                      //
	//////////////////////////
	logic   [3:0]    Imem2Icache1_response;
	logic [`XLEN-1:0] if2Icache1_addr;
	logic   [1:0]    Icache12Imem_command;
	logic [`XLEN-1:0] Icache12Imem_addr;
	ICACHE_PACKET Icache1_packet_out;
	/*
	logic [XLEN-1:0] Icache02mem_addr;
	logic            Icache0_valid_out;
	*/
	icache icache1(
	.clock(clock),
	.reset(reset),
	.Imem2proc_response(Imem2Icache1_response),
	.Imem2proc_data(Imem2Icache_data),
	.Imem2proc_tag(Imem2Icache_tag),
	.proc2Icache_addr(if2Icache1_addr),
	.Dcache_on_bus(Dcache_on_bus),

	.proc2Imem_command(Icache12Imem_command),
	.proc2Imem_addr(Icache12Imem_addr),
	
	.Icache_data_out(Icache1_packet_out.data),
	.Icache_valid_out(Icache1_packet_out.valid)
	);


	//////////////////////////
	//                      //
	//    Icache control    //
	//                      //
	//////////////////////////
	logic cache0_use_bus;
	assign cache0_use_bus        = (Icache02Imem_command == BUS_LOAD)?  1 : 0;
	assign Imem2Icache0_response = cache0_use_bus ? Imem2Icache_response : 0;
	assign Imem2Icache1_response = ~cache0_use_bus? Imem2Icache_response : 0;
	assign Icache2Imem_command   = cache0_use_bus ? Icache02Imem_command : Icache12Imem_command;
	assign Icache2Imem_addr      = cache0_use_bus ? Icache02Imem_addr    : Icache12Imem_addr;
	assign if2Icache0_addr       = proc2Icache_addr[0];
	assign if2Icache1_addr       = proc2Icache_addr[2] ;
	
	always_comb begin
		if(reset) begin
			icache_if_packet_out = 0;
		end else begin
			case(proc2Icache_addr[0][2])
				1'b0: begin
					  {icache_if_packet_out[1].inst, icache_if_packet_out[0].inst} = Icache0_packet_out.data;
					   icache_if_packet_out[2].inst                                = Icache1_packet_out.data[31:0];
					   icache_if_packet_out[0].valid = Icache0_packet_out.valid;
					   icache_if_packet_out[1].valid = Icache0_packet_out.valid;
					   icache_if_packet_out[2].valid = Icache1_packet_out.valid;
					  end
				1'b1: begin
					  icache_if_packet_out [0].inst = Icache0_packet_out.data[63:32];
					  {icache_if_packet_out[2].inst, icache_if_packet_out[1].inst} = Icache1_packet_out.data;
					  icache_if_packet_out[0].valid = Icache0_packet_out.valid;
					  icache_if_packet_out[1].valid = Icache1_packet_out.valid;
					  icache_if_packet_out[2].valid = Icache1_packet_out.valid;
					  end
			endcase
		end
	end


endmodule
