//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  top_level.v                                          //                                                                     //
//  Description :  a top level module that routes signals from ID stage,//
//                 RAT, RS, ROB, RRAT, PRF, Function Unit               //
//                                                                      // 
//////////////////////////////////////////////////////////////////////////
`define DEBUG
`ifndef __TOP_LEVEL_V__
`define __TOP_LEVEL_V__

`timescale 1ns/100ps

module top_level (
	input              clock,        // system clock
	input              reset,    
    input ID_PACKET    id_packet,    // signals from ID stage
    input              dispatch_enable,

    output logic rob_full,     
    output logic rs_full     
);

// ROB OUTPUTS
logic [4:0]             rob_commit_dest_areg_idx;   // rob -> rrat
logic [`PRF_LEN-1:0]    rob_commit_dest_preg_idx;   // rob -> rrat
logic [`ROB_LEN-1:0]    rob_tail;                   // rob -> rs
logic                   commit_valid;               // rob -> prf
logic                   mis_pred_is_head;           // rob -> rs, prf, rat


// PRF OUTPUTS
logic [`PRF_LEN-1:0]    prf_free_preg_idx;               // prf -> rat, rob, rs
logic                   opa_ready;                       // prf -> rs
logic [`XLEN-1:0]       opa_value;                       // prf -> rs
logic                   opb_ready;                       // prf -> rs
logic [`XLEN-1:0]       opb_value;                       // prf -> rs

// RAT OUTPUTS
logic [`PRF_LEN-1:0]    opa_preg_idx;           // rat -> prf
logic [`PRF_LEN-1:0]    opb_preg_idx;           // rat -> prf

// RRAT OUTPUTS
logic [31:0][`PRF_LEN-1:0]              rat_packets_backup;                  // rat
logic [`PRF_LEN-1:0]                    rrat_prev_preg_idx;                  // prf
logic [`PRF_SIZE-1:0]                   rrat_free_backup;                    // prf
logic [`PRF_SIZE-1:0]                   rrat_valid_backup;                   // prf
logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]    rrat_free_preg_queue_backup;         // to prf 
logic [`PRF_LEN-1:0]                    rrat_free_preg_queue_head_backup;    // to prf
logic [`PRF_LEN-1:0]                    rrat_free_preg_queue_tail_backup;    // to prf

// RS OUTPUTS
RS_FU_PACKET            rs_fu_packet;       // rs -> alu
logic [`ROB_LEN-1:0]    rob_idx;            // rs -> alu

// ALU OUTPUTS
logic [`XLEN-1:0]       alu_value;                  // broadcasting to top_level
logic                   alu_valid;                  // broadcasting to top_level
logic [`PRF_LEN-1:0]    alu_prf_entry;              // alu->prf
logic                   alu_dest_prf_valid;         // alu->rs
logic [`ROB_LEN-1:0]    alu_rob_entry;              // alu->rob

// CDB OUTPUTS
logic                   cdb_broadcast_valid;  //
logic [`ROB_LEN-1:0]    cdb_rob_entry;
logic [`PRF_LEN-1:0]    cdb_dest_preg_idx;
logic                   cdb_mis_pred;
logic                   cdb_result;
logic [`FU_NUM-1:0]     fu_free_list;

// ROB INPUTS
// logic                   dispatch_enable;    // also prf input, input of top_level

// PRF INPUTS

