`include "verilog/sys_defs.svh"

module PSEL_DCACHE (
    input logic [3:0]     req,
    output logic [3:0]    gnt
);

    logic [3:0] pre_req;

	
    assign gnt[0] = req[0];
    assign pre_req[0] = req[0];
    genvar i;
    for(i = 1; i<4; i++)begin
        assign gnt[i] = req[i] & ~pre_req[i-1];  
        assign pre_req[i] = req[i] | pre_req[i-1];
    end    
endmodule 

module DCACHE(
    input clock, reset,
    input logic squash_flag,
    input LSQ_DCACHE_PACKET lsq_packet_in,
    input [3:0] Dmem2proc_response,
    input [63:0] Dmem2proc_data,
    input [3:0] Dmem2proc_tag,


    output DCACHE_LSQ_PACKET [1:0] lsq_packet_out,
    output logic icache_busy,
    output logic rt_busy,
    output logic [`XLEN-1:0] proc2Dmem_addr,
    output logic [63:0] proc2Dmem_data,
    output logic [1:0] proc2Dmem_command,
    output DCACHE_SET [`DCACHE_SET_NUM-1:0] dcache_table
);

    //DCACHE_SET [`DCACHE_SET_NUM-1:0] dcache_table;
    DCACHE_SET [`DCACHE_SET_NUM-1:0] n_dcache_table;
    MSHR_LINE [3:0] mshr_table;
    MSHR_LINE [3:0] n_mshr_table;
    MSHR_STATE [3:0] mshr_state_table;
    logic [3:0] [3:0] mshr_response_table;
    logic ptr;
    logic [2:0] in_bo;
    logic [3:0] in_idx;
    logic [24:0] in_tag;
    logic line0_hit;
    logic line1_hit;
    logic miss;
    logic mem_req;
    logic [1:0] mshr_last_match;
    logic [`XLEN-1:0] evict_addr;
    logic [63:0] evict_data;
    logic evict_valid;
    logic [`XLEN-1:0] n_evict_addr;
    logic [63:0] n_evict_data;
    logic n_evict_valid;
    logic [63:0] income_data;
    logic [3:0] mshr_invalid;
    logic [3:0] masked_invalid;
    logic [3:0] mshr_ready;
    logic [3:0] masked_ready;
    logic [3:0] mshr_state_completed;
    logic mshr_state_completed_match;

    assign {in_tag, in_idx, in_bo} = lsq_packet_in.address;
    assign line0_hit = lsq_packet_in.valid && dcache_table[in_idx].line[0].valid && (dcache_table[in_idx].line[0].tag == in_tag);
    assign line1_hit = lsq_packet_in.valid && dcache_table[in_idx].line[1].valid && (dcache_table[in_idx].line[1].tag == in_tag);
    assign miss = ~line0_hit && ~line1_hit;
    assign ptr = (line0_hit) ? 0 : (line1_hit) ? 1 : 0;
    assign mem_req = ~(lsq_packet_in.valid && miss) ? 0 : 
			(({in_tag, in_idx} == {mshr_table[0].tag, mshr_table[0].idx}) && (mshr_state_table[0] == WAITING) ||
			({in_tag, in_idx} == {mshr_table[1].tag, mshr_table[1].idx}) && (mshr_state_table[1] == WAITING) ||
			({in_tag, in_idx} == {mshr_table[2].tag, mshr_table[2].idx}) && (mshr_state_table[2] == WAITING) ||
			({in_tag, in_idx} == {mshr_table[3].tag, mshr_table[3].idx}) && (mshr_state_table[3] == WAITING)) ? 0 :1;
    assign mshr_last_match = ({in_tag, in_idx} == {mshr_table[3].tag, mshr_table[3].idx}) && (mshr_state_table[3] == WAITING) ? 3 :
			({in_tag, in_idx} == {mshr_table[2].tag, mshr_table[2].idx}) && (mshr_state_table[2] == WAITING) ? 2 :
			({in_tag, in_idx} == {mshr_table[1].tag, mshr_table[1].idx}) && (mshr_state_table[1] == WAITING) ? 1 : 0;

    genvar i;
    for(i = 0; i<4; i++)begin
	assign mshr_invalid[i] = (mshr_state_table[i] == INVALID);
	assign mshr_state_completed[i] = mshr_state_table[i] == WAITING && (mshr_response_table[i] == Dmem2proc_tag) && (Dmem2proc_tag != 3'b0);
        assign mshr_ready[i] = (mshr_state_table[i] == READY);
    end  
    assign mshr_state_completed_match = (mshr_state_completed[0] && ({in_tag, in_idx} == {mshr_table[0].tag, mshr_table[0].idx})) ||
					(mshr_state_completed[1] && ({in_tag, in_idx} == {mshr_table[1].tag, mshr_table[1].idx})) ||
					(mshr_state_completed[2] && ({in_tag, in_idx} == {mshr_table[2].tag, mshr_table[2].idx})) ||
					(mshr_state_completed[3] && ({in_tag, in_idx} == {mshr_table[3].tag, mshr_table[3].idx}));
    PSEL_DCACHE invalid_psel(
        // input
        .req(mshr_invalid),
        
        // output
        .gnt(masked_invalid)
    );
    PSEL_DCACHE ready_psel(
        // input
        .req(mshr_ready),
        
        // output
        .gnt(masked_ready)
    );

    always_comb begin
	n_dcache_table = dcache_table;
	n_dcache_table[in_idx].last_ptr = (line0_hit) ? 0 : (line1_hit) ? 1 : dcache_table[in_idx].last_ptr;
	income_data = Dmem2proc_data;
	for(int i=0; i<4; i++) begin
	    if(mshr_state_completed[i]) begin
		$display("heard");
		n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].valid = 1'b1;
		n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value = income_data;
		//n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value = Dmem2proc_data;
		n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].tag = mshr_table[i].tag;
		if(~mshr_table[i].st_or_ld) begin
		    if(mshr_table[i].mem_size == BYTE) begin
			case(mshr_table[i].bo)
			    3'b000:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[7:0] = mshr_table[i].in_value[7:0];
			    3'b001:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[15:8] = mshr_table[i].in_value[7:0];
			    3'b010:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[23:16] = mshr_table[i].in_value[7:0];
			    3'b011:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[31:24] = mshr_table[i].in_value[7:0];
			    3'b100:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[39:32] = mshr_table[i].in_value[7:0];
			    3'b101:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[47:40] = mshr_table[i].in_value[7:0];
			    3'b110:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[55:48] = mshr_table[i].in_value[7:0];
			    3'b111:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[63:56] = mshr_table[i].in_value[7:0];
			endcase
		    end else if(mshr_table[i].mem_size == HALF) begin
			case(mshr_table[i].bo[2:1])
			    2'b00:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[15:0] = mshr_table[i].in_value[15:0];
			    2'b01:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[31:16] = mshr_table[i].in_value[15:0];
			    2'b10:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[47:32] = mshr_table[i].in_value[15:0];
			    2'b11:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[63:48] = mshr_table[i].in_value[15:0];
			endcase
		    end else begin
			case(mshr_table[i].bo[2])
			    1'b0:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[31:0] = mshr_table[i].in_value;
			    1'b1:n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value[63:32] = mshr_table[i].in_value;
			endcase
		    end
		    income_data = n_dcache_table[mshr_table[i].idx].line[~mshr_table[i].ptr].value;
		end
		n_mshr_table[i].value = (mshr_table[i].bo[2]) ? Dmem2proc_data[63:32] : Dmem2proc_data[31:0];
	    end else begin
		n_mshr_table[i].value = mshr_table[i].value;
	   end
	end
	if(lsq_packet_in.valid) begin
	    if(~lsq_packet_in.st_or_ld && ~miss) begin
		if(lsq_packet_in.mem_size == BYTE) begin
		    case(in_bo)
		        3'b000:n_dcache_table[in_idx].line[ptr].value[7:0] = lsq_packet_in.value[7:0];
		        3'b001:n_dcache_table[in_idx].line[ptr].value[15:8] = lsq_packet_in.value[7:0];
		        3'b010:n_dcache_table[in_idx].line[ptr].value[23:16] = lsq_packet_in.value[7:0];
		        3'b011:n_dcache_table[in_idx].line[ptr].value[31:24] = lsq_packet_in.value[7:0];
		        3'b100:n_dcache_table[in_idx].line[ptr].value[39:32] = lsq_packet_in.value[7:0];
		        3'b101:n_dcache_table[in_idx].line[ptr].value[47:40] = lsq_packet_in.value[7:0];
		        3'b110:n_dcache_table[in_idx].line[ptr].value[55:48] = lsq_packet_in.value[7:0];
		        3'b111:n_dcache_table[in_idx].line[ptr].value[63:56] = lsq_packet_in.value[7:0];
		    endcase
		end else if(lsq_packet_in.mem_size == HALF) begin
		    case(in_bo[2:1])
			2'b00:n_dcache_table[in_idx].line[ptr].value[15:0] = lsq_packet_in.value[15:0];
			2'b01:n_dcache_table[in_idx].line[ptr].value[31:16] = lsq_packet_in.value[15:0];
			2'b10:n_dcache_table[in_idx].line[ptr].value[47:32] = lsq_packet_in.value[15:0];
			2'b11:n_dcache_table[in_idx].line[ptr].value[63:48] = lsq_packet_in.value[15:0];
		    endcase
		end else begin
		    case(in_bo[2])
			1'b0:n_dcache_table[in_idx].line[ptr].value[31:0] = lsq_packet_in.value;
			1'b1:n_dcache_table[in_idx].line[ptr].value[63:32] = lsq_packet_in.value;
		    endcase
		end
	    end

	end
    end

    always_comb begin
	for(int k=0; k<4; k++) begin
	    n_mshr_table[k].bo = mshr_table[k].bo;
	    n_mshr_table[k].idx = mshr_table[k].idx;
	    n_mshr_table[k].tag = mshr_table[k].tag;
	    n_mshr_table[k].st_or_ld = mshr_table[k].st_or_ld;
	    n_mshr_table[k].ptr = mshr_table[k].ptr;
	    n_mshr_table[k].mem_size = mshr_table[k].mem_size;
	    n_mshr_table[k].T = mshr_table[k].T;
	    n_mshr_table[k].in_value = mshr_table[k].in_value;
	end
	if(lsq_packet_in.valid && (miss && ~mshr_state_completed_match)) begin
	    for (int j=0; j<4; j++) begin
		if(masked_invalid[j]) begin
		    n_mshr_table[j].bo = in_bo;
		    n_mshr_table[j].idx = in_idx;
		    n_mshr_table[j].tag = in_tag;
		    n_mshr_table[j].st_or_ld = lsq_packet_in.st_or_ld;
		    n_mshr_table[j].ptr = (mem_req) ? dcache_table[in_idx].last_ptr : mshr_table[mshr_last_match].ptr;
		    n_mshr_table[j].mem_size = lsq_packet_in.mem_size;
		    n_mshr_table[j].T = lsq_packet_in.T;
		    n_mshr_table[j].in_value = lsq_packet_in.value;
		end
	    end
	end
    end

    always_comb begin
	n_evict_addr = evict_addr;
        n_evict_data = evict_data;
	n_evict_valid = 0;
	if(mshr_state_completed != 4'b0) begin
	    if(mshr_state_completed[0]) begin
	    	n_evict_addr = {dcache_table[mshr_table[0].idx].line[~dcache_table[mshr_table[0].idx].last_ptr].tag, mshr_table[0].idx, 3'b0};
	    	n_evict_data = dcache_table[mshr_table[0].idx].line[~dcache_table[mshr_table[0].idx].last_ptr].value;
	    	n_evict_valid = dcache_table[mshr_table[0].idx].line[~dcache_table[mshr_table[0].idx].last_ptr].valid;
	    end else if(mshr_state_completed[1]) begin
	    	n_evict_addr = {dcache_table[mshr_table[1].idx].line[~dcache_table[mshr_table[1].idx].last_ptr].tag, mshr_table[1].idx, 3'b0};
	    	n_evict_data = dcache_table[mshr_table[1].idx].line[~dcache_table[mshr_table[1].idx].last_ptr].value;
	    	n_evict_valid = dcache_table[mshr_table[1].idx].line[~dcache_table[mshr_table[1].idx].last_ptr].valid;
	    end else if(mshr_state_completed[2]) begin
	    	n_evict_addr = {dcache_table[mshr_table[2].idx].line[~dcache_table[mshr_table[2].idx].last_ptr].tag, mshr_table[2].idx, 3'b0};
	    	n_evict_data = dcache_table[mshr_table[2].idx].line[~dcache_table[mshr_table[2].idx].last_ptr].value;
	    	n_evict_valid = dcache_table[mshr_table[2].idx].line[~dcache_table[mshr_table[2].idx].last_ptr].valid;
	    end else begin
	    	n_evict_addr = {dcache_table[mshr_table[3].idx].line[~dcache_table[mshr_table[3].idx].last_ptr].tag, mshr_table[3].idx, 3'b0};
	    	n_evict_data = dcache_table[mshr_table[3].idx].line[~dcache_table[mshr_table[3].idx].last_ptr].value;
	    	n_evict_valid = dcache_table[mshr_table[3].idx].line[~dcache_table[mshr_table[3].idx].last_ptr].valid;
	    end
	end
    end

    always_comb begin
	if(lsq_packet_in.valid && ~miss) begin
	    lsq_packet_out[0].valid = 1;
	    lsq_packet_out[0].address = lsq_packet_in.address;
	    lsq_packet_out[0].T = lsq_packet_in.T;
	    lsq_packet_out[0].st_or_ld = lsq_packet_in.st_or_ld;
	    case(lsq_packet_in.mem_size)
		BYTE: begin
			lsq_packet_out[0].value = (in_bo[2]) ? dcache_table[in_idx].line[ptr].value[63:32] : dcache_table[in_idx].line[ptr].value[31:0];
			lsq_packet_out[0].value >>= (in_bo[1:0])*8;
			lsq_packet_out[0].value[31:8] = 24'b0;
		end
		HALF: begin
			lsq_packet_out[0].value = (in_bo[2]) ? dcache_table[in_idx].line[ptr].value[63:32] : dcache_table[in_idx].line[ptr].value[31:0];
			lsq_packet_out[0].value >>= (in_bo[1])*16;
			lsq_packet_out[0].value[31:16] = 16'b0;
		end
		default:lsq_packet_out[0].value = (in_bo[2]) ? dcache_table[in_idx].line[ptr].value[63:32] : dcache_table[in_idx].line[ptr].value[31:0];
	    endcase
 	end else if(lsq_packet_in.valid && mshr_state_completed_match) begin
		lsq_packet_out[0].valid = 1;
	    	lsq_packet_out[0].address = lsq_packet_in.address;
		lsq_packet_out[0].T = lsq_packet_in.T;
		lsq_packet_out[0].st_or_ld = lsq_packet_in.st_or_ld;
	    	case(lsq_packet_in.mem_size)
		    BYTE: begin
			//lsq_packet_out[0].value = (in_bo[2]) ? income_data[63:32] : income_data[31:0];
			lsq_packet_out[0].value = (in_bo[2]) ? Dmem2proc_data[63:32] : Dmem2proc_data[31:0];
			lsq_packet_out[0].value >>= (in_bo[1:0])*8;
			lsq_packet_out[0].value[31:8] = 24'b0;
		    end
		    HALF: begin
			//lsq_packet_out[0].value = (in_bo[2]) ? income_data[63:32] : income_data[31:0];
			lsq_packet_out[0].value = (in_bo[2]) ? Dmem2proc_data[63:32] : Dmem2proc_data[31:0];
			lsq_packet_out[0].value >>= (in_bo[1])*16;
			lsq_packet_out[0].value[31:16] = 16'b0;
		    end
		    //default:lsq_packet_out[0].value = (in_bo[2]) ? income_data[63:32] : income_data[31:0];
		    default:lsq_packet_out[0].value = (in_bo[2]) ? Dmem2proc_data[63:32] : Dmem2proc_data[31:0];
		    
	    	endcase
		// $display("---------------");
	end else begin
	    lsq_packet_out[0].valid = 0;
	    lsq_packet_out[0].address = 0;
	    lsq_packet_out[0].value = 0;
	    lsq_packet_out[0].T = 0;
	    lsq_packet_out[0].st_or_ld = 0;
	end
    end

    always_comb begin
	lsq_packet_out[1].valid = 0;
	lsq_packet_out[1].address = 0;
	lsq_packet_out[1].value = 0;
	lsq_packet_out[1].T = 0;
	lsq_packet_out[1].st_or_ld = 0;
	for(int n=0; n<4; n++) begin
	    if(masked_ready[n]) begin
		lsq_packet_out[1].valid = 1;
	        lsq_packet_out[1].address = {mshr_table[n].tag, mshr_table[n].idx, mshr_table[n].bo};
		lsq_packet_out[1].T = mshr_table[n].T;
		lsq_packet_out[1].st_or_ld = mshr_table[n].st_or_ld;
	        case(mshr_table[n].mem_size)
		    BYTE: begin
			lsq_packet_out[1].value = (mshr_table[n].bo[2]) ? mshr_table[n].value[63:32] : mshr_table[n].value[31:0];
			lsq_packet_out[1].value >>= (mshr_table[n].bo[1:0])*8;
			lsq_packet_out[1].value[31:8] = 24'b0;
		    end
		    HALF: begin
			lsq_packet_out[1].value = (mshr_table[n].bo[2]) ? mshr_table[n].value[63:32] : mshr_table[n].value[31:0];
			lsq_packet_out[1].value >>= (mshr_table[n].bo[1])*16;
			lsq_packet_out[1].value[31:16] = 16'b0;
		    end
		    default:lsq_packet_out[1].value = (mshr_table[n].bo[2]) ? mshr_table[n].value[63:32] : mshr_table[n].value[31:0];
	        endcase
	    end	
	end
    end

    always_comb begin
        proc2Dmem_command = BUS_NONE;
        proc2Dmem_addr = 0;
        proc2Dmem_data = 32'h0;
	icache_busy = 0;
        if (mem_req) begin
	$display("sent");
            proc2Dmem_command = BUS_LOAD;
            proc2Dmem_addr = {in_tag, in_idx, 3'b0};
	    icache_busy = 1;
        end else if (evict_valid) begin
            proc2Dmem_command = BUS_STORE;
            proc2Dmem_addr = evict_addr;
            proc2Dmem_data = evict_data;
	    icache_busy = 1;
	$display("evict");
        end
    end

    assign lsq_packet_out[0].busy = n_evict_valid || (mshr_state_table[0] != INVALID && mshr_state_table[1] != INVALID && mshr_state_table[2] != INVALID && 
					mshr_state_table[3] != INVALID);
    assign lsq_packet_out[1].busy = lsq_packet_out[0].busy;
    assign rt_busy = (mshr_state_table[0] != INVALID && mshr_state_table[1] != INVALID && mshr_state_table[2] != INVALID && mshr_state_table[3] != INVALID) || 
					((lsq_packet_in.valid && miss && ~lsq_packet_in.st_or_ld) || ((mshr_state_table[0] == WAITING)&& ~mshr_table[0].st_or_ld) || 
					((mshr_state_table[1] == WAITING) && ~mshr_table[1].st_or_ld) ||
					((mshr_state_table[2] == WAITING) && ~mshr_table[2].st_or_ld) || ((mshr_state_table[3] == WAITING) && ~mshr_table[3].st_or_ld));

    always_ff @(posedge clock) begin
	if(reset) begin
	    //last_ptr <= 0;
	    dcache_table <= 0;
	    mshr_table <= 0;
	    evict_addr <= 0;
	    evict_data <= 0;
	    evict_valid <= 0;
	    mshr_state_table[0] <= INVALID;
	    mshr_response_table[0] <= 3'b0;
	    mshr_state_table[1] <= INVALID;
	    mshr_response_table[1] <= 3'b0;
	    mshr_state_table[2] <= INVALID;
	    mshr_response_table[2] <= 3'b0;
	    mshr_state_table[3] <= INVALID;
	    mshr_response_table[3] <= 3'b0;
	end else begin
	    //last_ptr <= ptr;
	    dcache_table <= n_dcache_table;
	    mshr_table <= n_mshr_table;
	    evict_addr <= n_evict_addr;
	    evict_data <= n_evict_data;
	    evict_valid <= n_evict_valid;
	    for(int m=0; m<4; m++) begin
		if(squash_flag) begin
		    mshr_state_table[m] <= INVALID;
		    mshr_response_table[m] <= 3'b0;
		end else if(lsq_packet_in.valid && (miss && ~mshr_state_completed_match) && masked_invalid[m]) begin
		    mshr_state_table[m] <= WAITING;
		    mshr_response_table[m] <= (mem_req) ? Dmem2proc_response : mshr_response_table[mshr_last_match];
	        end else if(mshr_state_table[m] == WAITING) begin
		    if((mshr_response_table[m] == Dmem2proc_tag) && (Dmem2proc_tag != 3'b0)) begin
			mshr_state_table[m] <= READY;
			mshr_response_table[m] <= 3'b0;
		    end
		//end else if(mshr_state_table[m] == COMPLETED) begin
		    //mshr_state_table[m] <= READY;
		end else if(masked_ready[m]) begin
		    mshr_state_table[m] <= INVALID;
		end
	    end
	    //$display("evict_valid:%b completed:%b state:%b income_data:%h", evict_valid, mshr_state_completed, mshr_state_table, income_data);
	    //$display("idx0:%h idx1:%h idx2:%h idx3:%h", mshr_table[0].value[7:0], mshr_table[1].value[7:0], mshr_table[2].value[7:0], mshr_table[3].value[7:0]);
        $display("mshr_state_table[0]:%b, mshr_state_table[1]:%b, mshr_state_table[2]:%b, mshr_state_table[3]", mshr_state_table[0], mshr_state_table[1], mshr_state_table[2], mshr_state_table[3]);
	end
	if(lsq_packet_in.valid) begin
		$display("sendtoDmem addr:%h value:%h st_or_ld:%b", lsq_packet_in.address, lsq_packet_in.value, lsq_packet_in.st_or_ld);
	end
	if(lsq_packet_out[0].valid) begin
		$display("sendtoLSQ value[0]:%h", lsq_packet_out[0].value);
	end
	if(lsq_packet_out[1].valid) begin
		$display("sendtoLSQ value[1]:%h", lsq_packet_out[1].value);
    end
	end
endmodule    
