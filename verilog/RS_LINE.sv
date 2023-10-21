module RS_LINE (
    input             		clock, reset, enable,
    input 	 		empty,
    input  			squash_flag,
    input			line_id,
    input			sel,
    input DP_PACKET [2:0]  	dp_packet,
    input MT_RS_PACKET [2:0]  	mt_packet,
    input ROB_RS_PACKET [2:0]	rob_packet,
    input CDB_RS_PACKET [2:0}	cdb_packet,

    output RS_LINE  rs_line
);
    RS_LINE  n_rs_line;
    logic ready_flag;

    //determine ready_flag

    //match tag

    always_ff @(posedge clock) begin
        if (reset || squash_flag) begin
		rs_line.RSID          	<= 0;
		rs_line.inst		<= 'NOP;
            	rs_line.busy          	<= 0;
 		rs_line.ready		<= 0;
		rs_line.T		<= 0;
		rs_line.T1		<= 0;
		rs_line.T2		<= 0;
		rs_line.V1		<= 0;
		rs_line.V2		<= 0;
		rs_line.halt		<= 0;
	end else (enable) begin
		rs_line.RSID          	<= n_rs_line.RSID;
		rs_line.inst		<= n_rs_line.inst;
            	rs_line.busy          	<= n_rs_line.busy;
 		rs_line.ready		<= n_rs_line.ready;
		rs_line.T		<= n_rs_line.T;
		rs_line.T1		<= n_rs_line.T1;
		rs_line.T2		<= n_rs_line.T2;
		rs_line.V1		<= n_rs_line.V1;
		rs_line.V2		<= n_rs_line.V2;
		rs_line.halt		<= n_rs_line.halt;
	end
    end

    always_comb begin
	case (sel)
	2'b00: begin
		//unchanged
		if (empty) begin
			n_rs_line.busy          = 0;	
		end else begin
			n_rs_line.busy          = 1;
		end
		if (cdb_packet.valid) begin
			n_rs_line.V1		= ;
			n_rs_line.V2		= ;
			n_rs_line.T1		= ;
			n_rs_line.T2		= ;
		end else begin
			n_rs_line.V1		= ;
			n_rs_line.V2		= ;
			n_rs_line.T1		= ;
			n_rs_line.T2		= ;
		end
		n_rs_line.ready		= ready_flag;
	end 
	2'b01: begin
		
			n_rs_line.V1		= ;
			n_rs_line.V2		= ;
		
		n_rs_line.RSID          = line_id;
		n_rs_line.inst		= dp_packet.packet[0].inst;
            	n_rs_line.busy          = 1;
 		n_rs_line.ready		= ready_flag;
		n_rs_line.T		= ;
		n_rs_line.T1		= ;
		n_rs_line.T2		= ;
		n_rs_line.halt		= ;
	end
	2'b10: begin
		n_rs_line.V1		= ;
			n_rs_line.V2		= ;
		
		n_rs_line.RSID          = line_id;
		n_rs_line.inst		= dp_packet.packet[1].inst;
            	n_rs_line.busy          = 1;
 		n_rs_line.ready		= ready_flag;
		n_rs_line.T		= ;
		n_rs_line.T1		= ;
		n_rs_line.T2		= ;
		n_rs_line.halt		= ;
	end
	2'b11: begin
		n_rs_line.V1		= ;
			n_rs_line.V2		= ;
		
		n_rs_line.RSID          = line_id;
		n_rs_line.inst		= dp_packet.packet[2].inst;
            	n_rs_line.busy          = 1;
 		n_rs_line.ready		= ready_flag;
		n_rs_line.T		= ;
		n_rs_line.T1		= ;
		n_rs_line.T2		= ;
		n_rs_line.halt		= ;
	end
	default:begin
		n_rs_line.RSID          = 0;
		n_rs_line.inst		= 'NOP;
            	n_rs_line.busy          = 0;
 		n_rs_line.ready		= 0;
		n_rs_line.T		= 0;
		n_rs_line.T1		= 0;
		n_rs_line.T2		= 0;
		n_rs_line.V1		= 0;
		n_rs_line.V2		= 0;
		n_rs_line.halt		= 0;
	end
    end
