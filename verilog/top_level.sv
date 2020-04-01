////////////////////////////////////////////////////////////////////////////
//                                                                        //
//   Modulename :  top_level.v                                            //                                                                     //
//   Description :  a top level module that routes signals from ID stage, //
//                 RAT, RS, ROB, RRAT, PRF, Function Unit                 //
//                                                                        // 
////////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __TOP_LEVEL_V__
`define __TOP_LEVEL_V__
`timescale 1ns/100ps

module top_level (
	input                           clock,        
	input                           reset,
    //dcache
    input                           mem2Dcache_data,
    input                           mem2Dcache_tag,
    input                           mem2Dcache_response_valid,
    input                           mem2Dcache_response,

    input ID_PACKET                 id_packet,              // Output of ID stage - decoded 
    // Outputs
    output logic                    rob_full,     
    output logic                    rs_alu_full,
    output logic                    rs_mul_full,
    output logic                    rs_branch_full,
    output logic                    rs_lb_full,
    output logic                    rs_sq_full,
    output logic                    result_valid,          // the current output is valid or not    
    output logic  [`XLEN-1:0]       result_PC,              // branch target address that is committed
    output logic                    result_cond_branch,
    output logic                    result_uncond_branch,
    output logic  [`XLEN-1:0]       result_target_PC,
    output logic                    result_local_pred_direction,
    output logic                    result_global_pred_direction,
    output logic                    result_branch_direction, // branch is actually taken or not
    output logic                    result_mis_pred,
    output                          commit_halt,
    output                          commit_illegal,
    output logic    [1:0]           Dcache2mem_command,      // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    output MEM_SIZE                 Dcache2mem_size,
    output logic    [`XLEN-1:0]     Dcache2mem_data
    
`ifdef DEBUG
    , output logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values
    , output logic [`PRF_SIZE-1:0]                 prf_free
    , output logic [`PRF_SIZE-1:0]                 prf_valid
    , output logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_head
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_tail
    , output ROB_PACKET [`ROB_SIZE-1:0]            rob_packets
    , output logic [`ROB_LEN-1:0]                  rob_head
    , output logic [`ROB_LEN-1:0]                  rob_tail
    , output logic [31:0] [`PRF_LEN-1:0]           rat_packets 
    , output logic [31:0] [`PRF_LEN-1:0]           rrat_packets 
    
    , output logic [`PRF_LEN-1:0]                  opa_preg_idx
    , output logic [`PRF_LEN-1:0]                  opb_preg_idx

    , output logic                           fu_opa_ready
    , output logic                           fu_opb_ready
    , output logic [`XLEN-1:0]               fu_opa_value
    , output logic [`XLEN-1:0]               fu_opb_value
    , output logic [`XLEN-1:0]               fu_offset

    , output RS_ALU_PACKET [`RS_ALU_SIZE-1:0]   rs_alu_packets
    , output logic         [`RS_ALU_LEN:0]      rs_alu_counter
    , output logic         [`RS_ALU_SIZE-1:0]   rs_alu_ex
    , output logic         [`RS_ALU_SIZE-1:0]   rs_alu_free
    , output logic         [`RS_ALU_LEN-1:0]    rs_alu_free_idx
    , output logic         [`RS_ALU_LEN-1:0]    rs_alu_ex_idx 

    , output RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets
    , output logic            [`RS_BR_LEN:0]    rs_branch_counter
    , output logic            [`RS_BR_SIZE-1:0] rs_branch_ex
    , output logic            [`RS_BR_SIZE-1:0] rs_branch_free
    , output logic            [`RS_BR_LEN-1:0]  rs_branch_free_idx
    , output logic            [`RS_BR_LEN-1:0]  rs_branch_ex_idx

    , output RS_MUL_PACKET [`RS_MUL_SIZE-1:0]   rs_mul_packets
    , output logic         [`RS_MUL_LEN:0]      rs_mul_counter
    , output logic         [`RS_MUL_SIZE-1:0]   rs_mul_ex
    , output logic         [`RS_MUL_SIZE-1:0]   rs_mul_free
    , output logic         [`RS_MUL_LEN-1:0]    rs_mul_free_idx
    , output logic         [`RS_MUL_LEN-1:0]    rs_mul_ex_idx
    
    , output RS_LB_PACKET [`RS_LB_SIZE-1:0]     rs_lb_packets
    , output logic        [`RS_LB_LEN:0]        rs_lb_counter
    , output logic        [`RS_LB_SIZE-1:0]     rs_lb_ex
    , output logic        [`RS_LB_SIZE-1:0]     rs_lb_free
    , output logic        [`RS_LB_LEN-1:0]      rs_lb_free_idx
    , output logic        [`RS_LB_LEN-1:0]      rs_lb_ex_idx

    , output RS_SQ_PACKET [`RS_SQ_SIZE-1:0]     rs_sq_packets
    , output logic        [`RS_SQ_LEN:0]        rs_sq_counter
    , output logic        [`RS_SQ_SIZE-1:0]     rs_sq_ex
    , output logic        [`RS_SQ_SIZE-1:0]     rs_sq_free
    , output logic        [`RS_SQ_LEN-1:0]      rs_sq_free_idx
    , output logic        [`RS_SQ_LEN-1:0]      rs_sq_ex_idx

    // Outputs of cdb
    , output logic [3:0]           module_select
    , output logic                 cdb_broadcast_valid
    , output logic [`XLEN-1:0]     cdb_result
    , output logic [`PRF_LEN-1:0]  cdb_dest_preg_idx
    , output logic [`ROB_LEN-1:0]  cdb_rob_idx
    , output logic [`XLEN-1:0]     cdb_broadcast_inst_PC
    , output logic                 cdb_br_direction
    , output logic [`XLEN-1:0]     cdb_br_target_PC
    , output logic                 cdb_mis_pred
    , output logic                 cdb_local_pred_direction
    , output logic                 cdb_global_pred_direction

    // Outputs of prf
    , output logic [`PRF_LEN-1:0]    prf_free_preg_idx
    , output logic [`PRF_LEN-1:0]    dest_preg_idx
    , output logic                   opa_ready
    , output logic [`XLEN-1:0]       opa_value
    , output logic                   opb_ready
    , output logic [`XLEN-1:0]       opb_value

    // Outputs of load store queue
    , output STORE_QUEUE            SQ
    , output LOAD_BUFFER            LB
    , output logic                  sq_all_rsvd
    , output logic [`SQ_LEN-1:0]    sq_head
    , output logic [`SQ_LEN-1:0]    secure_age
    , output logic                  lb2sq_request_valid
    , output LB_ENTRY               lb2sq_request_entry
    , output logic [`SQ_LEN-1:0]    sq_counter
    , output logic                  sq_empty
    , output logic                  forward_match
    , output logic [`XLEN-1:0]      forward_data   
    , output logic [`SQ_LEN-1:0]    forward_match_idx
    , output logic [`XLEN-1:0]      forward_addr
    , output logic [`SQ_LEN-1:0]    forward_age
    , output MEM_SIZE               forward_mem_size
    , output logic                      none_selected
    , output logic [`LB_CAPACITY-1:0]   psel_gnt
    , output logic [`LB_LEN-1:0]        lq_free_idx
    , output logic                      lq_conflict
    , output logic [`LB_LEN-1:0]        lq_issue_idx

    // Outputs of  dcache
    , output DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks
    , output LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0]   load_buffer
`endif
);


     // RAT OUTPUTS
    // logic [`PRF_LEN-1:0]    opa_preg_idx;           // rat -> prf
    // logic [`PRF_LEN-1:0]    opb_preg_idx;           // rat -> prf

    // PRF OUTPUTS
