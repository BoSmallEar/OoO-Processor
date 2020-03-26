parameter SQ_CAPACITY = 8;
parameter SQ_IDX_LEN = 3;

typedef struct packed {
    logic [`XLEN-1:0] address;
    logic [`XLEN-1:0] value;
    logic             resolved;
} SQ_ENTRY;

typedef struct packed {
    SQ_ENTRY    [SQ_CAPACITY-1:0]   entries;
    logic       [SQ_IDX_LEN-1:0]    head;
    logic       [SQ_IDX_LEN-1:0]    tail;
} STORE_QUEUE;

module store_queue (
    //  From ID packet
    input                       clock,
    input                       reset,
    input                       enable,         // Add new Store instruction
    input                       base,
    input                       no_offset,
    input   [`XLEN-1:0]         source_data,
    // From load instruction @execution/@decode
    input   [`XLEN-1:0]         load_address,
    input   [SQ_IDX_LEN-1:0]    load_age,  
    // From ALU
    input   [`XLEN-1:0]         alu2SQ_addr,
    input   [SQ_IDX_LEN-1:0]    alu2SQ_idx,
    // From Dcache
    input   [SQ_IDX_LEN-1:0]    Dcache2SQ_response,   
    // From ROB
    output  logic                       full,
    // Output to load instruction @execution/@decode
    output  logic [`XLEN-1:0]           forward_data,
    output  logic                       address_match,
    output  logic [SQ_IDX_LEN-1:0]      sq_tail,
    output  logic [SQ_IDX_LEN-1:0]      sq_head,
    output  logic [SQ_IDX_LEN-1:0]      avoid_flush_gap,
    // Output to D_cache
    output  logic [`XLEN-1:0]           head_address,
    output  logic [`XLEN-1:0]           head_source_data,
    output                              head_resolved
);

    STORE_QUEUE             SQ;
    logic [SQ_IDX_LEN:0]    counter;
    logic                   full;
    logic                   match;
    logic [`XLEN-1:0]       chosen_data;
    logic [SQ_IDX_LEN-1:0]      sq_tail;
    logic [SQ_IDX_LEN-1:0]      sq_head;

    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign full = counter==SQ_CAPACITY;
    assign head_address = (counter==0)? 0: SQ.entries[SQ.head].address;
    assign head_source_data = (counter==0)? 0:SQ.entries[SQ.head].value;
    assign head_resolved = SQ.entries[SQ.head].resolved;

    logic [SQ_IDX_LEN-1:0]      gap;
    /* To assist flush */
    always_comb begin
        if (SQ.head < SQ.tail) begin
            for (int i=SQ.tail-1; i>alu2SQ_idx; i--) begin
                if (SQ.entries[i].resolved&&alu2SQ_addr==SQ.entries[i].address) begin
                    gap = i-alu2SQ_idx;
                end
            end
        end
        else if (SQ.head >= SQ.tail) begin
            if (alu2SQ_idx < SQ.tail-1) begin
                for (i=alu2SQ_idx+1;i<SQ.tail; i++) begin
                    if (SQ.entries[i].resolved&&alu2SQ_addr==SQ.entries[i].address) begin
                        gap = i-alu2SQ_idx;
                    end
                end
            end
            else if (alu2SQ_idx >= SQ.head) begin
                for (i=alu2SQ_idx+1;i<SQ_CAPACITY; i++) begin
                    if (SQ.entries[i].resolved&&alu2SQ_addr==SQ.entries[i].address) begin
                        gap = i-alu2SQ_idx;
                    end
                end
                for (i=0;i<SQ.tail; i++) begin
                    if (SQ.entries[i].resolved&&alu2SQ_addr==SQ.entries[i].address) begin
                        gap = i+SQ_CAPACITY-1-alu2SQ_idx;
                    end
                end
            end
        end
    end
    /*------------------*/

    always_comb begin
        if (!full && SQ.head==SQ.tail) begin
            match = 0;
        end
        else if (SQ.head < SQ.tail && SQ.head < load_age) begin
            for (int i=SQ.head; i<=load_age-1; i++) begin
                if (SQ.entries[i].resolved&&load_address==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
        end
        else if (SQ.head >= SQ.tail && !(load_age<=SQ.head&&load_age>SQ.tail)) begin
            int i;
            i = (SQ_CAPACITY>load_age)?load_age:SQ_CAPACITY;       
            for (i=SQ.head; (i<SQ_CAPACITY)&&i(<load_age); i++) begin
                if (SQ.entries[i].resolved&&load_address==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
            for (i=0; (i<load_age)&&(i<SQ.tail); i++) begin
                if (SQ.entries[i].resolved&&load_address==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
        end
        else
            match = 0;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;  //points to empty position
            counter <= `SD 0;
            for(int i=0;i<SQ_CAPACITY;i++) SQ.entries[i].resolved <= `SD 0;
        end

        if (enable) begin 
            SQ.entries[tail].value <=`SD source_data;
            SQ.tail <= `SD (SQ.tail == `SQ_CAPACITY-1)? 0: SQ.tail + 1;
            if (no_offset)  begin
                SQ.entries[tail].address <=`SD base;
                SQ.entries[tail].resolved <=`SD 1;
            end
        end 

        if (Dcache2SQ_response==SQ.head) begin     // Retire
            SQ.entries[head].resolved <=`SD 0;
            SQ.head <= `SD (SQ.head == `SQ_CAPACITY-1)? 0: SQ.head + 1;
        end

        if (enable && ~ Dcache2SQ_response)   counter <= `SD counter + 1;
        if (~enable && Dcache2SQ_response)    counter <= `SD counter - 1;

        if (SQ.entries[alu2SQ_idx].resolved==0) begin
            SQ.entries[alu2SQ_idx].address <= `SD alu2SQ_addr;
            SQ.entries[alu2SQ_idx].resolved <=`SD 1;
            avoid_flush_gap <= `SD gap;
        end

        address_match <= `SD match;

        if (match)
            forward_data <=`SD chosen_data;
    end

endmodule