// RAT INPUTS
logic                   rat_enable;
assign rat_enable = (id_packet.dest_areg_idx != `ZERO_REG)&&id_packet.valid;

// logic [4:0]             opa_areg_idx;       // in id_packet
// logic [4:0]             opb_areg_idx;       // in id_packet
// logic [4:0]             dest_areg_idx;      // in id_packet

// RRAT INPUTS
logic                   rrat_enable;
assign rrat_enable = commit_valid;

// RS INPUTS
logic [][] alu_free; // possibly a 2D table that records the free FU

// ALU INPUTS
logic                   alu_enable;


rob rob0(
    //inputs
    .clock(clock),      // top level
    .reset(reset),      // top level
    .PC(id_packet.PC),            // ID packet
    .dispatch_enable(id_packet.valid),          
    .cdb_broadcast_valid(cdb_broadcast_valid),    // cdb
    .dest_areg_idx(id_packet.dest_reg_idx),              // ID packet
    .prf_free_preg_idx(prf_free_preg_idx),      // prf
    .executed_rob_entry(cdb_rob_entry),    // cdb ???
    .cdb_mis_pred(cdb_mis_pred),                // cdb ???
    //Outputs
    .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),    // to rrat
    .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),    // to rrat
    .rob_tail(rob_tail),                    // to rs
    .rob_full(rob_full),                    // top level output
    .commit_valid(commit_valid),            // to rrat, prf
    .mis_pred_is_head(mis_pred_is_head)     // to rs, prf, rat
);

//////////////////////////////////////////////////
//                                              //
//                    P R F                     //
//                                              //
//////////////////////////////////////////////////


prf prf0(
    // inputs
    .clock(clock),                          // top level
    .reset(reset),                           // top level
    .opa_preg_idx(opa_preg_idx),            // rat
    .opb_preg_idx(opb_preg_idx),            // rat
    .dispatch_enable(rat_enable),      // ???
    .rrat_prev_reg_idx(rrat_prev_preg_idx),  // rrat
    .commit_mis_pred(mis_pred_is_head),      // rob
    .commit_valid(commit_valid),            // rob
    .rrat_free_backup(rrat_free_backup),    // rrat
    .rrat_valid_backup(rrat_valid_backup),  // rrat
    .rrat_free_preg_queue_backup(rrat_free_preg_queue_backup);              // rrat
    .rrat_free_preg_queue_head_backup(rrat_free_preg_queue_head_backup);    // rrat
    .rrat_free_preg_queue_tail_backup(rrat_free_preg_queue_tail_backup);    // rrat
    .cdb_result(cdb_result),                    // cdb
    .cdb_dest_preg_idx(cdb_dest_preg_idx),      // cdb
    .cdb_broadcast_valid(cdb_broadcast_valid),  // cdb -> prf, rs
    // outputs
    .prf_free_preg_idx(prf_free_preg_idx),      // to rat, rob, rs
    .opa_ready(opa_ready),                      // to rs
    .opa_value(opa_value),                      // to rs
    .opb_ready(opb_ready),                      // to rs
    .opb_value(opb_value)                       // to rs
);

//////////////////////////////////////////////////
//                                              //
//                    R A T                     //
//                                              //
//////////////////////////////////////////////////

rat rat0(
    // inputs
    .clock(clock),                              // top level
    .reset(reset),                              // top level
    .rat_enable(rat_enable),                    // top level ??? this signal is not usd in RAT
    .commit_mis_pred(mis_pred_is_head),         // rob
    .opa_areg_idx(id_packet.opa_areg_idx),                // ID packet
    .opb_areg_idx(id_packet.opb_areg_idx),                // ID packet
    .dest_areg_idx(id_packet.dest_areg_idx),              // ID packet
    .prf_free_preg_idx(prf_free_preg_idx),      // prf
    .rat_packets_backup(rat_packets_backup),    // rrat
    // outputs
    .opa_preg_idx(opa_preg_idx),                // to prf
    .opb_preg_idx(opb_preg_idx)                 // to prf
);

//////////////////////////////////////////////////
//                                              //
//                    R R A T                   //
//                                              //
//////////////////////////////////////////////////

rrat rrat0(
    //inputs
    .clock(clock),
    .reset(reset),
    .enable(rrat_enable),                                            // rob ???
    .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),        // rob
    .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),        // rob
    //outputs
    .rat_packets_backup(rat_packets_backup),                    // rat
    .rrat_prev_preg_idx(rrat_prev_preg_idx),                    // prf
    .rrat_free_backup(rrat_free_backup),                        // prf
    .rrat_valid_backup(rrat_valid_backup),                      // prf
    .rrat_free_preg_queue_backup(rrat_free_preg_queue_backup),              // to prf 
    .rrat_free_preg_queue_head_backup(rrat_free_preg_queue_head_backup),    // to prf
    .rrat_free_preg_queue_tail_backup(rrat_free_preg_queue_tail_backup)     // to prf
);

//////////////////////////////////////////////////
//                                              //
//                      R S                     //
//                                              //
//////////////////////////////////////////////////

rs rs0(
    //inputs
    .clock(clock),
    .reset(reset),
    .opa_preg_idx(opa_preg_idx),            // rat
    .opb_preg_idx(opb_preg_idx),            // rat
    .prf_free_preg_idx(prf_free_preg_idx),  // prf
	.opa_ready(opa_ready),                  // prf
	.opb_ready(opb_ready),                  // prf
	.opa_value(opa_value),                  // prf
	.opb_value(opb_value),                  // prf
    .commit_mis_pred(mis_pred_is_head),      // rob
    .rob_tail(rob_tail),                    // rob
    .cdb_dest_preg_idx(cdb_dest_preg_idx),  // cdb
    .cdb_value(cdb_result),                  // cdb
    .id_packet_in(id_packet),            // ID packet
    .alu_free(alu_free),                    // alu ???
    // outputs
    .rs_fu_packet(rs_fu_packet),     // overwrite opa and opb value, if needed
    .rs_full(rs_full)
);

//////////////////////////////////////////////////
//                                              //
//                     A L U                    //
//                                              //
//////////////////////////////////////////////////

alu alu0{
    //input
    .rs_fu_packet(rs_fu_packet),
    .alu_enable(alu_enable),
    //output
    .alu_value(alu_value),
    .alu_valid(alu_valid),
    .alu_dest_prf_entry(alu_prf_entry),
    .alu_rob_entry(alu_rob_entry)
}

endmodule