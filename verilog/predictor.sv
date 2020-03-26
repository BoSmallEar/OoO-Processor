`ifndef __PREDICTOR_V__
`define __PREDICTOR_V__
`timescale 1ns/100ps

module predictor(
    // current instruction
	input                   clock,                  // system clock
	input                   reset,                  // system reset 
	input   [`XLEN-1:0]     PC,                     // PC of branch to be predicted 
    // resolved branch: updates on history tables

    input                   result_taken,       // branch is actually taken or not 
    input                   result_local_taken,
    input                   result_global_taken,
    input   [`XLEN-1:0]     result_PC,                 // resolved branch's own PC 
    input                   result_cond_branch,        // if the result instr is a cond branch for updating the history table
    
    // output 
    output  logic tournament_taken,                // result of the predictor : whether taken or not 
    output  logic local_taken,
    output  logic global_taken
);  

    local_predictor #( 
        .local_offset_length(8), 
        .local_offset_pow(256), 
        .local_history_length(8),
        .local_history_pow(256))
        local_predictor0(
            .clock(clock),                  // system clock
            .reset(reset),                  // system reset
            .PC(PC),                     // PC of branch to be predicted
            // resolved branch: updates on history tables
            .result_taken(result_taken),       // branch is actually taken or not 
            .result_PC(result_PC),    
            .result_cond_branch(result_cond_branch),

            .taken(local_taken)
    );

    global_predictor #( 
        .global_history_length(8), 
        .global_history_pow(256))
        global_predictor0(
            .clock(clock),                  // system clock
            .reset(reset),                  // system reset
            .PC(PC),                     // PC of branch to be predicted
            // resolved branch: updates on history tables
            .result_taken(result_taken),       // branch is actually taken or not 
            .result_PC(result_PC),   
            .result_cond_branch(result_cond_branch), 

            .taken(global_taken)
    );


    // tournament selector 
    // 

    tournament_selector tournament_selector0( 
        .clock(clock),                  // system clock
        .reset(reset),                  // system reset
        .PC(PC),                     // PC of branch to be predicted 
        .local_taken(local_taken),
        .global_taken(global_taken), 
    
        .result_taken(result_taken),       // branch is actually taken or not 
        .result_PC(result_PC),              // resolved branch target address
        .result_cond_branch(result_cond_branch),
        .result_local_taken(result_local_taken),
        .result_global_taken(result_global_taken),
    
        .taken(tournament_taken)
    ); 

endmodule


module tournament_selector( 
    input                   clock,               // system clock
	input                   reset,                  // system reset
	input   [`XLEN-1:0]     PC,                     // PC of branch to be predicted
    input                   local_taken,
    input                   global_taken, 
    input                   result_cond_branch,
    input                   result_taken,       // branch is actually taken or not 
    input                   result_local_taken,
    input                   result_global_taken,
    input   [`XLEN-1:0]     result_PC,              // resolved branch target address
    
    output                  taken
);
    parameter tournament_offset_length = 8;
    parameter tournament_offset_pow = 256;

    logic [tournament_offset_pow-1:0][1:0] tournament_prediction_table;
 
    assign taken = tournament_prediction_table[PC[tournament_offset_length+1:2]] > 2'b01 ? local_taken : global_taken;

    always_ff @(posedge clock) begin
        if (reset) begin
            int i;
            for (i=0; i<tournament_offset_pow; i++) begin
                tournament_prediction_table[i] <= `SD 2'b10; // initialize history as weakly favors local history 
            end
        end
        else begin 
            if (result_cond_branch) begin
                if (result_local_taken != result_global_taken) begin // if the prediction results are different
                    if (result_taken == result_local_taken && tournament_prediction_table[result_PC[tournament_offset_length+1:2]] != 2'b11) begin
                        tournament_prediction_table[result_PC[tournament_offset_length+1:2]] <= `SD tournament_prediction_table[result_PC[tournament_offset_length+1:2]] + 1'b1;
                    end 
                    else if (result_taken == result_global_taken && tournament_prediction_table[result_PC[tournament_offset_length+1:2]] != 2'b00) begin
                        tournament_prediction_table[result_PC[tournament_offset_length+1:2]] <= `SD tournament_prediction_table[result_PC[tournament_offset_length+1:2]] - 1'b1;
                    end
                end
            end
        end 
    end
endmodule

module local_predictor(
      // current instruction
	input                   clock,                  // system clock
	input                   reset,                  // system reset
	input   [`XLEN-1:0]     PC,                     // PC of branch to be predicted
    
    // resolved branch: updates on history tables
    input                   result_taken,       // branch is actually taken or not 
    input   [`XLEN-1:0]     result_PC,              // resolved branch target address
    input                   result_cond_branch,
    
    output  logic           taken
);

    parameter local_offset_length = 8;
    parameter local_offset_pow = 256;
    parameter local_history_length = 8;
    parameter local_history_pow = 256;

    logic [local_offset_pow-1:0][local_history_length-1:0] local_history_table;
    logic [local_history_pow-1:0][1:0] local_prediction_table;

    assign taken = local_prediction_table[local_history_table[PC[local_offset_length+1:2]]] > 2'b01;

    always_ff @(posedge clock) begin
        if (reset) begin
            int i,j;
            for (i=0; i<local_offset_pow; i++) begin
                local_history_table[i] <= `SD {local_offset_length{1'b0}}; // initialize history as all not taken
            end 
            for (j=0; j<local_history_pow; j++) begin
                local_prediction_table[j] <= `SD 2'b10; //initialize as weakly taken
            end
        end
        else if (result_cond_branch) begin
            local_history_table[result_PC[local_offset_length+1:2]] <= `SD {result_taken,local_history_table[result_PC[local_offset_length+1:2]][local_offset_length-1:1]};
            if (local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] != 2'b11 && result_taken) begin
                local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] <= `SD local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] + 1'b1;
            end
            else if (local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] != 2'b00 && !result_taken) begin 
                local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] <= `SD local_prediction_table[local_history_table[result_PC[local_offset_length+1:2]]] - 1'b1;
            end
        end
    end
endmodule


module global_predictor(
      // current instruction
	input                   clock,                  // system clock
	input                   reset,                  // system reset
	input   [`XLEN-1:0]     PC,                     // PC of branch to be predicted
    
    // resolved branch: updates on history tables
    input                   result_taken,       // branch is actually taken or not 
    input   [`XLEN-1:0]     result_PC,              // resolved branch target address
    input                   result_cond_branch,
    
    output  logic           taken
);

    parameter global_history_length = 8;
    parameter global_history_pow = 256;

    logic [global_history_pow-1:0][1:0] global_prediction_table;
    logic [global_history_length-1:0] global_history;
    logic [global_history_length-1:0] index_xor;

    assign index_xor = global_history ^ PC[`XLEN-1:`XLEN-global_history_length];
    assign taken     = global_prediction_table[index_xor] > 2'b01;

    always_ff @(posedge clock) begin
        if (reset) begin
            int i;
            global_history <= `SD {global_history_length{1'b0}};
            for (i=0; i<global_history_pow; i++) begin
                global_prediction_table[i] <= `SD 2'b10;
            end
        end
        else if (result_cond_branch) begin
            global_history <= `SD {result_taken, global_history[global_history_length-1:1]};
            if (global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] != 2'b11 && result_taken) begin
                global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] <= `SD global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] + 1'b1;
            end
            else if (global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] != 2'b00 && !result_taken) begin
                global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] <= `SD global_prediction_table[global_history ^ result_PC[`XLEN-1:`XLEN-global_history_length]] - 1'b1;
            end
        end
    end
endmodule
`endif