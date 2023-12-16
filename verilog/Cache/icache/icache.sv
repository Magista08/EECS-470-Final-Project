
`include "verilog/sys_defs.svh"

module icache_2way (
    input clock,
    input reset,
    input squash_flag,
	input [`XLEN-1:0] squash_pc,
    // From memory
    input [3:0]  Imem2proc_response, // Should be zero unless there is a response
    input [63:0] Imem2proc_data,
    input [3:0]  Imem2proc_tag,

    // From fetch stage
    input [`XLEN-1:0] proc2Icache_addr,

	// From Dcache
	input             Dcache_on_bus,


    // To memory
    output logic [1:0]       proc2Imem_command,
    output logic [`XLEN-1:0] proc2Imem_addr,

    // To fetch stage
    output ICACHE_IF_PACKET [2:0] icache_if_packet_out
);

    // ---- Cache data ---- //

    ICACHE_ENTRY [`CACHE_LINES-1:0] icache_data;

    // ---- Addresses and final outputs ---- //

    // Note: cache tags, not memory tags
    logic [12-`CACHE_LINE_BITS:0] current_tag, last_tag;
    logic [`CACHE_LINE_BITS - 1:0] current_index, last_index;
	logic [63:0]                  Icache_data_out;
	logic                         Icache_valid_out;
    assign {current_tag, current_index} = proc2Icache_addr[15:3];

    assign Icache_data_out = icache_data[current_index].data;
    assign Icache_valid_out = icache_data[current_index].valid &&
                              (icache_data[current_index].tags == current_tag);
	//assign {icache_if_packet_out[1].inst, icache_if_packet_out[0].inst}  = Icache_data_out;
    assign icache_if_packet_out[0].inst  = (proc2Icache_addr[2] == 1) ? Icache_data_out[63:32] : Icache_data_out[31:0];
    assign icache_if_packet_out[1].inst  = Icache_data_out[63:32];
	assign icache_if_packet_out[1].valid = Icache_valid_out && (proc2Icache_addr[2] != 1);
	assign icache_if_packet_out[0].valid = Icache_valid_out;

	assign icache_if_packet_out[2].valid = 0;
	assign icache_if_packet_out[2].inst  = `NOP;

    logic [3:0] current_mem_tag;
    logic miss_outstanding;

    wire got_mem_data = (current_mem_tag == Imem2proc_tag) && (current_mem_tag != 0);

    wire changed_addr = (current_index != last_index) || (current_tag != last_tag);

    wire update_mem_tag = (changed_addr || miss_outstanding || got_mem_data) && (!Dcache_on_bus);

    wire unanswered_miss = changed_addr ? !Icache_valid_out
                                        : (Dcache_on_bus)? miss_outstanding :miss_outstanding && (Imem2proc_response == 0);

    assign proc2Imem_command = reset ? BUS_NONE : (miss_outstanding && !changed_addr && !Dcache_on_bus) ? BUS_LOAD : BUS_NONE;
    assign proc2Imem_addr    = (!reset)? {proc2Icache_addr[31:3],3'b0} : {proc2Icache_addr[31:3],3'b1};


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
			if (squash_flag && squash_pc != proc2Icache_addr) begin
				current_mem_tag <= 0;
			end
            if (got_mem_data) begin // If data came from memory, meaning tag matches
                icache_data[current_index].data  <= Imem2proc_data;
                icache_data[current_index].tags  <= current_tag;
                icache_data[current_index].valid <= 1;
		current_mem_tag                  <= 0;
				
            end
        end
	$display("Dcache_busy:%b Icache_command:%b miss_outstanding:%b changed_addr:%b Imem2proc_response:%b Icache_valid_out:%b, got_mem_data%b current_mem_tag:%b current_index:%b icache_data[current_index].data:%h icache_data[current_index].valid:%b", Dcache_on_bus, proc2Imem_command, miss_outstanding, changed_addr, Imem2proc_response, Icache_valid_out, got_mem_data, current_mem_tag, current_index, icache_data[current_index].data, icache_data[current_index].valid);
		// $display("current_mem_tag:%b", current_mem_tag);
		// $display("Icache_valid_out:%b", Icache_valid_out);
		// $display("current_tag:%b", current_tag);
		// $display("proc2Imem_command:%b", proc2Imem_command);
	
    end

endmodule // icache
