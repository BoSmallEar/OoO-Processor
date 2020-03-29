typedef struct packed {            
	logic [`XLEN-1:0]       PC;                
    logic [`XLEN-1:0]       addr;
    logic [`XLEN-1:0]       data;
    logic                   rob_idx;
    logic                   rsvd;
} SQ_ENTRY;

typedef struct packed {
    SQ_ENTRY    [`SQ_CAPACITY-1:0]   entries;
    logic       [`SQ_LEN-1:0]        head;
    logic       [`SQ_LEN-1:0]        tail;
} STORE_QUEUE;

typedef struct packed {            
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       forward_data;
    logic [4:0]             rd_preg;
    logic                   rob_idx;    
} FORWARD;

module store_queue (
    input                               clock,
    input                               reset,
    input                               sq_enable,       
    // From RS_SQ
    input                               rs_sq_out_valid,
    input                               rs_sq_packet,    
    // From load instruction
    input                               lb2sq_request_entry,
    // From Dcache
    input   [`SQ_LEN-1:0]               Dcache2SQ_response,   
    
    // Output to D_cache
    output  SQ_ENTRY                    sq_head_entry,
    output  LB_ENTRY                    lb2cache_request_entry,
    // Out to previous stage
    output  logic                       sq_full,
    // Output to load buffer
    output  logic                       sq_all_rsvd,
    output  logic                       sq_empty,
    output  logic [`SQ_LEN-1:0]         sq_tail,         // Also to MEM_RS 
    output  logic [`SQ_LEN-1:0]         sq_head,
    output  logic [`SQ_LEN-1:0]         oldest_unrsvd_sq_idx, 
    // To CDB
    output  logic                       forward_valid,
    output  FORWARD                     forward_pack,
);
    STORE_QUEUE                         SB;
    logic [`SQ_LEN:0]                   counter;
    logic                               sq_full, sq_empty;
    logic                               match;
    logic [`XLEN-1:0]                   forward_data;
    logic [`SQ_LEN-1:0]                 sq_tail;
    logic [`SQ_LEN-1:0]                 sq_head;
    logic [`SQ_LEN:0]                   unkwn_idx;
    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign sq_full = counter==`SQ_CAPACITY;
    assign sq_empty = counter==0;
    assign sq_head_entry = SQ.entries[head];

    // The valid range is [From old to young] :
    // If (SQ.head < SQ.tail || sq_empty)
    // HEAD -> TAIL
    // SQ.head >= SQ.tail
    // HEAD -> `SQ_CAPACITY-1 -> 0 -> TAIL
    always_comb begin
        // Compute the oldest_unrsvd_sq_idx
        if (sq_empty)
            unkwn_idx = `SQ_CAPACITY;
        else begin
            unkwn_idx = `SQ_CAPACITY;
            if (SQ.head < SQ.tail) begin
                for (int i=SQ.tail-1; i>=SQ.head;i--) begin
                    if (SQ.entries[i].rsvd==0)
                         unkwn_idx = i;
                end
            end
            else begin
                for (int i=SQ.tail-1; i>=0;i--) begin
                    if (SQ.entries[i].rsvd==0)
                         unkwn_idx = i;
                end
                for (int i=`SQ_CAPACITY-1; i>=SQ.head;i--) begin
                    if (SQ.entries[i].rsvd==0)
                         unkwn_idx = i;
                end
            end
        end
    end

    logic [`XLEN-1:0]       load_addr;
    logic [`SQ_LEN-1:0]     load_age;

    always_comb begin
        load_addr = lb2sq_request_entry.addr;
        load_age = lb2sq_request_entry.age;
        if (!sq_full && SQ.head==SQ.tail) begin
            match = 0;
        end
        else if (SQ.head < SQ.tail && SQ.head < load_age) begin
            for (int i=SQ.head; i<=load_age-1; i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    match = 1;
                    forward_data = SQ.entries[i].data;
                end
            end
        end
        else if (SQ.head >= SQ.tail && !(load_age<=SQ.head&&load_age>SQ.tail)) begin
            int i;
            i = (`SQ_CAPACITY>load_age)?load_age:`SQ_CAPACITY;       
            for (i=SQ.head; (i<`SQ_CAPACITY)&&i(<load_age); i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    match = 1;
                    forward_data = SQ.entries[i].data;
                end
            end
            for (i=0; (i<load_age)&&(i<SQ.tail); i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    match = 1;
                    forward_data = SQ.entries[i].data;
                end
            end
        end
        else
            match = 0;
    end

    FORWARD 4ward, forward_pack;
    always_comb begin
        if(match) begin
            4ward.PC = lb2sq_request_entry.PC;
            4ward.forward_data <=`SD forward_data;
            4ward.rd_preg <=`SD lb2sq_request_entry.rd_preg;
            4ward.rob_idx <=`SD lb2sq_request_entry.rob_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;
            counter <= `SD 0;
            for(int i=0;i<`SQ_CAPACITY;i++) begin
                SQ.entries[i].rsvd <= `SD 0;
            end 
            oldest_unrsvd_sq_idx <=`SD 0;
            sq_all_rsvd <=`SD 1;
            forward_valid <= `SD 0;
        end
        else begin
            sq_all_rsvd <=`SD (sq_empty || unkwn_idx==`SQ_CAPACITY);
            oldest_unrsvd_sq_idx <=`SD unkwn_idx[`SQ_LEN-1:0];

            // To add the new instruction with unknown data and addr
            if (sq_enable) begin 
                SQ.entries[tail].rsvd <= `SD 0;
                SQ.tail <= `SD (SQ.tail == `SQ_CAPACITY-1)? 0: SQ.tail + 1;
            end 

             // To resolve address and data for the specific entry
            if (rs_sq_out_valid&&SQ.entries[rs_sq_packet.sq_idx].rsvd==0) begin
                SQ.entries[rs_sq_packet.sq_idx].rsvd <=`SD 1;
                SQ.entries[rs_sq_packet.sq_idx].addr <= `SD rs_sq_packet.base_value + rs_sq_packet.offset;
                SQ.entries[rs_sq_packet.sq_idx].data <= `SD rs_sq_packet.src_value;
                SQ.entries[rs_sq_packet.sq_idx].rob_idx <= `SD rs_sq_packet.rob_idx;
                SQ.entries[rs_sq_packet.sq_idx].PC <= `SD rs_sq_packet.PC;
            end

            if (Dcache2SQ_response==SQ.entries[head].rob_idx) begin     // Retire
                SQ.entries[head].rsvd <=`SD 0;
                SQ.head <= `SD (SQ.head == `SQ_CAPACITY-1)? 0: SQ.head + 1;
            end

            if (sq_enable && ~ Dcache2SQ_response)   counter <= `SD counter + 1;
            if (~sq_enable && Dcache2SQ_response)    counter <= `SD counter - 1;
            
            if (match) begin
                forward_valid <= `SD 1;
                forward_pack <= `SD 4ward;
            end
            else begin
                forward_valid <= `SD 0;
                lb2cache_request_entry <=`SD lb2sq_request_entry;
            end
        end    
    end

endmodule
