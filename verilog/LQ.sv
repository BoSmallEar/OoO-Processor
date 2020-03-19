parameter LQ_CAPACITY = 8;
parameter LQ_IDX_LEN = 3;

typedef struct packed {
    logic [`XLEN-1:0] address;
    logic [LQ_IDX_LEN-1:0] age;
} LQ_ENTRY;

typedef struct packed {
    LQ_ENTRY    [LQ_IDX_LEN-1:0]   entries;
    logic       [LQ_IDX_LEN-1:0]    head;
    logic       [LQ_IDX_LEN-1:0]    tail;
} LOAD_QUEUE;

module load_queue (
    input   clock,
    input   reset,
    input   enable,
    input   store_position,
    input   age,
    input   sq_head,
    input   [3:0]               mem2LQ_response,   

    output logic full,
    output logic flush,
 
     output  logic [`XLEN-1:0]           current_load_address
);
    LOAD_QUEUE LQ;
    logic [LQ_IDX_LEN-1:0]  counter;
    logic full;
    logic younger;

    for (int i=0; i < LQ_CAPACITY-1;i++) begin
        if(LQ.entries[i].address==store_position)
    end
    assign full = counter==lQ_CAPACITY;
    assign current_load_address = (counter==0)? 0: LQ.entries[LQ.head].address;
  
    always_ff @(posedge clock) begin
        if (reset) begin
            LQ.head <= `SD 0;
            LQ.tail <= `SD 0;  //points to empty position
            counter <= `SD 0;
        end

        if (enable) begin
            LQ.entries[tail].address <= `SD load_address;
            LQ.entries[tail].age <= `SD age;
            LQ.tail <= `SD (LQ.tail == `LQ_CAPACITY-1)? 0: LQ.tail + 1;
        end 
        if (mem2LQ_response) begin
            counter <= `SD counter - 1;
            LQ.head <= `SD (LQ.head == `LQ_CAPACITY-1)? 0: LQ.head + 1;
        end
        if (enable && ~ mem2LQ_response)   counter <= `SD counter + 1;
        if (~enable && mem2LQ_response)    counter <= `SD counter - 1;
        if (younger) flush <= `SD 1;
    end

endmodule
