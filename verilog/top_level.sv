////////////////////////////////////////////////////////////////////////////
//                                                                        //
//   Modulename :  top_level.v                                            //                                                                     //
//   Description :  a top level module that routes signals from ID stage, //
//                 RAT, RS, ROB, RRAT, PRF, Function Unit                 //
//                                                                        // 
////////////////////////////////////////////////////////////////////////////
`define DEBUG
`ifndef __TOP_LEVEL_V__
`define __TOP_LEVEL_V__

`timescale 1ns/100ps

module top_level (
	input                           clock,        
	input                           reset,    
    input ID_PACKET                 id_packet,    // Output of ID stage - decoded
    
    input logic                     dispatch_enable,        // allow to handle the input decoded packet
    // Outputs
    output logic                    rob_full,     
    output logic                    rs_alu_full,
    output logic                    rs_mul_full,
    output logic                    rs_mem_full,
    output logic                    rs_branch_full,
    output logic                    result_direction,       // branch is actually taken or not
    output logic                    result_enable,   
    output logic  [`XLEN-1:0]       result_PC,              // branch target address that is resolved
    output logic  [`XLEN-1:0]       prev_branch_PC,         // PC of branch that is resolved
);

    logic                           fu_opa_ready;
    logic                           fu_opb_ready;
    logic [`XLEN-1:0]               fu_opa_value;
    logic [`XLEN-1:0]               fu_opb_value;
    logic [`XLEN-1:0]               fu_offset;

    always_comb begin
		fu_opa_value = `XLEN'hdeadfbac;
        fu_opa_ready = 1'b1;
		case (id_packet.opa_select)
			OPA_IS_RS1: begin 
                fu_opa_value = opa_value; 
                fu_opa_ready = opa_ready;
            end
			OPA_IS_NPC:  fu_opa_value = id_packet.NPC;
			OPA_IS_PC:  fu_opa_value = id_packet.PC;
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
    RS_ALU_PACKET            rs_alu_packet;       // rs -> alu
    logic [`ROB_LEN-1:0]     rob_idx;            // rs -> alu

    // ALU OUTPUTS
    logic [`XLEN-1:0]       alu_value;                  // broadcasting to top_level
    logic                   alu_valid;                  // broadcasting to top_level
    logic [`PRF_LEN-1:0]    alu_prf_entry;              // alu->prf
    logic                   alu_dest_prf_valid;         // alu->rs
    logic [`ROB_LEN-1:0]    alu_rob_entry;              // alu->rob

    // MUL OUTPUTS
    logic [`XLEN-1:0]            mul_value;
    logic                        mul_valid;
    logic [`PRF_LEN-1:0]         mul_prf_entry;
    logic [`ROB_LEN-1:0]         mul_rob_entry;
    RS_MUL_PACKET                rs_mul_packet;

    // BRANCH OUTPUTS
	logic                        br_direction;      // branch direction 0 NT 1 T
	logic [`XLEN-1:0]            br_target_PC;      // branch target PC = PC+offset
    logic                        br_valid;
    logic [`PRF_LEN-1:0]         br_prf_entry;
    logic [`ROB_LEN-1:0]         br_rob_entry;
    RS_BRANCH_PACKET             rs_branch_packet;

    // CDB OUTPUTS
    logic                   cdb_broadcast_valid;  //
    logic [`ROB_LEN-1:0]    cdb_rob_entry;
    logic [`PRF_LEN-1:0]    cdb_dest_preg_idx;
    logic                   cdb_mis_pred;
    logic                   cdb_result;
    logic [`FU_NUM-1:0]     fu_free_list;

    // ROB INPUTS

    // PRF INPUTS

    // RAT INPUTS
    logic                   rat_enable;
    assign rat_enable = (id_packet.dest_areg_idx != `ZERO_REG)&&id_packet.valid;


    // RRAT INPUTS
    logic                   rrat_enable;
    assign rrat_enable = commit_valid;

    // RS INPUTS

    .enable(id_packet.fu_type == ALU)

    // Execution units input
    logic                        alu_enable, mul_enable, branch_enable;
    
	logic                        cdb_broadcast_alu, cdb_broadcast_mul;
   
  
  


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
        .enable(rrat_enable),                                       // rob ???
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
    //                    R O B                     //
    //                                              //
    //////////////////////////////////////////////////

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
        .clock(clock),                           // top level
        .reset(reset),                           // top level
        .opa_preg_idx(opa_preg_idx),             // rat
        .opb_preg_idx(opb_preg_idx),             // rat
        .dispatch_enable(rat_enable),            // ???
        .rrat_prev_reg_idx(rrat_prev_preg_idx),  // rrat
        .commit_mis_pred(mis_pred_is_head),      // rob
        .commit_valid(commit_valid),             // rob
        .rrat_free_backup(rrat_free_backup),     // rrat
        .rrat_valid_backup(rrat_valid_backup),   // rrat
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
    //                   R S _ A L U                //
    //                                              //
    //////////////////////////////////////////////////

    rs_alu rs_alu0(
        //inputs
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .enable(id_packet.fu_type == ALU),
        .opa_preg_idx(opa_preg_idx),
        .opb_preg_idx(opb_preg_idx),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .dest_preg_idx(prf_free_preg_idx),
        .rob_idx(rob_tail),
        .alu_func(id_packet.alu_func),
        
        .commit_mis_pred(mis_pred_is_head),
        
        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result),

        //outputs
        .rs_alu_packet(rs_alu_packet),
        .rs_alu_out_valid(rs_alu_out_valid),
        .rs_alu_full(rs_alu_full)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                     A L U                    //
    //                                              //
    //////////////////////////////////////////////////

    alu alu0(
        //input
        .rs_alu_packet(rs_alu_packet),
        .alu_enable(alu_enable),
        .cdb_broadcast_alu(cdb_broadcast_alu),
        //output
        .alu_value(alu_value),
        .alu_valid(alu_valid),
        .alu_dest_prf_entry(alu_prf_entry),
        .alu_rob_entry(alu_rob_entry)
    )

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
        .enable(id_packet.fu_type == MUL),
        .opa_preg_idx(opa_preg_idx),
        .opb_preg_idx(opb_preg_idx),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .dest_preg_idx(prf_free_preg_idx),
        .rob_idx(rob_tail),
        .mul_func(id_packet.alu_func),
        
        .commit_mis_pred(mis_pred_is_head),

        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result),

        //outputs
        .rs_mul_packet(rs_mul_packet),
        .rs_mul_out_valid(rs_mul_out_valid),
        .rs_mul_full(rs_mul_full)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                      M U L                    //
    //                                              //
    //////////////////////////////////////////////////

    mult2cdb mult2cdb0(
        //input
        .clock(clock),
        .reset(reset),
        .rs_mul_packet(rs_mul_packet),
        .mul_enable(mul_enable),
        .cdb_broadcast_mul(cdb_broadcast_alu),
        //output
        .mul_value(mul_value),
        .mul_valid(mul_valid),
        .mul_prf_entry(mul_prf_entry),
        .mul_rob_entry(mul_rob_entry)
    )

    //////////////////////////////////////////////////
    //                                              //
    //                   R S _ M E M                //
    //                                              //
    //////////////////////////////////////////////////

    rs_mem rs_mem0(
        //inputs
        .clock(clock),
        .reset(reset),
        .PC(id_packet.PC),
        .enable(id_packet.fu_type == MEM),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .offset(fu_offset),
        .dest_preg_idx(prf_free_preg_idx),
        .rob_idx(rob_tail),
        .rd_mem(id_packet.rd_mem),
        .wr_mem(id_packet.wr_mem),
        
        .commit_mis_pred(mis_pred_is_head),

        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result),

        //outputs
        .rs_mem_packet(rs_mem_packet),
        .rs_mem_out_valid(rs_mem_out_valid),
        .rs_mem_full(rs_mem_full)
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
        .enable(id_packet.fu_type == BRANCH),
        .opa_ready(fu_opa_ready),
        .opa_value(fu_opa_value),
        .opb_ready(fu_opb_ready),
        .opb_value(fu_opb_value),
        .offset(fu_offset),
        .dest_preg_idx(prf_free_preg_idx), 
        .rob_idx(rob_tail),
        .cond_branch(id_packet.cond_branch),
        .uncond_branch(id_packet.uncond_branch),
        
        .commit_mis_pred(mis_pred_is_head),

        .cdb_dest_preg_idx(cdb_dest_preg_idx),
        .cdb_broadcast_valid(cdb_broadcast_valid),
        .cdb_value(cdb_result),

        //outputs
        .rs_branch_packet(rs_branch_packet),
        .rs_branch_out_valid(rs_branch_out_valid),
        .rs_branch_full(rs_branch_full)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                      BRCOND                  //
    //                                              //
    //////////////////////////////////////////////////

    branch branch0(
	.clock(clock),
    .reset(reset),
    .branch_enable(branch_enable),
	.rs_branch_packet(rs_branch_packet),
	.cdb_broadcast_alu(cdb_broadcast_alu),

	.br_cond(br_cond),      // branch direction 0 NT 1 T
	.br_target_PC(br_target_PC), // branch target PC = PC+offset
    .br_valid(br_valid),
    .br_prf_entry(br_prf_entry),
    .br_rob_entry(br_rob_entry)
)

endmodule