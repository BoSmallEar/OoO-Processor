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

extern void rob_print_header(int head, int tail, int commit_valid);
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
// Correct Outputs
logic [4:0]                 correct_rob_commit_dest_areg_idx;
logic [`PRF_LEN-1:0]        correct_rob_commit_dest_preg_idx;
logic [`ROB_LEN-1:0]        correct_rob_tail;
logic                       correct_rob_full;
logic                       correct_commit_valid;           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
logic                       correct_mis_pred_is_head;
// Else
int i;
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

task compare_correct;
    input                                clock; 
    input [`XLEN-1:0]                    PC;
    input                                dispatch_enable;        // not only depend on rob_full, (e.g. invalid instr)
    input                                execution_finished;     // make executed_rob_entry valid
    input [4:0]                          dest_areg_idx;
    input [`PRF_LEN-1:0]                 prf_free_preg_idx;
    input [`ROB_LEN-1:0]                 executed_rob_entry;
    input                                cdb_mis_pred;
    //Outputs                   
    input [4:0]                          rob_commit_dest_areg_idx;
    input [`PRF_LEN-1:0]                 rob_commit_dest_preg_idx;
    input [`ROB_LEN-1:0]                 rob_tail;
    input                                rob_full;
    input                                commit_valid;           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
    input                                mis_pred_is_head;
    // Correct Outputs
    input [4:0]                          correct_rob_commit_dest_areg_idx;
    input [`PRF_LEN-1:0]                 correct_rob_commit_dest_preg_idx;
    input [`ROB_LEN-1:0]                 correct_rob_tail;
    input                                correct_rob_full;
    input                                correct_commit_valid;           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
    input                                correct_mis_pred_is_head;
    begin
            // Check the answer...
            if(rob_commit_dest_areg_idx == correct_rob_commit_dest_areg_idx && rob_commit_dest_preg_idx == correct_rob_commit_dest_preg_idx && rob_tail == correct_rob_tail && rob_full == correct_rob_full && commit_valid == correct_commit_valid && mis_pred_is_head == correct_mis_pred_is_head)
            begin
                // "empty" cases are legal, since the begin/end
                // block is consuming the true if-branch
            end else begin
                $display("@@@ Incorrect at time %4.0f", $time);
                $display("@@@ Time:%4.0f clock:%b PC:%h dispatch_enable:%h execution_finished:%b dest_areg_idx:%h prf_free_preg_idx:%b executed_rob_entry:%b cdb_mis_pred:%b", $time, clock, PC, dispatch_enable, execution_finished, dest_areg_idx, prf_free_preg_idx, executed_rob_entry, cdb_mis_pred);
                $display("@@@ user output: rob_commit_dest_areg_idx:%h rob_commit_dest_preg_idx:%h rob_tail:%b rob_full:%b commit_valid:%b mis_pred_is_head:%b",rob_commit_dest_areg_idx, rob_commit_dest_preg_idx, rob_tail, rob_full, commit_valid, mis_pred_is_head);
                $display("@@@ correct output: rob_commit_dest_areg_idx:%h rob_commit_dest_preg_idx:%h rob_tail:%b rob_full:%b commit_valid:%b mis_pred_is_head:%b",correct_rob_commit_dest_areg_idx, correct_rob_commit_dest_preg_idx, correct_rob_tail, correct_rob_full, correct_commit_valid, correct_mis_pred_is_head);
                $finish;
            end

            // What doesn't this function test that it probably should?
    end
endtask



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
    
    $display("INPUTS:");
    rob_print_input({31'h0, reset}, PC, {31'h0, execution_finished}, {31'h0, dispatch_enable}, {27'h0, dest_areg_idx}, {{(32-`PRF_LEN){1'b0}}, prf_free_preg_idx}, 
                    {{(32-`ROB_LEN){1'b0}}, executed_rob_entry}, {31'h0, cdb_mis_pred});
    $display("OUTPUTS:");
    rob_print_header({{(32-`ROB_LEN){1'b0}}, rob_head}, {{(32-`ROB_LEN){1'b0}}, rob_tail},{31'h0, commit_valid});
    $display("ROB:");
    for (i = 0; i < `ROB_SIZE; i++) begin
        rob_print(i, rob_packets[i].PC, {31'h0, rob_packets[i].executed}, {{(32-`PRF_LEN){1'b0}},rob_packets[i].dest_preg_idx},
                  {27'h0, rob_packets[i].dest_areg_idx}, {31'h0, rob_packets[i].rob_mis_pred}, {{(32-`ROB_LEN){1'b0}}, rob_head}, {{(32-`ROB_LEN){1'b0}}, rob_tail});
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

    @(negedge clock);
    print_rob(rob_packets0,rob_head,rob_tail,clock,PC,dispatch_enable,dest_areg_idx,prf_free_preg_idx,executed_rob_entry,cdb_mis_pred,commit_valid);
 

   /*
    // Random Tests
    @(negedge clock);
    for (i=0; i <= 99; i=i+1) begin
        for (j=0; j <= 99 ; j=j+1) begin
            A = {$random,$random}; // What's up with this syntax?
            B = {$random,$random};
            #1
            compare_correct(A, B, SUM, C_IN, C_OUT);
            @(negedge clock);
        end
    end
*/

    rob_print_close();
// DON'T FORGET TO FINISH THE SIMULATION
    $display("\nENDING TESTBENCH: SUCCESS!\n");
    $finish;

end

endmodule

`endif
