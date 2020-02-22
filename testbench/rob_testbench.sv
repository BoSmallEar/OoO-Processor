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

extern void rob_print_header(int commit_valid);
extern void rob_print_cycles();
extern void rob_print_input(int reset, 
                            int PC,
                            int execution_finished,
                            int dispatch_enable,
                            int dest_areg_idx,
                            int prf_free_preg_idx,
                            int executed_rob_entry,
                            int cdb_mis_pred);
extern void rob_print(int entry,
                      int PC,
                      int executed,
                      int dest_areg,
                      int dest_preg,
                      int rob_mis_pred,
                      int head,
                      int tail);
extern void rob_print_close();

module rob_testbench;

//MODULE PARAMETERS:

// We need to define inputs and output for the module we wish to test.
// In general, inputs should be registers (since a register is a physical
// device that can hold state and can be wired from) and outputs should
// be wires (since we only need to read the value of the output, we have
// no desire or need to latch it)

// Strictly speaking, this is an asynchronous circuit, and thus we do not
// need a clock. We'll use one to delimit test cases, as it makes looking
// at the output much easier.
// Inputs
logic                       clock;
logic                       reset;
logic [`XLEN-1:0]           PC;
logic                       dispatch_enable;        // not only depend on rob_full, (e.g. invalid instr)
logic                       execution_finished;     // make executed_rob_entry valid
logic [4:0]                 dest_areg_idx;
logic [`PRF_LEN-1:0]        prf_free_preg_idx;
logic [`ROB_LEN-1:0]        executed_rob_entry;
logic                       cdb_mis_pred;
// Outputs
logic [4:0]                 rob_commit_dest_areg_idx;
logic [`PRF_LEN-1:0]        rob_commit_dest_preg_idx;
logic [`ROB_LEN-1:0]        rob_tail;
logic                       rob_full;
logic                       commit_valid;           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
logic                       mis_pred_is_head;
logic [`ROB_LEN-1:0]       rob_head;
logic                      rob_empty;
ROB_PACKET [`ROB_SIZE-1:0] rob_packets0;

// Else
int i;
int j;
logic  [`ROB_LEN-1:0]       random_rob_entry;
// Need a number? It's a testbench, we can do that! Conceptually these are
// much more like variables from C, and do not necessarily correlate to any
// physical hardware (thus they can only be used in testbenches)

// Now we declare an instance of the module we'd like to test, in this case
// the 64-bit full adder. We also wire in the signals declared above.
rob rob0(
    .clock(clock),
    .reset(reset),
    .PC(PC),
    .dispatch_enable(dispatch_enable),        // not only depend on rob_full, (e.g. invalid instr)
    .execution_finished(execution_finished),                    // make executed_rob_entry valid
    .dest_areg_idx(dest_areg_idx),
    .prf_free_preg_idx(prf_free_preg_idx),
    .executed_rob_entry(executed_rob_entry),
    .cdb_mis_pred(cdb_mis_pred),

    .rob_commit_dest_areg_idx(rob_commit_dest_areg_idx),
    .rob_commit_dest_preg_idx(rob_commit_dest_preg_idx),
    .rob_tail(rob_tail),
    .rob_full(rob_full),
    .commit_valid(commit_valid),             // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
    .mis_pred_is_head(mis_pred_is_head),
    .rob_head(rob_head),
    .rob_empty(rob_empty),
    .rob_packets(rob_packets0)
);



// "tasks" are verilog-speak for functions. These are really useful and help
// to save on a lot of repeated / duplicated work.

