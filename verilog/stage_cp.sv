`include "verilog/sys_defs.svh"

// Now just allocate packages to different tables
module stage_cp(
    input       EX_PACKET      [2:0] ex_packet_in,

    // generate CDB_PACKET, to RS, ROB, MapTable
    output      CDB_RS_PACKET  [2:0] cdb_rs_packet_out, // value, tag, valid
    output      CDB_MT_PACKET  [2:0] cdb_mt_packet_out, // tag, valid
    output      CDB_ROB_PACKET [2:0] cdb_rob_packet_out // value, tag, valid, take_branch, NPC, halt
);

    // CDB to RS
    assign cdb_rs_packet_out[0].value              = ex_packet_in[0].value;
    assign cdb_rs_packet_out[0].tag                = ex_packet_in[0].T;
    assign cdb_rs_packet_out[0].valid              = ex_packet_in[0].valid;
    // CDB to MT
    assign cdb_mt_packet_out[0].Tag                = ex_packet_in[0].T;
    assign cdb_mt_packet_out[0].valid              = ex_packet_in[0].valid;
    // CDB to ROB
    assign cdb_rob_packet_out[0].value             = ex_packet_in[0].value;
    assign cdb_rob_packet_out[0].tag               = ex_packet_in[0].T;
    assign cdb_rob_packet_out[0].valid             = ex_packet_in[0].valid;
    assign cdb_rob_packet_out[0].take_branch       = ex_packet_in[0].branch_taken;
    assign cdb_rob_packet_out[0].NPC               = ex_packet_in[0].NPC;
    assign cdb_rob_packet_out[0].halt              = ex_packet_in[0].halt;

    // CDB to RS
    assign cdb_rs_packet_out[1].value              = ex_packet_in[1].value;
    assign cdb_rs_packet_out[1].tag                = ex_packet_in[1].T;
    assign cdb_rs_packet_out[1].valid              = ex_packet_in[1].valid;
    // CDB to MT
    assign cdb_mt_packet_out[1].Tag                = ex_packet_in[1].T;
    assign cdb_mt_packet_out[1].valid              = ex_packet_in[1].valid;
    // CDB to ROB
    assign cdb_rob_packet_out[1].value             = ex_packet_in[1].value;
    assign cdb_rob_packet_out[1].tag               = ex_packet_in[1].T;
    assign cdb_rob_packet_out[1].valid             = ex_packet_in[1].valid;
    assign cdb_rob_packet_out[1].take_branch       = ex_packet_in[1].branch_taken;
    assign cdb_rob_packet_out[1].NPC               = ex_packet_in[1].NPC;
    assign cdb_rob_packet_out[1].halt              = ex_packet_in[1].halt;

    // CDB to RS
    assign cdb_rs_packet_out[2].value              = ex_packet_in[2].value;
    assign cdb_rs_packet_out[2].tag                = ex_packet_in[2].T;
    assign cdb_rs_packet_out[2].valid              = ex_packet_in[2].valid;
    // CDB to MT
    assign cdb_mt_packet_out[2].Tag                = ex_packet_in[2].T;
    assign cdb_mt_packet_out[2].valid              = ex_packet_in[2].valid;
    // CDB to ROB
    assign cdb_rob_packet_out[2].value             = ex_packet_in[2].value;
    assign cdb_rob_packet_out[2].tag               = ex_packet_in[2].T;
    assign cdb_rob_packet_out[2].valid             = ex_packet_in[2].valid;
    assign cdb_rob_packet_out[2].take_branch       = ex_packet_in[2].branch_taken;
    assign cdb_rob_packet_out[2].NPC               = ex_packet_in[2].NPC;
    assign cdb_rob_packet_out[2].halt              = ex_packet_in[2].halt;           

endmodule
