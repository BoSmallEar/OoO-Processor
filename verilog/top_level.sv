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
	input              clock,        // System clock
	input              reset,    
    input ID_EX_PACKET id_ex_packet, // signals from ID stage 

    output logic rob_full,          
);

// logic                       enable;

// logic [`PRF_LEN-1:0]        opa_preg_idx;
// logic [`PRF_LEN-1:0]        opb_preg_idx;
// logic                       dispatch_enable;
// logic [`PRF_LEN-1:0]        rrat_prev_reg_idx;
// logic                       commit_mis_pred;
// logic [`PRF_SIZE-1:0]       rrat_free_backup;
// logic [`PRF_SIZE-1:0]       rrat_valid_backup;
// logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0] rrat_free_preg_queue_backup;
// logic [`PRF_LEN-1:0]        rrat_free_preg_queue_head_backup;
// logic [`PRF_LEN-1:0]        rrat_free_preg_queue_tail_backup;
// logic [`XLEN-1:0]           cdb_result;
// logic [`PRF_LEN-1:0]        cdb_dest_preg_idx;
// logic                       execution_finished;

logic [`PRF_LEN-1:0] prf_free_preg_idx; // prf -> rat, rs, rob
logic                opa_ready;         // prf -> rs
logic [`XLEN-1:0]    opa_value;         // prf -> rs
logic                opb_ready;         // prf -> rs
logic [`XLEN-1:0]    opb_value;         // prf -> rs

logic [4:0]                 rob_commit_dest_areg_idx;   // rob -> rrat
logic [`PRF_LEN-1:0]        rob_commit_dest_preg_idx;   // rob -> rrat
logic [`ROB_LEN-1:0]        rob_tail;                   // rob -> rs
logic                       commit_valid;               // rob -> prf

rob rob0(
    //inputs
    .clock(clock),      // top level
    .reset(reset),      // top level
    .PC(PC),            // ID packet
    .dispatch_enable(dispatch_enable),          // internal : not only depend on rob_full, (e.g. invalid instr)
    .execution_finished(execution_finished),    // fu
    .dest_areg_idx(dest_areg_idx),              // ID packet
    .prf_free_preg_idx(prf_free_preg_idx),      // prf
    .executed_rob_entry(executed_rob_entry),    // cdb ???
    .cdb_mis_pred(cdb_mus_pred),                // cdb ???
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
    .reset(rset),                           // top level
    .opa_preg_idx(opa_preg_idx),            // rat
    .opb_preg_idx(opb_preg_idx),            // rat
    .dispatch_enable(dispatch_enable),      // ???
    .rrat_prev_reg_idx(rrat_prev_reg_idx),  // rrat
    .commit_mis_pred(commit_mis_pred),      // rob
    .commit_valid(commit_valid),            // rob
    .rrat_free_backup(rrat_free_backup),    // rrat
    .rrat_valid_backup(rrat_valid_backup),  // rrat
    .rrat_free_preg_queue_backup(rrat_free_preg_queue_backup);              // rrat
    .rrat_free_preg_queue_head_backup(rrat_free_preg_queue_head_backup);    // rrat
    .rrat_free_preg_queue_tail_backup(rrat_free_preg_queue_tail_backup);    // rrat
    .cdb_result(cdb_result),                    // cdb
    .cdb_dest_preg_idx(cdb_dest_preg_idx),      // cdb
    .execution_finished(execution_finished),    // fu
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
    .commit_mis_pred(commit_mis_pred),          // rob
    .opa_areg_idx(opa_areg_idx),                // ID packet
    .opb_areg_idx(opb_areg_idx),                // ID packet
    .dest_areg_idx(dest_areg_idx),              // ID packet
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
    .enable(enable),                                            // rob ???
    .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),        // rob
    .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),        // rob
    //outputs
    .rat_packets_backup(rat_packets_backup),                    // rat
    .rrat_prev_preg_idx(rrat_prev_preg_idx),                    // prf
    .rrat_free_backup(rrat_free_backup),                        // rat
    .rrat_valid_backup(rrat_valid_backup),                      // rat
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
    .commit_mis_pred(commit_mis_pred),      // rob
    .rob_tail(rob_tail),                    // rob
    .cdb_dest_preg_idx(cdb_dest_preg_idx),  // cdb
    .cdb_value(cdb_value),                  // cdb
    .id_packet_in(id_packet_in),            // ID packet
    .alu_free(alu_free),                    // alu ???
    // outputs
    .id_packet_out(id_packet_out),     // overwrite opa and opb value, if needed
    .rob_idx(rob_idx),                  // the correponding entry being sent to FU/CDB
    .rs_full(rs_full)
);

//////////////////////////////////////////////////
//                                              //
//                     A L U                    //
//                                              //
//////////////////////////////////////////////////

alu alu0{
    //input
    .id_packet_out(id_packet_out),
    .alu_enable(alu_enable),
    .rob_idx(rob_idx),
    //output
    .alu_value(alu_value),
    .alu_valid(alu_valid),
    .alu_dest_prf_entry(alu_prf_entry),
    .alu_dest_prf_valid(alu_dest_prf_valid),
    .alu_rob_entry(alu_rob_entry)
}


endmodule