task print_rob;
    input ROB_PACKET [`ROB_SIZE-1:0] rob_packets;
    input [`ROB_LEN-1:0]           rob_head;
    input [`ROB_LEN-1:0]           rob_tail;
    input 		                   clock;
    input [`XLEN-1:0]	           PC;
    input 		                   dispatch_enable;
    input [4:0]		               dest_areg_idx;
    input [`PRF_LEN-1:0]           prf_free_preg_idx;
    input [`ROB_LEN-1:0]           executed_rob_entry;
    input 		                   cdb_mis_pred;
    input                          commit_valid;
    
    rob_print_input({31'h0, reset},
                    PC,
                    {31'h0, execution_finished},
                    {31'h0, dispatch_enable},
                    {27'h0, dest_areg_idx},
                    {{(32-`PRF_LEN){1'b0}},
                    prf_free_preg_idx},
                    {{(32-`ROB_LEN){1'b0}}, executed_rob_entry},
                    {31'h0, cdb_mis_pred});
    rob_print_header({31'h0, commit_valid});
    for (i = 0; i < `ROB_SIZE; i++) begin
        rob_print(i,
                  rob_packets[i].PC,
                  {31'h0, rob_packets[i].executed},
                  {{(32-`PRF_LEN){1'b0}}, rob_packets[i].dest_preg_idx},
                  {27'h0, rob_packets[i].dest_areg_idx},
                  {31'h0, rob_packets[i].rob_mis_pred},
                  {{(32-`ROB_LEN){1'b0}}, rob_head},
                  {{(32-`ROB_LEN){1'b0}}, rob_tail});
    end
endtask

// Set up the clock to tick, notice that this block inverts clock every 5 ticks,
// so the actual period of the clock is 10, not 5.
always begin
    #5;
    clock=~clock;
end



// Start the "real" testbench here. Initial is the beginning of simulated time.
initial begin

    // Monitors can be really useful, but for larger testbenches, they can
    // dump a huge amount of text to the screen.

    // Conceptually a monitor is a "magic" printf that will print itself
    // any time one of the signals changes.

    // Try uncommenting this monitor once and running the testbench...
    //$monitor("Time:%4.0f clock:%b A:%h B:%h CIN:%b SUM:%h COUT:%b", $time, clock, A, B, C_IN, SUM, C_OUT);

    // Recall that verilog has an "unknown" state (x) which every signal
    // starts at. In practice, most internal registers will get set by a
    // reset signal and you will only need to specify testbench signals here


    //Test Suite 1
    reset               = 1'b1;
    PC                  = 32'h0;
    dispatch_enable     = 1'b1;
    execution_finished  = 1'b0;
    dest_areg_idx       = 1'b1;
    prf_free_preg_idx   = 1'b0;
    executed_rob_entry  = `ROB_LEN'h0;
    cdb_mis_pred        = 1'b0;

    // Don't forget to initialize the clock! Otherwise that always block
    // above will just keep inverting "x" to "x".
    clock = 0;

    $display("STARTING TESTSUITE 1!");
    // Here, we present a method to test every possible input
    @(negedge clock);
    
    // Test 1
    @(negedge clock); 
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h4;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h0;
    cdb_mis_pred       = 1'b0;

    // Test 2
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h8;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b1;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h0;
    cdb_mis_pred       = 1'b0;


    // Test 3
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'hc;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b1;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h1;
    cdb_mis_pred       = 1'b1;

    // Test 4
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h10;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h1;
    cdb_mis_pred       = 1'b0;
    
    // Test 5
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h14;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b1;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h2;
    cdb_mis_pred       = 1'b0;

    // Test 6
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h18;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b1;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h3;
    cdb_mis_pred       = 1'b0;

    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    
    $display("FINISHING TESTSUITE 1!");

    $display("@@@");
    $display("@@@");
    $display("@@@");
      //Test Suite 2
    reset               = 1'b1;
    PC                  = 32'h0;
    dispatch_enable     = 1'b1;
    execution_finished  = 1'b0;
    dest_areg_idx       = 1'b1;
    prf_free_preg_idx   = 1'b0;
    executed_rob_entry  = `ROB_LEN'h0;
    cdb_mis_pred        = 1'b0;


    $display("STARTING TESTSUITE 2!");
    // Here, we present a method to test every possible input
    @(negedge clock);
    
    // Test 1
    @(negedge clock); 
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h4;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h0;
    cdb_mis_pred       = 1'b0;

    // Test 2
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h8;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h1;
    cdb_mis_pred       = 1'b0;


    // Test 3
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'hc;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h2;
    cdb_mis_pred       = 1'b1;

    // Test 4
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h10;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h2;
    cdb_mis_pred       = 1'b0;
    
    // Test 5
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h14;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h3;
    cdb_mis_pred       = 1'b0;

        // Test 6
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h18;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h3;
    cdb_mis_pred       = 1'b0;

        // Test 7
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h1c;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h3;
    cdb_mis_pred       = 1'b0;

        // Test 8
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h20;
    dispatch_enable    = 1'b1;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b1;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h0;
    cdb_mis_pred       = 1'b0;
    
        // Test 9
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h24;
    dispatch_enable    = 1'b0;
    execution_finished = 1'b1;
    dest_areg_idx      = 1'b0;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h0;
    cdb_mis_pred       = 1'b0;
 
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
    reset              = 1'b0;
    PC                 = 32'h24;
    dispatch_enable    = 1'b0;
    execution_finished = 1'b0;
    dest_areg_idx      = 1'b0;
    prf_free_preg_idx  = 1'b1;
    executed_rob_entry = `ROB_LEN'h1;
    cdb_mis_pred       = 1'b0;
 

    // Random Tests
    reset              = 1'b1;
    PC                 = 32'h0;
    for (j=0; j <= 1000; j++) begin
        @(negedge clock);
        print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
        reset       = 1'b0;
        PC          = $urandom;
        if (rob_full && ~commit_valid)
            // cannot dispatch new instruction
            dispatch_enable = 1'b0;
        else
            dispatch_enable = $urandom%2;
        
        dest_areg_idx = $urandom%32;
        prf_free_preg_idx = $urandom%`PRF_SIZE;
        random_rob_entry = $urandom%`ROB_SIZE;
        if ((random_rob_entry == rob_tail) && (~rob_full))
            executed_rob_entry = (rob_tail == `ROB_LEN'h0) ? `ROB_SIZE-1:rob_tail-1;
        else
            executed_rob_entry = random_rob_entry;
        execution_finished = ($urandom%5 !=1) | rob_packets0[executed_rob_entry].executed;
        cdb_mis_pred = ($urandom%100 == 1);
    end
    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);


    rob_print_close();
// DON'T FORGET TO FINISH THE SIMULATION
    $display("\nENDING TESTBENCH: SUCCESS!\n");
    $finish;

end

endmodule

`endif
