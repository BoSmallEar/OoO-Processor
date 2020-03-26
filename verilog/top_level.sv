////////////////////////////////////////////////////////////////////////////
//                                                                        //
//   Modulename :  top_level.v                                            //                                                                     //
//   Description :  a top level module that routes signals from ID stage, //
//                 RAT, RS, ROB, RRAT, PRF, Function Unit                 //
//                                                                        // 
////////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`ifndef __TOP_LEVEL_V__
`define __TOP_LEVEL_V__
`timescale 1ns/100ps

module top_level (
	input                           clock,        
	input                           reset,    
    input ID_PACKET                 id_packet,              // Output of ID stage - decoded 
    // Outputs
    output logic                    rob_full,     
    output logic                    rs_alu_full,
    output logic                    rs_mul_full,
    output logic                    rs_mem_full,
    output logic                    rs_branch_full,
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
    output                          commit_illegal
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
    
    ,output RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets
    ,output logic [`RS_ALU_LEN:0] rs_alu_counter
    ,output logic [`RS_ALU_SIZE-1:0] rs_alu_ex    // goes to priority selector (data ready && FU free) 
    ,output logic [`RS_ALU_SIZE-1:0] rs_alu_free
    ,output logic [`RS_ALU_LEN-1:0] rs_alu_free_idx // the rs idx that is selected for the dispatched instr
    ,output logic [`RS_ALU_LEN-1:0] rs_alu_ex_idx 

    , output RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets
    , output logic [`RS_BR_LEN:0] rs_branch_counter
    , output logic [`RS_BR_SIZE-1:0] rs_branch_ex     // goes to priority selector (data ready && FU free) 
    , output logic [`RS_BR_SIZE-1:0] rs_branch_free
    , output logic [`RS_BR_LEN-1:0] rs_branch_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_BR_LEN-1:0] rs_branch_ex_idx

    // , output RS_FU_PACKET [`RS_MEM_SIZE-1:0] rs_mem_packets
    // , output logic [`RS_MEM_LEN:0] rs_mem_counter
    // , output logic [`RS_MEM_SIZE-1:0] rs_mem_ex 
    // , output logic [`RS_MEM_SIZE-1:0] rs_mem_free
    // , output logic [`RS_MEM_LEN-1:0] rs_mem_free_idx
    // , output logic [`RS_MEM_LEN-1:0] rs_mem_ex_idx

    , output RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets
    , output logic [`RS_MUL_LEN:0] rs_mul_counter
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_ex     // goes to priority selector (data ready && FU free)
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_free
    , output logic [`RS_MUL_LEN-1:0] rs_mul_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx
  
`endif
);

    logic                           fu_opa_ready;
    logic                           fu_opb_ready;
    logic [`XLEN-1:0]               fu_opa_value;
    logic [`XLEN-1:0]               fu_opb_value;
    logic [`XLEN-1:0]               fu_offset;

     // RAT OUTPUTS
    logic [`PRF_LEN-1:0]    opa_preg_idx;           // rat -> prf
    logic [`PRF_LEN-1:0]    opb_preg_idx;           // rat -> prf

    // PRF OUTPUTS
    logic [`PRF_LEN-1:0]    prf_free_preg_idx;               // prf -> rat, rob, rs
    logic [`PRF_LEN-1:0]    dest_preg_idx;

    logic                   opa_ready;                       // prf -> rs
    logic [`XLEN-1:0]       opa_value;                       // prf -> rs
    logic                   opb_ready;                       // prf -> rs
    logic [`XLEN-1:0]       opb_value;                       // prf -> rs

    // ROB OUTPUTS
    logic [4:0]             rob_commit_dest_areg_idx;   // rob -> rrat
    logic [`PRF_LEN-1:0]    rob_commit_dest_preg_idx;   // rob -> rrat
    // logic [`ROB_LEN-1:0]    rob_tail;                   // rob -> rs
    logic                   commit_valid;               // rob -> prf
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

    // RS_MEM OUTPUTS

    // // MEM OUTPUTS
  
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
    // CDB OUTPUTS for mem
    // logic [`XLEN-1:0]         mem_PC;
    // logic                     mem_valid;
    // logic [`XLEN-1:0]         mem_value;
    // logic [`PRF_LEN-1:0]      mem_prf_idx;
    // logic [`ROB_LEN-1:0]      mem_rob_idx;

    // ROB INPUTS

    // PRF INPUTS

    // RAT INPUTS
    logic                     rat_enable;
    assign rat_enable = (id_packet.dest_areg_idx != `ZERO_REG)&&id_packet.valid;

    assign dest_preg_idx = (id_packet.dest_areg_idx != `ZERO_REG) ? prf_free_preg_idx : 0;

    // RRAT INPUTS
    logic                     rrat_enable;
    assign rrat_enable = commit_valid;

    always_comb begin
		fu_opa_value = `XLEN'hdeadfbac;
        fu_opa_ready = 1'b1;
		case (id_packet.opa_select)
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
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
        fu_opb_value = `XLEN'hfacefeed;
        fu_opb_ready = 1'b1;
        fu_offset = 0;
		case (id_packet.opb_select)
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
                case (id_packet.fu_type) 
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
    //                    Store Queue               //
    //                                              //
    //////////////////////////////////////////////////
    /*  wr_mem     = `TRUE;
	    fu_type    = MEM;
        opa_select = OPA_IS_RS1;        Base Address - to add
        opb_select = OPB_IS_S_IMM;      Source Data
        alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
        fu_offset = `RV32_signext_Bimm(id_packet.inst); 
    */
	/*
        The resolved address should be sent to Store queue, hence we provide an index
    */
    
    //////////////////////////////////////////////////
    //                                              //
    //                    Load  Queue               //
    //                                              //
    //////////////////////////////////////////////////
    /*  opa_select = OPA_IS_RS1;            BASE: fu_opa_value
		opb_select = OPB_IS_I_IMM;          fu_offset
		alu_func = ALU_ADD;
		csr_op = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
        dest_reg   = DEST_RD;		    id_packet.dest_areg_idx
		rd_mem     = `TRUE;
		fu_type    = MEM; 
        
        */
 
    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ M E M                //
    //                                              //
    //////////////////////////////////////////////////

    // rs_mem rs_mem0(
    //     //inputs
    //     .clock(clock),
    //     .reset(reset),
    //     .PC(id_packet.PC),
    //     .NPC(id_packet.NPC),
    //     .enable(id_packet.valid && id_packet.fu_type == MEM),
    //     .opa_preg_idx(opa_preg_idx),
    //     .opb_preg_idx(opb_preg_idx),
    //     .opa_ready(fu_opa_ready),
    //     .opa_value(fu_opa_value),
    //     .opb_ready(fu_opb_ready),
    //     .opb_value(fu_opb_value),
    //     .offset(fu_offset),
    //     .dest_SQ_idx(sq_tail),
    //     .rob_idx(rob_tail),
    //     .rd_mem(id_packet.rd_mem),
    //     .wr_mem(id_packet.wr_mem),
    //     // empty on mis prediction
    //     .commit_mis_pred(mis_pred_is_head),
    //     // cdb broadcast
    //     .cdb_broadcast_valid(cdb_broadcast_valid),
    //     .cdb_dest_preg_idx(cdb_dest_preg_idx),
    //     .cdb_value(cdb_result),
    //     .mem_func(),
    //     //outputs
    //     .rs_mem_packet(rs_mem_packet),
    //     .rs_mem_out_valid(rs_mem_out_valid),
    //     .rs_mem_full(rs_mem_full)
    // );


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
        // cdb broadcast
        .cdb_broadcast_valid(cdb_broadcast_valid),     // make executed_rob_idx valid
        .executed_rob_idx(cdb_rob_idx),                      
        .cdb_br_prediction(cdb_br_direction),
        .cdb_br_target_PC(cdb_br_target_PC),
        .cdb_mis_pred(cdb_mis_pred),

        //Outputs
        .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),
        .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),
        .rob_tail(rob_tail),
        .rob_full(rob_full),
        .commit_valid(commit_valid),           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
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
        .mis_pred_is_head(mis_pred_is_head)

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
        .commit_valid(commit_valid),             // rob
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
        .reset(reset),
        .rs_mul_packet(rs_mul_packet),
        .mul_enable(rs_mul_out_valid), 
        //output
        .mul_value(mul_value),
        .mul_valid(mul_valid),
        .mul_prf_idx(mul_prf_idx),
        .mul_rob_idx(mul_rob_idx),
        .mul_PC(mul_PC)
    );

    
    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ M E M                //
    //                                              //
    //////////////////////////////////////////////////

    // rs_mem rs_mem0(
    //     //inputs
    //     .clock(clock),
    //     .reset(reset),
    //     .PC(id_packet.PC),
    //     .NPC(id_packet.NPC),
    //     .enable(id_packet.valid && id_packet.fu_type == MEM),
    //     .opa_preg_idx(opa_preg_idx),
    //     .opb_preg_idx(opb_preg_idx),
    //     .opa_ready(fu_opa_ready),
    //     .opa_value(fu_opa_value),
    //     .opb_ready(fu_opb_ready),
    //     .opb_value(fu_opb_value),
    //     .offset(fu_offset),
    //     .dest_preg_idx(dest_preg_idx),
    //     .rob_idx(rob_tail),
    //     .rd_mem(id_packet.rd_mem),
    //     .wr_mem(id_packet.wr_mem),
    //     // empty on mis prediction
    //     .commit_mis_pred(mis_pred_is_head),
    //     // cdb broadcast
    //     .cdb_broadcast_valid(cdb_broadcast_valid),
    //     .cdb_dest_preg_idx(cdb_dest_preg_idx),
    //     .cdb_value(cdb_result),
    //     .mem_func(),
    //     //outputs
    //     .rs_mem_packet(rs_mem_packet),
    //     .rs_mem_out_valid(rs_mem_out_valid),
    //     .rs_mem_full(rs_mem_full)
    // );

    //////////////////////////////////////////////////
    //                                              //
    //                   M E M - FU                 //
    //                                              //
    //////////////////////////////////////////////////

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
        // MEM
        // .mem_PC(mem_PC),
        // .mem_valid(mem_valid),
        // .mem_value(mem_value),
        // .mem_prf_idx(mem_prf_idx),
        // .mem_rob_idx(mem_rob_idx),
        // BRANCH
        .br_PC(br_PC),
        .br_valid(br_valid),
        .br_prf_idx(br_prf_idx),
        .br_value(br_value),
        .br_direction(br_direction),
        .br_target_PC(br_target_PC),
        .br_mis_pred(br_mis_pred), 
        .br_rob_idx(br_rob_idx),
        .br_cond_branch(br_cond_branch),
        .br_uncond_branch(br_uncond_branch),
        .br_local_pred_direction(br_local_pred_direction),
        .br_global_pred_direction(br_global_pred_direction),

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
    
endmodule

`endif
`endif