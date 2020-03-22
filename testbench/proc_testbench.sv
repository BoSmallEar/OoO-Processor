//TESTBENCH FOR 64 BIT ADDER
//Class:    EECS470
//Specific:    Final project ROB testbench
//Description:    This file contains the testbench for the 64-bit adder.


// Note: This testbench is heavily commented for your benefit, please
//       read through and understand _what_ it is doing

// The testbench itself is a module, so declare it as such

`ifndef DEBUG
`define DEBUG

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

    // RS_FU_PACKET [`RS_MEM_SIZE-1:0] rs_mem_packets
    // logic [`RS_MEM_LEN:0] rs_mem_counter
    // logic [`RS_MEM_SIZE-1:0] rs_mem_ex 
    // logic [`RS_MEM_SIZE-1:0] rs_mem_free
    // logic [`RS_MEM_LEN-1:0] rs_mem_free_idx
    // logic [`RS_MEM_LEN-1:0] rs_mem_ex_idx

    RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets;
    logic [`RS_MUL_LEN:0] rs_mul_counter;
    logic [`RS_MUL_SIZE-1:0] rs_mul_ex;     // goes to priority selector (data ready && FU free)
    logic [`RS_MUL_SIZE-1:0] rs_mul_free;
    logic [`RS_MUL_LEN-1:0] rs_mul_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx;

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

    $display("======= RAT =======");
    $display("|rat_idx |preg_idx|");
    for (int i = 0; i < 32; i++) begin
        $display("|%8d|%8d|", i, rat_packets[i]);
    end
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
    input RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets;
    input RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets;
    input RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets;

    $display("======================================= RS-ALU ========================================");
    $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |dest_preg_idx |rob_idx |");
    for (int i = 0; i < `RS_ALU_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%10d|%10d|%14d|%8d|", i,
        rs_alu_packets[i].PC,
        rs_alu_packets[i].opa_ready,
        rs_alu_packets[i].opa_value,
        rs_alu_packets[i].opb_ready,
        rs_alu_packets[i].opb_value,
        rs_alu_packets[i].dest_preg_idx,
        rs_alu_packets[i].rob_idx);
    end
    // $display("======================================= RS-MUL ========================================");
    // $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |dest_preg_idx |rob_idx |");
    // for (int i = 0; i < `RS_ALU_SIZE; i++) begin
    //     $display("|%8d|%8d|%10d|%10d|%10d|%10d|%14d|%8d|", i,
    //     rs_mul_packets[i].PC,
    //     rs_mul_packets[i].opa_ready,
    //     rs_mul_packets[i].opa_value,
    //     rs_mul_packets[i].opb_ready,
    //     rs_mul_packets[i].opb_value,
    //     rs_mul_packets[i].dest_preg_idx,
    //     rs_mul_packets[i].rob_idx);
    // end
    $display("============================================= RS-BR ==============================================");
    $display("|rs_idx  |PC      |opa_ready |opa_value |opb_ready |opb_value |target_PC |pred_direction|rob_idx |");
    for (int i = 0; i < `RS_BR_SIZE; i++) begin
        $display("|%8d|%8d|%10d|%10d|%10d|%10d|%10d|%14d|%8d|", i,
        rs_branch_packets[i].PC,
        rs_branch_packets[i].opa_ready,
        rs_branch_packets[i].opa_value,
        rs_branch_packets[i].opb_ready,
        rs_branch_packets[i].opb_value,
        rs_branch_packets[i].br_pred_target_PC,
        rs_branch_packets[i].br_pred_direction,
        rs_branch_packets[i].rob_idx);
    end
    $display("==================================================================================================");
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
            print_prf(prf_values,prf_free,prf_valid,free_preg_queue,free_preg_queue_head,free_preg_queue_tail);
            print_rob(rob_packets, rob_head, rob_tail);
            print_rat(rat_packets);
            print_rrat(rrat_packets);
            print_rs(rs_alu_packets, rs_branch_packets, rs_mul_packets);
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

`endif
