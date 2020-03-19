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

`define CLOCK_PERIOD 30

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

    // prf outputs (debug)
    logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values;
    logic [`PRF_SIZE-1:0]                 prf_free;
    logic [`PRF_SIZE-1:0]                 prf_valid;
    logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
    logic [`PRF_LEN-1:0]                  free_preg_queue_head;
    logic [`PRF_LEN-1:0]                  free_preg_queue_tail;
    EXCEPTION_CODE processor_error_status;


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
        , .prf_values(prf_values)
        , .prf_free(prf_free)
        , .prf_valid(prf_valid)
        , .free_preg_queue(free_preg_queue)
        , .free_preg_queue_head(free_preg_queue_head)
        , .free_preg_queue_tail(free_preg_queue_tail)
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

    $display("prf_index    prf_value    valid    free    ");
    for (int i = 0; i < `PRF_SIZE; i++) begin
        $display("%d        %d           %d        %d    ", i, prf_values[i], prf_valid[i], prf_free[i]);
    end
endtask


    // Set up the clock to tick, notice that this block inverts clock every 5 ticks,
    // so the actual period of the clock is 10, not 5.
    always begin
        #(`CLOCK_PERIOD/2.0);
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
            print_prf(prf_values,prf_free,prf_valid,free_preg_queue,free_preg_queue_head,free_preg_queue_tail);
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
                #100 $finish;
            end
            debug_counter <= debug_counter + 1;
        end  // if(reset)   
    end 
    // $display("\nENDING TESTBENCH: SUCCESS!\n");
    // $finish;    

endmodule

`endif
