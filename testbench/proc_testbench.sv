//TESTBENCH FOR 64 BIT ADDER
//Class:    EECS470
//Specific:    Final project ROB testbench
//Description:    This file contains the testbench for the 64-bit adder.


// Note: This testbench is heavily commented for your benefit, please
//       read through and understand _what_ it is doing

// The testbench itself is a module, so declare it as such

`ifndef DEBUG
`define DEBUG
`endif


`timescale 1ns/100ps

module proc_testbench;

    logic clock;
    logic reset;
	logic [3:0]   mem2proc_response;         // Tag from memory about current request
	logic [63:0]  mem2proc_data;             // Data coming back from memory
	logic [3:0]   mem2proc_tag;              // Tag from memory about current reply
	
	logic [1:0]  proc2mem_command;    // command sent to memory
	logic [`XLEN-1:0] proc2mem_addr;  // Address sent to memory
	logic [63:0] proc2mem_data;       // Data sent to memory
	MEM_SIZE proc2mem_size;          // data size sent to memory

    logic                                 result_mis_pred;

    // from if_id_stage (debug)
	logic					btb_taken;
	logic	[`XLEN-1:0]		btb_target_PC;
	logic					tournament_taken;
	logic					local_taken;
	logic					global_taken;

    // prf outputs (debug)
    logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values;
    logic [`PRF_SIZE-1:0]                 prf_free;
    logic [`PRF_SIZE-1:0]                 prf_valid;
    logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
    logic [`PRF_LEN-1:0]                  free_preg_queue_head;
    logic [`PRF_LEN-1:0]                  free_preg_queue_tail;
    EXCEPTION_CODE processor_error_status;

    // rob outputs (debug)
    ROB_PACKET [`ROB_SIZE-1:0]            rob_packets;
    logic [`ROB_LEN-1:0]                  rob_head;
    logic [`ROB_LEN-1:0]                  rob_tail;
    
    // rat internal reg
    logic [31:0] [`PRF_LEN-1:0]     rat_packets;
    logic [`PRF_LEN-1:0]            opa_preg_idx;
    logic [`PRF_LEN-1:0]            opb_preg_idx;

    // fu opa, opb, offset assignment
    logic                                 fu_opa_ready;
    logic                                 fu_opb_ready;
    logic [`XLEN-1:0]                     fu_opa_value;
    logic [`XLEN-1:0]                     fu_opb_value;
    logic [`XLEN-1:0]                     fu_offset;

    // rrat internal reg
    logic [31:0] [`PRF_LEN-1:0]     rrat_packets; 

    // rs
    RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets;
    logic [`RS_ALU_LEN:0] rs_alu_counter;
    logic [`RS_ALU_SIZE-1:0] rs_alu_ex;    // goes to priority selector (data ready && FU free) 
    logic [`RS_ALU_SIZE-1:0] rs_alu_free;
    logic [`RS_ALU_LEN-1:0] rs_alu_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_ALU_LEN-1:0] rs_alu_ex_idx; 

    RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets;
    logic [`RS_BR_LEN:0] rs_branch_counter;
    logic [`RS_BR_SIZE-1:0] rs_branch_ex;     // goes to priority selector (data ready && FU free) 
    logic [`RS_BR_SIZE-1:0] rs_branch_free;
    logic [`RS_BR_LEN-1:0] rs_branch_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_BR_LEN-1:0] rs_branch_ex_idx;

    RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets;
    logic [`RS_MUL_LEN:0] rs_mul_counter;
    logic [`RS_MUL_SIZE-1:0] rs_mul_ex;     // goes to priority selector (data ready && FU free)
    logic [`RS_MUL_SIZE-1:0] rs_mul_free;
    logic [`RS_MUL_LEN-1:0] rs_mul_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx;

    RS_LB_PACKET [`RS_LB_SIZE-1:0]     rs_lb_packets;
    logic        [`RS_LB_LEN:0]        rs_lb_counter;
    logic        [`RS_LB_SIZE-1:0]     rs_lb_ex;
    logic        [`RS_LB_SIZE-1:0]     rs_lb_free;
    logic        [`RS_LB_LEN-1:0]      rs_lb_free_idx;
    logic        [`RS_LB_LEN-1:0]      rs_lb_ex_idx;

    RS_SQ_PACKET [`RS_SQ_SIZE-1:0]     rs_sq_packets;
    logic        [`RS_SQ_LEN:0]        rs_sq_counter;
    logic        [`RS_SQ_SIZE-1:0]     rs_sq_ex;
    logic        [`RS_SQ_SIZE-1:0]     rs_sq_free;
    logic        [`RS_SQ_LEN-1:0]      rs_sq_free_idx;
    logic        [`RS_SQ_LEN-1:0]      rs_sq_ex_idx;

    // Outputs of cdb
    logic [3:0]           module_select;
    logic                 cdb_broadcast_valid;
    logic [`XLEN-1:0]     cdb_result;
    logic [`PRF_LEN-1:0]  cdb_dest_preg_idx;
    logic [`ROB_LEN-1:0]  cdb_rob_idx;
    logic [`XLEN-1:0]     cdb_broadcast_inst_PC;
    logic                 cdb_br_direction;
    logic [`XLEN-1:0]     cdb_br_target_PC;
    logic                 cdb_mis_pred;
    logic                 cdb_local_pred_direction;
    logic                 cdb_global_pred_direction;

    // id packet
    ID_PACKET             id_packet_out;

    // Outputs of prf
    logic [`PRF_LEN-1:0]    prf_free_preg_idx;
    logic [`PRF_LEN-1:0]    dest_preg_idx;
    logic                   opa_ready;
    logic [`XLEN-1:0]       opa_value;
    logic                   opb_ready;
    logic [`XLEN-1:0]       opb_value;

    // Outputs of load store queue
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

    // Outputs of dcache
    DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks;
    LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0]   load_buffer;

    logic [63:0] debug_counter;

    processor processor0(

        .clock(clock),                     // System clock
        .reset(reset),                     // System reset
        .mem2proc_response(mem2proc_response),         // Tag from memory about current request
        .mem2proc_data(mem2proc_data),             // Data coming back from memory
        .mem2proc_tag(mem2proc_tag),              // Tag from memory about current reply
        
        .proc2mem_command(proc2mem_command),    // command sent to memory
        .proc2mem_addr(proc2mem_addr),  // Address sent to memory
        .proc2mem_data(proc2mem_data),       // Data sent to memory
        .proc2mem_size(proc2mem_size),           // data size sent to memory
        .processor_error_status(processor_error_status)
    `ifdef DEBUG
        , .btb_taken(btb_taken)
        , .btb_target_PC(btb_target_PC)
        , .tournament_taken(tournament_taken)
        , .local_taken(local_taken)
        , .global_taken(global_taken)

        , .result_mis_pred(result_mis_pred)
        , .prf_values(prf_values)
        , .prf_free(prf_free)
        , .prf_valid(prf_valid)
        , .free_preg_queue(free_preg_queue)
        , .free_preg_queue_head(free_preg_queue_head)
        , .free_preg_queue_tail(free_preg_queue_tail)
        , .rob_packets(rob_packets)
        , .rob_head(rob_head)
        , .rob_tail(rob_tail)
        , .rat_packets(rat_packets)
        , .rrat_packets(rrat_packets)

        , .opa_preg_idx(opa_preg_idx)
        , .opb_preg_idx(opb_preg_idx)

        , .fu_opa_ready(fu_opa_ready)
        , .fu_opb_ready(fu_opb_ready)
        , .fu_opa_value(fu_opa_value)
        , .fu_opb_value(fu_opb_value)
        , .fu_offset(fu_offset)

        , .rs_alu_packets(rs_alu_packets)
        , .rs_alu_counter(rs_alu_counter)
        , .rs_alu_ex(rs_alu_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_alu_free(rs_alu_free)
        , .rs_alu_free_idx(rs_alu_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_alu_ex_idx(rs_alu_ex_idx) 

        , .rs_mul_packets(rs_mul_packets)
        , .rs_mul_counter(rs_mul_counter)
        , .rs_mul_ex(rs_mul_ex) 
        , .rs_mul_free(rs_mul_free)
        , .rs_mul_free_idx(rs_mul_free_idx)
        , .rs_mul_ex_idx(rs_mul_ex_idx)

        , .rs_branch_packets(rs_branch_packets)
        , .rs_branch_counter(rs_branch_counter)
        , .rs_branch_ex(rs_branch_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_branch_free(rs_branch_free)
        , .rs_branch_free_idx(rs_branch_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_branch_ex_idx(rs_branch_ex_idx) 

        , .rs_lb_packets(rs_lb_packets)
        , .rs_lb_counter(rs_lb_counter)
        , .rs_lb_ex(rs_lb_ex)
        , .rs_lb_free(rs_lb_free)
        , .rs_lb_free_idx(rs_lb_free_idx)
        , .rs_lb_ex_idx(rs_lb_ex_idx)

        , .rs_sq_packets(rs_sq_packets)
        , .rs_sq_counter(rs_sq_counter)
        , .rs_sq_ex(rs_sq_ex)
        , .rs_sq_free(rs_sq_free)
        , .rs_sq_free_idx(rs_sq_free_idx)
        , .rs_sq_ex_idx(rs_sq_ex_idx)

        // cdb output
        , .cdb_broadcast_valid(cdb_broadcast_valid)         
        , .module_select(module_select)               
        , .cdb_dest_preg_idx(cdb_dest_preg_idx)         
        , .cdb_rob_idx(cdb_rob_idx)
        , .cdb_result(cdb_result)
        , .cdb_broadcast_inst_PC(cdb_broadcast_inst_PC)       
        , .cdb_br_direction(cdb_br_direction)                 
        , .cdb_br_target_PC(cdb_br_target_PC)                 
        , .cdb_mis_pred(cdb_mis_pred)                         
        , .cdb_local_pred_direction(cdb_local_pred_direction)
        , .cdb_global_pred_direction(cdb_global_pred_direction)

        // id packet
        , .id_packet_out(id_packet_out)

        // Outputs of prf
        , .prf_free_preg_idx(prf_free_preg_idx)
        , .dest_preg_idx(dest_preg_idx)
        , .opa_ready(opa_ready)
        , .opa_value(opa_value)
        , .opb_ready(opb_ready)
        , .opb_value(opb_value)

        // Outputs of load store queue
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

        // Outputs of dcache
        , .dcache_blocks(dcache_blocks)
        , .load_buffer(load_buffer)
    `endif
    );


	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif
		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);


task print_prf;
    input [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values;
    input [`PRF_SIZE-1:0]                 prf_free;
    input [`PRF_SIZE-1:0]                 prf_valid;
    input [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
    input [`PRF_LEN-1:0]                  free_preg_queue_head;
    input [`PRF_LEN-1:0]                  free_preg_queue_tail;

    $display("==================== PRF ====================");
    $display("|prf_idx |prf_value       |valid   |free    |");
    for (int i = 0; i < `PRF_SIZE; i++) begin
        $display("|%8d|%16d|%8d|%8d|", i, prf_values[i], prf_valid[i], prf_free[i]);
    end
    $display("=============================================");
endtask

task print_rob;
    input ROB_PACKET [`ROB_SIZE-1:0]      rob_packets;
    input            [`ROB_LEN-1:0]       rob_head;
    input            [`ROB_LEN-1:0]       rob_tail;

    $display("=================== ROB ==================");
    $display("|rob_idx |PC      |executed|dest_preg_idx|");
    for (int i = 0; i < `ROB_SIZE; i++) begin
        if (rob_head == i && rob_tail == i)
            $display("|%8d|%8d|%8d|%13d| <- HEAD & TAIL", i, rob_packets[i].PC, rob_packets[i].executed, rob_packets[i].dest_preg_idx);
        else if (rob_head == i)
            $display("|%8d|%8d|%8d|%13d| <- HEAD", i, rob_packets[i].PC, rob_packets[i].executed, rob_packets[i].dest_preg_idx);
        else if (rob_tail == i)
            $display("|%8d|%8d|%8d|%13d| <- TAIL", i, rob_packets[i].PC, rob_packets[i].executed, rob_packets[i].dest_preg_idx);
        else
            $display("|%8d|%8d|%8d|%13d|", i, rob_packets[i].PC, rob_packets[i].executed, rob_packets[i].dest_preg_idx);
    end
    $display("==========================================");
endtask

task print_rat;
    input logic [31:0] [`PRF_LEN-1:0]     rat_packets;
    input logic [`PRF_LEN-1:0]            opa_preg_idx;
    input logic [`PRF_LEN-1:0]            opb_preg_idx;

    $display("======= RAT =======");
    $display("|rat_idx |preg_idx|");
    for (int i = 0; i < 32; i++) begin
        $display("|%8d|%8d|", i, rat_packets[i]);
    end
    $display("--------");
    $display("opa_preg_idx: %d", opa_preg_idx);
    $display("opb_preg_idx: %d", opb_preg_idx);
    $display("===================");
endtask

task print_rrat;
    input logic [31:0] [`PRF_LEN-1:0]     rrat_packets;

    $display("====== RRAT =======");
    $display("|rrat_idx|preg_idx|");
    for (int i = 0; i < 32; i++) begin
        $display("|%8d|%8d|", i, rrat_packets[i]);
    end
    $display("===================");
endtask

task print_rs;
    input RS_ALU_PACKET [`RS_ALU_SIZE-1:0]   rs_alu_packets;
    input logic [`RS_ALU_SIZE-1:0]           rs_alu_free;
    input RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets;
    input logic [`RS_BR_SIZE-1:0]            rs_branch_free;
    input RS_MUL_PACKET [`RS_MUL_SIZE-1:0]   rs_mul_packets;
    input logic [`RS_MUL_SIZE-1:0]           rs_mul_free;
    input RS_LB_PACKET [`RS_LB_SIZE-1:0]     rs_lb_packets;
    input logic        [`RS_LB_SIZE-1:0]     rs_lb_free;
    input RS_SQ_PACKET [`RS_SQ_SIZE-1:0]     rs_sq_packets;
    input logic        [`RS_SQ_SIZE-1:0]     rs_sq_free;

    $display("======================================= RS-ALU ========================================");
    $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |dest_preg_idx |rob_idx |free |");
    for (int i = 0; i < `RS_ALU_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%10d|%10d|%14d|%8d|%5d|", i,
        rs_alu_packets[i].PC,
        rs_alu_packets[i].opa_ready,
        rs_alu_packets[i].opa_value,
        rs_alu_packets[i].opb_ready,
        rs_alu_packets[i].opb_value,
        rs_alu_packets[i].dest_preg_idx,
        rs_alu_packets[i].rob_idx,
        rs_alu_free[i]);
    end
    $display("======================================= RS-MUL ========================================");
    $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |dest_preg_idx |rob_idx |free |");
    for (int i = 0; i < `RS_MUL_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%10d|%10d|%14d|%8d|%5d|", i,
        rs_mul_packets[i].PC,
        rs_mul_packets[i].opa_ready,
        rs_mul_packets[i].opa_value,
        rs_mul_packets[i].opb_ready,
        rs_mul_packets[i].opb_value,
        rs_mul_packets[i].dest_preg_idx,
        rs_mul_packets[i].rob_idx,
        rs_mul_free[i]);
    end
    $display("============================================= RS-BR ==============================================");
    $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |target_PC |pred_direction|rob_idx |free |");
    for (int i = 0; i < `RS_BR_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%10d|%10d|%10d|%14d|%8d|%5d|", i,
        rs_branch_packets[i].PC,
        rs_branch_packets[i].opa_ready,
        rs_branch_packets[i].opa_value,
        rs_branch_packets[i].opb_ready,
        rs_branch_packets[i].opb_value,
        rs_branch_packets[i].br_pred_target_PC,
        rs_branch_packets[i].br_pred_direction,
        rs_branch_packets[i].rob_idx,
        rs_branch_free[i]);
    end
    $display("================================================= RS-LB =================================================");
    $display("|rs_idx  |PC      |base_ready|base_value|offset  |lb_idx  |dest_preg_idx |rob_idx |mem_size|signed|free |");
    for (int i = 0; i < `RS_LB_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%8d|%8d|%14d|%8d|%8d|%6d|%5d|", i,
        rs_lb_packets[i].PC,
        rs_lb_packets[i].base_ready,
        rs_lb_packets[i].base_value,
        rs_lb_packets[i].offset,
        rs_lb_packets[i].lb_idx,
        rs_lb_packets[i].dest_preg_idx,
        rs_lb_packets[i].rob_idx,
        rs_lb_packets[i].mem_size,
        rs_lb_packets[i].load_signed,
        rs_lb_free[i]);
    end
    $display("=============================================== RS-SQ ================================================");
    $display("|rs_idx  |PC      |base_ready|base_value|offset  |src_ready |src_value |sq_idx|rob_idx |mem_size|free |");
    for (int i = 0; i < `RS_SQ_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%8d|%10d|%10d|%6d|%8d|%8d|%5d|", i,
        rs_sq_packets[i].PC,
        rs_sq_packets[i].base_ready,
        rs_sq_packets[i].base_value,
        rs_sq_packets[i].offset,
        rs_sq_packets[i].src_ready,
        rs_sq_packets[i].src_value,
        rs_sq_packets[i].sq_idx,
        rs_sq_packets[i].rob_idx,
        rs_sq_packets[i].mem_size,
        rs_sq_free[i]);
    end
    $display("==================================================================================================");
endtask

task print_predict;
	input logic					btb_taken;
	input logic	[`XLEN-1:0]		btb_target_PC;
	input logic					tournament_taken;
	input logic					local_taken;
	input logic					global_taken;
    $display("|btb_taken | btb_target_PC | tournament_taken | local_taken | global_taken |");
    $display("|%10d|%15d|%18d|%13d|%14d|", btb_taken, btb_target_PC, tournament_taken, local_taken, global_taken);
    $display("============================================================================");
endtask

task print_cdb;
    input logic [3:0]           module_select;
    input logic                 cdb_broadcast_valid;
    input logic [`XLEN-1:0]     cdb_result;
    input logic [`PRF_LEN-1:0]  cdb_dest_preg_idx;
    input logic [`ROB_LEN-1:0]  cdb_rob_idx;
    input logic [`XLEN-1:0]     cdb_broadcast_inst_PC;
    // branch
    input logic                 cdb_br_direction;
    input logic [`XLEN-1:0]     cdb_br_target_PC;
    input logic                 cdb_mis_pred;
    input logic                 cdb_local_pred_direction;
    input logic                 cdb_global_pred_direction;

    $display("========================= CDB =========================");
    case(module_select)
        4'b1000:  $display("module_select: ALU");
        4'b0100:  $display("module_select: MUL");
        4'b0010:  $display("module_select: MEM");
        4'b0001:  $display("module_select: BRANCH");
        default:  $display("module_select: EMPTY!!!");
    endcase
    $display("cdb_broadcast_inst_PC: %d", cdb_broadcast_inst_PC); 
    $display("cdb_broadcast_valid: %d", cdb_broadcast_valid);
    $display("cdb_result: %d", cdb_result);
    $display("cdb_dest_preg_idx: %d", cdb_dest_preg_idx);
    $display("cdb_rob_idx: %d", cdb_rob_idx);

    $display("cdb_br_target_PC: %d", cdb_br_target_PC);
    $display("cdb_br_direction: %d", cdb_br_direction);
    $display("cdb_mis_pred: %d", cdb_mis_pred);
    $display("cdb_local_pred_direction: %d", cdb_local_pred_direction);
    $display("cdb_global_pred_direction: %d", cdb_global_pred_direction);
    $display("========================================================");

endtask

task print_id_packet;
    input ID_PACKET         id_packet_out;
    $display("========================= ID PACKET =========================");
    $display("PC: %d", id_packet_out.PC);
    case(id_packet_out.fu_type)
        ALU:  $display("fu_type: ALU");
        MUL:  $display("fu_type: MUL");
        MEM:  $display("fu_type: MEM");
        BRANCH:  $display("fu_type: BRANCH");
        default:  $display("fu_type: EMPTY!!!");
    endcase
    $display("opa_areg_idx: %d", id_packet_out.opa_areg_idx);
    $display("opb_areg_idx: %d", id_packet_out.opb_areg_idx);
    $display("dest_areg_idx: %d", id_packet_out.dest_areg_idx);
    case(id_packet_out.opa_select)
	    OPA_IS_RS1  : $display("opa_select: OPA_IS_RS1");
	    OPA_IS_NPC  : $display("opa_select: OPA_IS_NPC");
	    OPA_IS_PC   : $display("opa_select: OPA_IS_PC");
	    OPA_IS_ZERO : $display("opa_select: OPA_IS_ZERO");
        default     : $display("opa_select: EMPTY!!!");
    endcase
    case(id_packet_out.opb_select)
        OPB_IS_RS2   :  $display("opb_select: OPB_IS_RS2");
        OPB_IS_I_IMM :  $display("opb_select: OPB_IS_I_IMM");
        OPB_IS_S_IMM :  $display("opb_select: OPB_IS_S_IMM");
        OPB_IS_B_IMM :  $display("opb_select: OPB_IS_B_IMM");
        OPB_IS_U_IMM :  $display("opb_select: OPB_IS_U_IMM");
        OPB_IS_J_IMM :  $display("opb_select: OPB_IS_J_IMM");
        default      :  $display("opb_select: EMPTY!!!");
    endcase
    $display("inst: %h", id_packet_out.inst);
    $display("valid: %d", id_packet_out.valid);
    $display("branch_prediction: %d", id_packet_out.branch_prediction);
    $display("local_taken: %d", id_packet_out.local_taken);
    $display("global_taken: %d", id_packet_out.global_taken);
    $display("=============================================================");
endtask

task print_prf_out;
    input logic [`PRF_LEN-1:0]    prf_free_preg_idx;
    input logic [`PRF_LEN-1:0]    dest_preg_idx;
    input logic                   opa_ready;
    input logic [`XLEN-1:0]       opa_value;
    input logic                   opb_ready;
    input logic [`XLEN-1:0]       opb_value;
    $display("========= PRF OUTPUTS ==========");
    $display("prf_free_preg_idx: %d", prf_free_preg_idx);
    $display("dest_preg_idx: %d", dest_preg_idx);
    $display("opa_ready: %d", opa_ready);
    $display("opa_value: %d", opa_value);
    $display("opb_ready: %d", opb_ready);
    $display("opb_value: %d", opb_value);
    $display("================================");
endtask

task print_rs_in_opab;
    input logic                              fu_opa_ready;
    input logic                              fu_opb_ready;
    input logic [`XLEN-1:0]                  fu_opa_value;
    input logic [`XLEN-1:0]                  fu_opb_value;
    input logic [`XLEN-1:0]                  fu_offset;
    $display("========= FU OPA OPB ==========");
    $display("fu_opa_ready: %d", fu_opa_ready);
    $display("fu_opa_value: %d", fu_opa_value);
    $display("fu_opb_ready: %d", fu_opb_ready);
    $display("fu_opb_value: %d", fu_opb_value);
    $display("fu_offset: %d", fu_offset);
    $display("================================");
endtask

task print_lsq;
    input STORE_QUEUE            SQ;
    input LOAD_BUFFER            LB;
    input logic                  sq_all_rsvd;
    input logic [`SQ_LEN-1:0]    sq_head;
    input logic [`SQ_LEN-1:0]    secure_age;
    input logic                  lb2sq_request_valid;
    input LB_ENTRY               lb2sq_request_entry;
    input logic [`SQ_LEN-1:0]    sq_counter;
    input logic                  sq_empty;

    input logic                  forward_match;
    input logic [`XLEN-1:0]      forward_data; 
    input logic [`SQ_LEN-1:0]    forward_match_idx;
    input logic [`XLEN-1:0]      forward_addr;
    input logic [`SQ_LEN-1:0]    forward_age;
    input logic MEM_SIZE         forward_mem_size;

    input logic                      none_selected;
    input logic [`LB_CAPACITY-1:0]   psel_gnt;
    input logic [`LB_LEN-1:0]        lq_free_idx;
    input logic                      lq_conflict;
    input logic [`LB_LEN-1:0]        lq_issue_idx;

    $display("lb2sq_request_valid: %d", lb2sq_request_valid);
    if (lb2sq_request_valid) begin
        $display("-------------------------------------------------------------------------------");
        $display("|PC      |addr    |rob_idx |age     |read_preg |resolved|mem_size|load_signed |");
        $display("|%8d|%8d|%8d|%8d|%10d|%8d|%8d|%12d|",
                lb2sq_request_entry.PC, 
                lb2sq_request_entry.addr, 
                lb2sq_request_entry.rob_idx,
                lb2sq_request_entry.age,
                lb2sq_request_entry.rd_preg,
                lb2sq_request_entry.rsvd,
                lb2sq_request_entry.mem_size,
                lb2sq_request_entry.load_signed);
    end
    $display("secure_age: %d", secure_age);
    $display("none_selected: %d", none_selected);
    $display("psel_gnt: %d", psel_gnt);
    $display("lq_free_idx: %d", lq_free_idx);
    $display("lq_conflict: %d", lq_conflict);
    $display("lq_issue_idx: %d", lq_issue_idx);
    $display("forward_match: %d", forward_match);
    if (forward_match) begin
        $display("forward_data: %d", forward_data);
        $display("forward_match_idx: %d", forward_match_idx);
        $display("forward_addr: %d", forward_addr);
        $display("forward_age: %d", forward_age);
        $display("forward_mem_size: %d", forward_mem_size);
    end
    $display("============================================ L B ============================================");
    $display("|PC      |addr    |rob_idx |age     |read_preg |resolved|mem_size|load_signed |free  |issue |");
    for (int i=0; i<`LB_CAPACITY; i++) begin
        $display("|%8d|%8d|%8d|%8d|%10d|%8d|%8d|%12d|%6d|%6d|",
                LB.entries[i].PC, 
                LB.entries[i].addr, 
                LB.entries[i].rob_idx,
                LB.entries[i].age,
                LB.entries[i].rd_preg,
                LB.entries[i].rsvd,
                LB.entries[i].mem_size,
                LB.entries[i].load_signed,
                LB.free_list[i],
                LB.issue_list[i]);
    end
    $display("sq_all_rsvd: %d", sq_all_rsvd);
    $display("sq_counter: %d", sq_counter);
    $display("sq_empty: %d", sq_empty);
    $display("======================= S Q =============================");
    $display("|PC      |addr    |rob_idx |data      |resolved|mem_size|");
    for (int i=0; i<`SQ_CAPACITY; i++) begin
        if (SQ.head == i && SSQ.tail == i)
            $display("|%8d|%8d|%8d|%10d|%8d|%8d| <- HEAD & TAIL", SQ.entries[i].PC, SQ.entries[i].addr, SQ.entries[i].rob_idx, SQ.entries[i].data, SQ.entries[i].rsvd, SQ.entries[i].mem_size);
        else if (SQ.head == i)
            $display("|%8d|%8d|%8d|%10d|%8d|%8d| <- HEAD", SQ.entries[i].PC, SQ.entries[i].addr, SQ.entries[i].rob_idx, SQ.entries[i].data, SQ.entries[i].rsvd, SQ.entries[i].mem_size);
        else if (SQ.tail == i)
            $display("|%8d|%8d|%8d|%10d|%8d|%8d| <- TAIL", SQ.entries[i].PC, SQ.entries[i].addr, SQ.entries[i].rob_idx, SQ.entries[i].data, SQ.entries[i].rsvd, SQ.entries[i].mem_size);
        else
            $display("|%8d|%8d|%8d|%10d|%8d|%8d|", SQ.entries[i].PC, SQ.entries[i].addr, SQ.entries[i].rob_idx, SQ.entries[i].data, SQ.entries[i].rsvd, SQ.entries[i].mem_size);
    end
    $display("=========================================================");
endtask

    // Set up the clock to tick, notice that this block inverts clock every 5 ticks,
    // so the actual period of the clock is 10, not 5.
    always begin
        #(`VERILOG_CLOCK_PERIOD/2.0);
        clock=~clock;
    end


    initial begin

		clock = 1'b0;
		reset = 1'b0;
		
		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);

        //Test Suite 1
        reset = 1'b1;
        @(posedge clock);
        @(posedge clock);

        $readmemh("program.mem", memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        `SD;

        reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime); 
    end
    
 
 
    always @(negedge clock) begin
        if(reset) begin
            $display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
                        $realtime);
            debug_counter <= 0;
        end else begin
            $display("///////////////////// cycle: %d    time: %t", debug_counter, $realtime);
            if (result_mis_pred) begin
                $display("mis_predict!!!");
            end
            print_cdb(module_select,
                cdb_broadcast_valid,
                cdb_result,
                cdb_dest_preg_idx,
                cdb_rob_idx,
                cdb_broadcast_inst_PC,
                cdb_br_direction,
                cdb_br_target_PC,
                cdb_mis_pred,
                cdb_local_pred_direction,
                cdb_global_pred_direction
            );
            print_id_packet(id_packet_out);
            print_prf_out(prf_free_preg_idx, dest_preg_idx, opa_ready, opa_value, opb_ready, opb_value);
            print_rs_in_opab(fu_opa_ready, fu_opb_ready, fu_opa_value, fu_opb_value, fu_offset);
            print_prf(prf_values,prf_free,prf_valid,free_preg_queue,free_preg_queue_head,free_preg_queue_tail);
            print_rob(rob_packets, rob_head, rob_tail);
            print_rat(rat_packets, opa_preg_idx, opb_preg_idx);
            print_rrat(rrat_packets);
            print_rs(rs_alu_packets, 
                rs_alu_free,
                rs_branch_packets, 
                rs_branch_free,
                rs_mul_packets,
                rs_mul_free,
                rs_lb_packets,
                rs_lb_free,
                rs_sq_packets,
                rs_sq_free);
            print_lsq(SQ, LB, sq_all_rsvd, sq_head, secure_age, lb2sq_request_valid, lb2sq_request_entry, sq_counter, sq_empty, forward_match, forward_data;, forward_match_idx, forward_addr, forward_age, forward_mem_size, none_selected, psel_gnt, lq_free_idx, lq_conflict, lq_issue_idx);
            print_predict(btb_taken, btb_target_PC, tournament_taken, local_taken, global_taken);
            // deal with any halting conditions
            if(processor_error_status != NO_ERROR || debug_counter > 50000000) begin
                $display("@@@ Unified Memory contents hex on left, decimal on right: ");  
                
                $display("@@  %t : System halted\n@@", $realtime);
                
                case(processor_error_status)
                    LOAD_ACCESS_FAULT:  
                        $display("@@@ System halted on memory error");
                    HALTED_ON_WFI:          
                        $display("@@@ System halted on WFI instruction");
                    ILLEGAL_INST:
                        $display("@@@ System halted on illegal instruction");
                    default: 
                        $display("@@@ System halted on unknown error code %x", 
                            processor_error_status);
                endcase
                $display("@@@\n@@"); 
                $finish;
            end
            debug_counter <= debug_counter + 1;
        end  // if(reset)   
    end 
    // $display("\nENDING TESTBENCH: SUCCESS!\n");
    // $finish;    

endmodule