`ifndef DEBUG
    logic [`PRF_LEN-1:0]    prf_free_preg_idx;               // prf -> rat, rob, rs
    logic [`PRF_LEN-1:0]    dest_preg_idx;
    logic                   opa_ready;                       // prf -> rs
    logic [`XLEN-1:0]       opa_value;                       // prf -> rs
    logic                   opb_ready;                       // prf -> rs
    logic [`XLEN-1:0]       opb_value;                       // prf -> rs
`endif
    // ROB OUTPUTS
    logic [4:0]             rob_commit_dest_areg_idx;   // rob -> rrat
    logic [`PRF_LEN-1:0]    rob_commit_dest_preg_idx;   // rob -> rrat
    // logic [`ROB_LEN-1:0]    rob_tail;                   // rob -> rs
    logic                   mis_pred_is_head;           // rob -> rs, prf, rat

    assign  result_mis_pred = mis_pred_is_head;

    // RRAT OUTPUTS
    logic [31:0][`PRF_LEN-1:0]              rat_packets_backup;                  // rat
    logic [`PRF_LEN-1:0]                    rrat_prev_preg_idx;                  // prf
    logic [`PRF_SIZE-1:0]                   rrat_free_backup;                    // prf
    logic [`PRF_SIZE-1:0]                   rrat_valid_backup;                   // prf
    logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]    rrat_free_preg_queue_backup;         // to prf 
    logic [`PRF_LEN-1:0]                    rrat_free_preg_queue_head_backup;    // to prf
    logic [`PRF_LEN-1:0]                    rrat_free_preg_queue_tail_backup;    // to prf

    // RS_ALU OUTPUTS            
    RS_ALU_PACKET            rs_alu_packet;            // rs_alu->alu
    logic                    rs_alu_out_valid;         // rs_alu->alu

    // ALU OUTPUTS
    logic [`XLEN-1:0]        alu_value;                // alu->cdb
    logic                    alu_valid;                // alu->cdb
    logic [`PRF_LEN-1:0]     alu_prf_idx;              // alu->prf
    logic [`ROB_LEN-1:0]     alu_rob_idx;              // alu->cdb
    logic [`XLEN-1:0]        alu_PC;                   // alu->cdb

    // RS_MUL OUTPUTS
    RS_MUL_PACKET            rs_mul_packet;            // rs_mul->mult2cdb
    logic                    rs_mul_out_valid;         // rs_mul->mult2cdb
              
    // MUL OUTPUTS
    logic [`XLEN-1:0]         mul_value;               // mul->cdb
    logic                     mul_valid;               // mul->cdb
    logic [`PRF_LEN-1:0]      mul_prf_idx;             // mul->prf
    logic [`ROB_LEN-1:0]      mul_rob_idx;             // mul->cdb
    logic [`XLEN-1:0]         mul_PC;                  // alu->cdb
    logic                     mul_free;                // mult2cdb->rs_mul

    // RS_LB OUTPUTS
    logic RS_LB_PACKET        rs_lb_packet;
    logic                     rs_lb_out_valid;

    // RS_SQ OUTPUTS
    RS_SQ_PACKET              rs_sq_packet;
    logic                     rs_sq_out_valid;

    // LB&SQ OUTPUTS
    logic                     lb_full;
    logic [`LB_LEN-1:0]       assigned_lb_idx;
    logic                     sq_head_rsvd;
    logic                     sq_full;
    logic [`SQ_LEN-1:0]       sq_tail;
    logic                     sq_valid;
    logic [`XLEN-1:0]         sq_value;
    logic [`PRF_LEN-1:0]      sq_prf_idx;
    logic [`ROB_LEN-1:0]      sq_rob_idx;
    logic [`XLEN-1:0]         sq_PC;
    logic                     lb2cache_request_valid;
    LB_ENTRY                  lb2cache_request_entry;
    logic                     sq2cache_request_valid;
    SQ_ENTRY                  sq2cache_request_entry;

    //RS_BRANCH OUTPUTS
    RS_BRANCH_PACKET          rs_branch_packet;         // rs_branch->branch
    logic                     rs_branch_out_valid;      // rs_branch->cdb

    // BRANCH OUTPUTS
	logic                     br_direction;             // br->bp,btb
	logic [`XLEN-1:0]         br_target_PC;             // br->bp.brb
    logic                     br_valid;                 // br->cdb
    logic [`XLEN-1:0]         br_value;
    logic [`PRF_LEN-1:0]      br_prf_idx;               // legacy output, have no meaning for BR inst
    logic [`ROB_LEN-1:0]      br_rob_idx;               // br->cdb
    logic                     br_mis_pred;              // br->cdb
    logic                     br_cond_branch;           // br->cdb
    logic                     br_uncond_branch;         // br->cdb
    logic                     br_local_pred_direction;  // br->cdb
    logic                     br_global_pred_direction; // br->cdb
    logic [`XLEN-1:0]         br_PC;                    // br->cdb

`ifndef DEBUG
    logic                           fu_opa_ready;
    logic                           fu_opb_ready;
    logic [`XLEN-1:0]               fu_opa_value;
    logic [`XLEN-1:0]               fu_opb_value;
    logic [`XLEN-1:0]               fu_offset;
    // RAT OUTPUTS
    logic [`PRF_LEN-1:0]      opa_preg_idx;
    logic [`PRF_LEN-1:0]      opb_preg_idx;
    // CDB OUTPUTS
    logic [`XLEN-1:0]         cdb_result;
    logic [3:0]               module_select;            // cdb->all FUs, all RSs
    logic                     cdb_broadcast_valid;      // cdb->rs (newly dispatched inst+current entries)
    logic [`PRF_LEN-1:0]      cdb_dest_preg_idx;        // cdb->rob
    logic [`ROB_LEN-1:0]      cdb_rob_idx;              // cdb->rob
    logic [`XLEN-1:0]         cdb_broadcast_inst_PC;    // cdb->bp, btb/lsq
    // CDB OUTPUTS for branch
    logic                     cdb_br_direction;         // cdb->rob
    logic [`XLEN-1:0]         cdb_br_target_PC;         // cdb->??
    logic                     cdb_mis_pred;             // cdb->rob
    logic                     cdb_local_pred_direction; // cdb->bp
    logic                     cdb_global_pred_direction;// cdb->bp

    STORE_QUEUE            SQ;
    LOAD_BUFFER            LB;
    logic                  sq_all_rsvd;
    logic [`SQ_LEN-1:0]    sq_head;
    logic [`SQ_LEN-1:0]    secure_age;
    logic                  lb2sq_request_valid;
    LB_ENTRY               lb2sq_request_entry;
    logic [`SQ_LEN-1:0]    sq_counter;
    logic                  sq_empty;
    logic                  forward_match;
    logic [`XLEN-1:0]      forward_data; 
    logic [`SQ_LEN-1:0]    forward_match_idx;
    logic [`XLEN-1:0]      forward_addr;
    logic [`SQ_LEN-1:0]    forward_age;
    MEM_SIZE               forward_mem_size;
    logic                      none_selected;
    logic [`LB_CAPACITY-1:0]   psel_gnt;
    logic [`LB_LEN-1:0]        lq_free_idx;
    logic                      lq_conflict;
    logic [`LB_LEN-1:0]        lq_issue_idx;
`endif

    // ROB INPUTS

    // PRF INPUTS

    // RAT INPUTS
    logic                     rat_enable;
    assign rat_enable = (id_packet.dest_areg_idx != `ZERO_REG) && id_packet.valid;

    assign dest_preg_idx = (id_packet.dest_areg_idx != `ZERO_REG) ? prf_free_preg_idx : 0;

    // RRAT INPUTS
    logic                     rrat_enable;
    assign rrat_enable = result_valid;

    
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
        .opa_areg_idx(id_packet.opa_areg_idx),      // ID packet
        .opb_areg_idx(id_packet.opb_areg_idx),      // ID packet
        .dest_areg_idx(id_packet.dest_areg_idx),    // ID packet
        .prf_free_preg_idx(prf_free_preg_idx),              // prf
        .rat_packets_backup(rat_packets_backup),    // rrat
        // outputs
        .opa_preg_idx(opa_preg_idx),                // to prf
        .opb_preg_idx(opb_preg_idx)                 // to prf
         `ifdef DEBUG
        , .rat_packets(rat_packets)
        `endif
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
        .rrat_enable(rrat_enable),                                       // rob ???
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
         `ifdef DEBUG
        , .rrat_packets(rrat_packets)
        `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                    R O B                     //
    //                                              //
    //////////////////////////////////////////////////

    rob rob0(
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        // dispatch
        .dispatch_enable(id_packet.valid),         // not only depend on rob_full, (e.g. invalid instr)
        .illegal(id_packet.illegal),
        .halt(id_packet.halt),
        .dest_areg_idx(id_packet.dest_areg_idx),
        .dest_preg_idx(dest_preg_idx),
        .cond_branch(id_packet.cond_branch),
        .uncond_branch(id_packet.uncond_branch),
        .local_pred_direction(id_packet.local_taken),
        .global_pred_direction(id_packet.global_taken),
        .wr_mem(id_packet.wr_mem),
        // cdb broadcast
        .cdb_broadcast_valid(cdb_broadcast_valid),     // make executed_rob_idx valid
        .executed_rob_idx(cdb_rob_idx),                      
        .cdb_br_prediction(cdb_br_direction),
        .cdb_br_target_PC(cdb_br_target_PC),
        .cdb_mis_pred(cdb_mis_pred),
        .sq_head_rsvd(sq_head_rsvd),

        //Outputs
        .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),
        .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),
        .rob_tail(rob_tail),
        .rob_full(rob_full),
        .commit_valid(result_valid),           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
        // branch
        .result_PC(result_PC),
        .result_cond_branch(result_cond_branch),
        .result_uncond_branch(result_uncond_branch),
        .result_target_PC(result_target_PC),
        .result_local_pred_direction(result_local_pred_direction),
        .result_global_pred_direction(result_global_pred_direction),
        .result_branch_direction(result_branch_direction),
        .commit_illegal(commit_illegal),
        .commit_halt(commit_halt),
        .mis_pred_is_head(mis_pred_is_head),
        .store_enable(store_enable)

    `ifdef DEBUG
        , .rob_packets(rob_packets)
        , .rob_head(rob_head)
    `endif
    );


    //////////////////////////////////////////////////
    //                                              //
    //                    P R F                     //
    //                                              //
    //////////////////////////////////////////////////

    prf prf0(
        // inputs
        .clock(clock),                           // top level
        .reset(reset),                           // top level
        .opa_preg_idx(opa_preg_idx),             // rat
        .opb_preg_idx(opb_preg_idx),             // rat
        .prf_enable(rat_enable),            // ???
        .rrat_prev_reg_idx(rrat_prev_preg_idx),  // rrat
        .commit_mis_pred(mis_pred_is_head),      // rob
        .commit_valid(result_valid),             // rob
        .rrat_free_backup(rrat_free_backup),     // rrat
        .rrat_valid_backup(rrat_valid_backup),   // rrat
        .rrat_free_preg_queue_backup(rrat_free_preg_queue_backup),              // rrat
        .rrat_free_preg_queue_head_backup(rrat_free_preg_queue_head_backup),    // rrat
        .rrat_free_preg_queue_tail_backup(rrat_free_preg_queue_tail_backup),    // rrat
        .cdb_result(cdb_result),                    // cdb
        .cdb_dest_preg_idx(cdb_dest_preg_idx),      // cdb
        .cdb_broadcast_valid(cdb_broadcast_valid),  // cdb -> prf, rs
        // outputs
        .prf_free_preg_idx(prf_free_preg_idx),      // to rat, rob, rs
        .opa_ready(opa_ready),                      // to rs
        .opa_value(opa_value),                      // to rs
        .opb_ready(opb_ready),                      // to rs
        .opb_value(opb_value)                       // to rs

    `ifdef DEBUG
        , .prf_values(prf_values)
        , .prf_free(prf_free)
        , .prf_valid(prf_valid)
        , .free_preg_queue(free_preg_queue)
        , .free_preg_queue_head(free_preg_queue_head)
        , .free_preg_queue_tail(free_preg_queue_tail)
    `endif
    );

    always_comb begin
		fu_opa_value = `XLEN'hdeadfbac;
        fu_opa_ready = 1'b1;
		casez (id_packet.opa_select)
			OPA_IS_RS1: begin 
                fu_opa_value = opa_value; 
                fu_opa_ready = opa_ready;
            end
			OPA_IS_NPC:  fu_opa_value = id_packet.NPC;
			OPA_IS_PC:  begin 
                fu_opa_value = (id_packet.inst==`RV32_JAL) ? id_packet.PC : opa_value;
                fu_opa_ready = (id_packet.inst==`RV32_JAL) ? 1'b1 : opa_ready;
            end
			OPA_IS_ZERO: fu_opa_value = 0;
		endcase
    end

    always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
        fu_opb_value = `XLEN'hfacefeed;
        fu_opb_ready = 1'b1;
        fu_offset = 0;
		casez (id_packet.opb_select)
			OPB_IS_RS2:   begin
                fu_opb_value = opb_value;
                fu_opb_ready = opb_ready;  
            end
            OPB_IS_S_IMM:   begin
                fu_opb_value = opb_value;
                fu_opb_ready = opb_ready;  
                fu_offset = `RV32_signext_Simm(id_packet.inst);
            end
            OPB_IS_B_IMM:   begin
                fu_opb_value = opb_value;
                fu_opb_ready = opb_ready; 
                fu_offset = `RV32_signext_Bimm(id_packet.inst); 
            end
			OPB_IS_I_IMM: begin  
                casez (id_packet.fu_type) 
                     ALU: fu_opb_value = `RV32_signext_Iimm(id_packet.inst);
                     MUL: fu_opb_value = `RV32_signext_Iimm(id_packet.inst);
                     MEM: fu_offset = `RV32_signext_Iimm(id_packet.inst);
                     BRANCH: fu_offset = `RV32_signext_Iimm(id_packet.inst);
                     default: fu_opb_value = `RV32_signext_Iimm(id_packet.inst);
                endcase
            end
			OPB_IS_U_IMM: fu_opb_value = `RV32_signext_Uimm(id_packet.inst);
			OPB_IS_J_IMM: fu_offset = `RV32_signext_Jimm(id_packet.inst); 
		endcase 
	end


    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ A L U                //
    //                                              //
    //////////////////////////////////////////////////

    rs_alu rs_alu0(
        //inputs
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .NPC(id_packet.NPC),
        .enable(id_packet.valid && id_packet.fu_type == ALU),
        .opa_preg_idx(opa_preg_idx),
        .opb_preg_idx(opb_preg_idx),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .dest_preg_idx(dest_preg_idx),
        .rob_idx(rob_tail),
        .alu_func(id_packet.alu_func),
        // empty on mis prediction
        .commit_mis_pred(mis_pred_is_head),
        // dispatch
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result), 

        .halt(id_packet.halt),
        .illegal(id_packet.illegal),

        //outputs
        .rs_alu_packet(rs_alu_packet),
        .rs_alu_out_valid(rs_alu_out_valid),
        .rs_alu_full(rs_alu_full)

    `ifdef DEBUG
        , .rs_alu_packets(rs_alu_packets)
        , .rs_alu_counter(rs_alu_counter)
        , .rs_alu_ex(rs_alu_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_alu_free(rs_alu_free)
        , .rs_alu_free_idx(rs_alu_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_alu_ex_idx(rs_alu_ex_idx) 
    `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                     A L U                    //
    //                                              //
    //////////////////////////////////////////////////

    alu alu0(
        //input
        .clock(clock),
        .reset(reset),
        .rs_alu_packet(rs_alu_packet),
        .alu_enable(rs_alu_out_valid),    //.alu_enable(alu_enable&&module_select==4'b1000), 
        //output
        .alu_value(alu_value),
        .alu_valid(alu_valid),
        .alu_prf_idx(alu_prf_idx),
        .alu_rob_idx(alu_rob_idx),
        .alu_PC(alu_PC)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ M U L                //
    //                                              //
    //////////////////////////////////////////////////

    rs_mul rs_mul0(
        //inputs
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .NPC(id_packet.NPC),
        .enable(id_packet.valid && id_packet.fu_type == MUL),
        .opa_preg_idx(opa_preg_idx),
        .opb_preg_idx(opb_preg_idx),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .dest_preg_idx(dest_preg_idx),
        .rob_idx(rob_tail),
        .mul_func(id_packet.alu_func),
        // empty on mis prediction
        .commit_mis_pred(mis_pred_is_head),
        // dispatch
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_value(cdb_result), 
        .mul_free(mul_free),
        //outputs
        .rs_mul_packet(rs_mul_packet),
        .rs_mul_out_valid(rs_mul_out_valid),
        .rs_mul_full(rs_mul_full)

    `ifdef DEBUG
        , .rs_mul_packets(rs_mul_packets)
        , .rs_mul_counter(rs_mul_counter)
        , .rs_mul_ex(rs_mul_ex) 
        , .rs_mul_free(rs_mul_free)
        , .rs_mul_free_idx(rs_mul_free_idx)
        , .rs_mul_ex_idx(rs_mul_ex_idx)
    `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                      M U L                   //
    //                                              //
    //////////////////////////////////////////////////

    mult2cdb mult2cdb0(
        //input
        .clock(clock),
        .reset(reset || mis_pred_is_head),
        .rs_mul_packet(rs_mul_packet),
        .mul_enable(rs_mul_out_valid), 
        //output
        .mul_value(mul_value),
        .mul_valid(mul_valid),
        .mul_free(mul_free),
        .mul_prf_idx(mul_prf_idx),
        .mul_rob_idx(mul_rob_idx),
        .mul_PC(mul_PC)
    );

    
    //////////////////////////////////////////////////
    //                                              //
    //                  R S _ L B                   //
    //                                              //
    //////////////////////////////////////////////////


    rs_lb rs_lb0(
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .NPC(id_packet.NPC),
        .enable(id_packet.valid && id_packet.fu_type == LOAD && id_packet.rd_mem == `TRUE),
        // from ID_PACKET
        .base_preg_idx(opa_preg_idx),
	    .base_ready(fu_opa_ready),
	    .base_value(fu_opa_value),
        .offset(fu_offset),
        .dest_preg_idx(dest_preg_idx),
        .mem_size(id_packet.mem_size),                              
        .load_signed(id_packet.load_signed),

        .commit_mis_pred(mis_pred_is_head),
        .rob_idx(rob_tail),
        .lb_idx(assigned_lb_idx),
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result),

        // outputs
        .rs_lb_packet(rs_lb_packet),     // overwrite base value, if needed
        .rs_lb_out_valid(rs_lb_out_valid),
        .rs_lb_full(rs_lb_full)           // sent rs_lb_full signal to if stage
    `ifdef DEBUG
        , .rs_lb_packets(rs_lb_packets)
        , .rs_lb_counter(rs_lb_counter)
        , .rs_lb_ex(rs_lb_ex)     // goes to priority selector (data ready && FU free)
        , .rs_lb_free(rs_lb_free)
        , .rs_lb_free_idx(rs_lb_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_lb_ex_idx(rs_lb_ex_idx)
    `endif
);

    //////////////////////////////////////////////////
    //                                              //
    //                  R S _ S Q                   //
    //                                              //
    //////////////////////////////////////////////////

    // directly copy from qyj history commit
    rs_sq  rs_sq0 (
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .NPC(id_packet.NPC),
        .enable(id_packet.valid && id_packet.fu_type == LOAD && id_packet.wr_mem == `TRUE),
        .base_preg_idx(opa_preg_idx),
        .src_preg_idx(opb_preg_idx),
        .offset(fu_offset),
        .mem_size(id_packet.mem_size),
        .base_ready(fu_opa_ready),
        .base_value(fu_opa_value),
        .src_ready(fu_opb_ready),
        .src_value(fu_opb_value),
        .commit_mis_pred(mis_pred_is_head),
        .rob_idx(rob_tail),
        .sq_idx(sq_tail),
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result), 
    
        //outputs
        .rs_sq_packet(rs_sq_packet),
        .rs_sq_out_valid(rs_sq_out_valid),
        .rs_sq_full(rs_sq_full)
    `ifdef DEBUG
        , .rs_sq_packets(rs_sq_packets)
        , .rs_sq_counter(rs_sq_counter)
        , .rs_sq_ex(rs_sq_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_sq_free(rs_sq_free)
        , .rs_sq_free_idx(rs_sq_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_sq_ex_idx(rs_sq_ex_idx) 
    `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   L B & S Q                  //
    //                                              //
    //////////////////////////////////////////////////

    load_store_queue load_store_queue0(
        .clock(clock),
        .reset(reset),
        .lb_enable(id_packet.valid && id_packet.fu_type == LOAD && id_packet.rd_mem==`TRUE),  
        .rs_lb_out_valid(rs_lb_out_valid),
        .rs_lb_packet(rs_lb_packet),  
        .sq_enable(id_packet.valid && id_packet.fu_type == STORE && id_packet.wr_mem==`TRUE),
        .rs_sq_out_valid(rs_sq_out_valid),
        .rs_sq_packet(rs_sq_packet),
        .store_enable(store_enable),

        // outputs
        .lb_full(lb_full),
        .assigned_lb_idx(assigned_lb_idx),
        .sq_head_rsvd(sq_head_rsvd), 
        .sq_full(sq_full),
        .sq_tail(sq_tail),
        // to CDB
        .sq_valid(sq_valid),
        .sq_value(sq_value),
        .sq_prf_idx(sq_prf_idx),
        .sq_rob_idx(sq_rob_idx),
        .sq_PC(sq_PC),
        
        .lb2cache_request_valid(lb2cache_request_valid),
        .lb2cache_request_entry(lb2cache_request_entry),
        .sq2cache_request_valid(sq2cache_request_valid),
        .sq2cache_request_entry(sq2cache_request_entry)

    `ifdef DEBUG
        , .SQ(SQ)
        , .LB(LB)
        , .sq_all_rsvd(sq_all_rsvd)
        , .sq_head(sq_head)
        , .secure_age(secure_age)
        , .lb2sq_request_valid(lb2sq_request_valid)
        , .lb2sq_request_entry(lb2sq_request_entry)
        , .sq_counter(sq_counter)
        , .sq_empty(sq_empty)
        , .forward_match(forward_match)
        , .forward_data(forward_data)   
        , .forward_match_idx(forward_match_idx)
        , .forward_addr(forward_addr)
        , .forward_age(forward_age)
        , .forward_mem_size(forward_mem_size)
        , .none_selected(none_selected)
        , .psel_gnt(psel_gnt)
        , .lq_free_idx(lq_free_idx)
        , .lq_conflict(lq_conflict)
        , .lq_issue_idx(lq_issue_idx)
    `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ B R                  //
    //                                              //
    //////////////////////////////////////////////////

    rs_branch rs_branch0(
        //inputs
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .NPC(id_packet.NPC),
        .enable(id_packet.valid && id_packet.fu_type == BRANCH),
        .opa_preg_idx(opa_preg_idx),
        .opb_preg_idx(opb_preg_idx),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .offset(fu_offset),
        .is_jalr(id_packet.inst == `RV32_JALR),
        .rob_idx(rob_tail),
        .dest_preg_idx(dest_preg_idx),
        .branch_func(id_packet.inst.b.funct3),
        .cond_branch(id_packet.cond_branch),
        .uncond_branch(id_packet.uncond_branch),
        .br_pred_direction(id_packet.branch_prediction),
        .br_pred_target_PC(id_packet.NPC),
        .local_pred_direction(id_packet.local_taken),
        .global_pred_direction(id_packet.global_taken),
        // empty on mis prediction
        .commit_mis_pred(mis_pred_is_head),
        // cdb broadcast
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_value(cdb_result), 

        //outputs
        .rs_branch_packet(rs_branch_packet),
        .rs_branch_out_valid(rs_branch_out_valid),
        .rs_branch_full(rs_branch_full)

    `ifdef DEBUG
        , .rs_branch_packets(rs_branch_packets)
        , .rs_branch_counter(rs_branch_counter)
        , .rs_branch_ex(rs_branch_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_branch_free(rs_branch_free)
        , .rs_branch_free_idx(rs_branch_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_branch_ex_idx(rs_branch_ex_idx) 
    `endif
    );

    //////////////////////////////////////////////////
    //                                              //
    //                      BRANCH                  //
    //                                              //
    //////////////////////////////////////////////////

    branch branch0(
        .clock(clock),
        .reset(reset),
        .branch_enable(rs_branch_out_valid),    //  .branch_enable(branch_enable&&module_select==4'b0001),
        .rs_branch_packet(rs_branch_packet), 

        .br_direction(br_direction),           // branch direction 0 NT 1 T
        .br_target_PC(br_target_PC),           // branch target PC = PC+offset
        .br_valid(br_valid), 
        .br_prf_idx(br_prf_idx),
        .br_value(br_value),
        .br_rob_idx(br_rob_idx),
        .br_mis_pred(br_mis_pred),
        .br_cond_branch(br_cond_branch),
        .br_uncond_branch(br_uncond_branch),
        .br_local_pred_direction(br_local_pred_direction),
        .br_global_pred_direction(br_global_pred_direction),
        .br_PC(br_PC)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                     C D B                    //
    //                                              //
    //////////////////////////////////////////////////

    cdb cdb0(
        .clock(clock),
        .reset(reset),
        .commit_mis_pred(mis_pred_is_head),
        // ALU
        .alu_PC(alu_PC),
        .alu_valid(alu_valid),
        .alu_value(alu_value),
        .alu_prf_idx(alu_prf_idx),
        .alu_rob_idx(alu_rob_idx),
        // MUL
        .mul_PC(mul_PC),
        .mul_valid(mul_valid),
        .mul_value(mul_value),
        .mul_prf_idx(mul_prf_idx),
        .mul_rob_idx(mul_rob_idx),
    
        // BRANCH
        .br_PC(br_PC),
        .br_valid(br_valid),
        .br_prf_idx(br_prf_idx),
        .br_value(br_value),
        .br_direction(br_direction),
        .br_target_PC(br_target_PC),
        .br_mis_pred(br_mis_pred), 
        .br_rob_idx(br_rob_idx),
        .br_local_pred_direction(br_local_pred_direction),
        .br_global_pred_direction(br_global_pred_direction),
        //SQ 
        .sq_valid(sq_valid),
        .sq_value(sq_value),
        .sq_prf_idx(sq_prf_idx),
        .sq_rob_idx(sq_rob_idx),
        .sq_PC(sq_PC), 
        //DCACHE
        .dcache_valid(dcache_valid),
        .dcache_value(dcache_value),
        .dcache_prf_idx(dcache_prf_idx),
        .dcache_rob_idx(dcache_rob_idx),
        .dcache_PC(dcache_PC), 

        // output
        .cdb_broadcast_valid(cdb_broadcast_valid),         
        .module_select(module_select),                
        .cdb_dest_preg_idx(cdb_dest_preg_idx),         
        .cdb_rob_idx(cdb_rob_idx),
        .cdb_broadcast_value(cdb_result),
        .cdb_broadcast_inst_PC(cdb_broadcast_inst_PC),       
        // outputs for branch
        .cdb_br_direction(cdb_br_direction),                 
        .cdb_br_target_PC(cdb_br_target_PC),                 
        .cdb_mis_pred(cdb_mis_pred),                         
        .cdb_local_pred_direction(cdb_local_pred_direction),
        .cdb_global_pred_direction(cdb_global_pred_direction)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                     D$                       //
    //                                              //
    //////////////////////////////////////////////////
    
    dcache dcache0(
        // Inputs
        .clock(clock),
        .reset(reset),

        // Load buffer
        .lb2cache_request_entry(lb2cache_request_entry),
        .lb2cache_request_valid(lb2cache_request_valid),

        // Store queue
        .sq2cache_request_entry(sq2cache_request_entry),
        .sq2cache_request_valid(sq2cache_request_valid),

        // Main Memory
        .mem2Dcache_data(mem2Dcache_data),         // Data coming back from memory
        .mem2Dcache_tag(mem2Dcache_tag),          

        // D-cache/I-cache arbiter
        .mem2Dcache_response_valid(mem2Dcache_response_valid),
        .mem2Dcache_response(mem2Dcache_response),     // Tag from memory about current request
        .commit_mis_pred(mis_pred_is_head),

        // Outputs
        // CDB
        .dcache_PC(dcache_PC),
        .dcache_valid(dcache_valid),
        .dcache_value(dcache_value),
        .dcache_prf_idx(dcache_prf_idx),
        .dcache_rob_idx(dcache_rob_idx),

        // Main Memory
        .Dcache2mem_command(Dcache2mem_command),      // Issue a bus load
        .Dcache2mem_addr(Dcache2mem_addr),         // Address sent to memory
        .Dcache2mem_size(Dcache2mem_size),
        .Dcache2mem_data(Dcache2mem_data)

        `ifdef DEBUG
            , .dcache_blocks(dcache_blocks)
            , .load_buffer(load_buffer)
        `endif
);

    //////////////////////////////////////////////////
    //                                              //
    //                     L B                      //
    //         old version (not delete!)            //
    //////////////////////////////////////////////////


    // load_buffer lb0(
    //     .clock(clock),
    //     .reset(reset),
    //     .lb_enable(id_packet.valid && id_packet.fu_type == LOAD && id_packet.rd_mem==`TRUE),  
    //     .rs_lb_out_valid(rs_lb_out_valid),
    //     .rs_lb_packet(rs_lb_packet),
    //     .sq_all_rsvd(sq_all_rsvd),
    //     .sq_head(sq_head),
    //     .sq_tail(sq_tail),
    //     .secure_age(secure_age),

    //     // outputs
    //     .lb_full(lb_full),
    //     .assigned_lb_idx(assigned_lb_idx),    
    //     .lb_request_valid(lb_request_valid),
    //     .lb_request_entry(lb_request_entry)
    // );

    //////////////////////////////////////////////////
    //                                              //
    //                     S Q                      //
    //         old version (not delete!)            //
    //////////////////////////////////////////////////


    // directly copy from qyj history commit
    // store_queue sq0(
    //     .clock(clock),
    //     .reset(reset),
    //     // .sq_enable(id_packet.valid &&id_packet.wr_mem==`TRUE),
    //     .rs_sq_out_valid(rs_sq_out_valid),
    //     .rs_sq_packet(rs_sq_packet),
    //     .lb2sq_request_valid(lb_request_valid),
    //     .lb2sq_request_entry(lb_request_entry),
    //     .store_enable(store_enable),

    //     // outputs
    //     .sq_head_rsvd(sq_head_rsvd),
    //     .sq_full(sq_full),
    //     .sq_all_rsvd(sq_all_rsvd),
    //     .sq_tail(sq_tail),    
    //     .sq_head(sq_head), 
    //     .secure_age(secure_age),
    //     .forward_valid(forward_valid),
    //     .forward_pack(forward_pack),     // To CDB
    
    //     .lb2cache_request_valid(lb2cache_request_valid),
    //     .lb2cache_request_entry(lb2cache_request_entry),
    //     .sq2cache_request_valid(sq2cache_request_valid),
    //     .sq2cache_request_entry(sq2cache_request_entry)
    // );


endmodule
`endif