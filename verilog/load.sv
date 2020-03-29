typedef struct packed {          
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       addr;
    logic [4:0]             rd_preg;
    logic                   rob_idx;
    logic [`SQ_LEN-1:0]     age;
    logic                   rsvd;   //  Load address is resolved
    logic                   issue;
    logic  [3:0]            load_byte; // LOAD 1 BYTE / HALF WORD/ ONE WORD
} LB_ENTRY;

typedef struct packed {
    LB_ENTRY    [`LB_LEN-1:0]        entries;
    logic       [`LB_CAPACITY-1:0]   free_list;      // Unoccupied entries
    logic       [`LB_CAPACITY-1:0]   rsvd_list;   
    logic       [`LB_CAPACITY-1:0]   issue_list;   
} LOAD_BUFFER;

module load_buffer ( 
    input                                       clock,
    input                                       reset,
    input                                       lb_enable,  
    // From RS_SQ
    input                                       rs_lb_out_valid,
    input                                       rs_lb_packet,  
    // From SQ
    input                                       sq_empty,
    input                                       sq_head,
    input                                       sq_tail,  
    input                                       sq_addr_all_rsvd,
    input                                       secure_age,  
    // To previous stage : no space for you
    output  logic                               lb_full,
    // To RS 
    output  logic      [`LB_LEN-1:0]            Assigned_lb_idx,    
    // To SQ
    output  logic                               lb_request_valid,
    output  LB_ENTRY                            lb_request_entry,
);

    LOAD_BUFFER                                 LB;
    logic                                       lb_full;
    assign                                      lb_full = LB.free_list==0;

    // Choose a free entry to put the new instruction
    logic [`LB_LEN-1:0]                      free_idx;
    always_comb begin
        free_idx = `LB_LEN'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (LB.free_list[j]==0) free_idx = j; 
        end
    end

    // Choose the issue_list from the resolved LB entries
    // They should be older than oldest unresolved store instruction
    always_comb begin
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (!LB.entries[j].rsvd) 
                LB.issue_list[j] = 0; // Unresolved loads are not considered
            else begin  
                // Consider the loads older than the secure_age
                // E.g. Index 0 - store ...
                //                load (age: 1)
                //      Index 1 - store ???
                // Even if the store at index 0 retires
                // new sq_head has index 1, which is equal the load_age 1
                // Hence we should consider load_age geq current sq_head
                //                                   leq secure_age
                if (sq_head <= secure_age) begin
                    //  START [....... |HEAD ------ SECURE ---|..... ] END
                    //  Whether TAIL wraps doesn't matter, we only care about the range between H&S
                    if (LB.entries[j].age >= sq_head && LB.entries[j].age <= secure_age)
                        LB.issue_list[j] = 1;
                end
                else if (sq_head > secure_age) begin
                    //  START [|---- SECURE ----| ...... |HEAD ----|] END
                    if(LB.entries[j].age >= sq_head || LB.entries[j].age <= secure_age)
                        LB.issue_list[j] = 1;
                    end
                end
                else
                    LB.issue_list[j] = 0;
            end 
        end
    end

    // Choose an issuable entry to issue with the given selector
    logic none_selected;
    logic [`LB_CAPACITY-1:0] gnt_bus;
    logic [`LB_CAPACITY-1:0] psel_gnt;
    psel_gen #(.WIDTH(`LB_CAPACITY), .REQS(1)) psel (
        .req(LB.issue_list),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(none_selected)
    );
    logic [`LB_LEN-1:0] issue_idx;
    always_comb begin
        issue_idx = `LB_CAPACITY'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (psel_gnt[j]) issue_idx = j; 
        end
    end

    // Sequentially 
    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i=0;i<`LB_CAPACITY;i++) begin
                LB.entries[i].rsvd <= `SD 0;
            end 
            LB.free_list <= `SD {`LB_CAPACITY{1}};
            LB.rsvd_list <= `SD {`LB_CAPACITY{0}};
            LB.issue_list <= `SD {`LB_CAPACITY{0}};
        end
        
        if (lb_enable) begin  
            // Tell RS this inst is entered into FREE_INDEX 
            Assigned_LB_idx <= `SD free_idx;
            // Age is the current SQ tail, new entry is always unresolved
            LB.entries[free_idx].age <= `SD sq_tail;
            LB.entries[free_idx].rsvd <=`SD 0;
            // Update the list - this entry no longer free/resolved
            LB.free_list[free_idx] <= `SD 0;    
            LB.rsvd_list[free_idx] <=`SD 0;
        end 
        
        // RS fills information into specific entry when it's ready
        if (rs_lb_out_valid&&LB.entries[rs_lb_packet.lb_idx].rsvd==0) begin
            LB.entries[rs_lb_packet.lb_idx].rsvd <=`SD 1;
            LB.entries[rs_lb_packet.lb_idx].addr <= `SD rs_lb_packet.base_value + rs_lb_packet.offset;
            LB.entries[rs_lb_packet.lb_idx].rd_preg <=`SD rs_lb_packet.dest_preg_idx;
            LB.entries[rs_lb_packet.lb_idx].rob_idx <=`SD rs_lb_packet.rob_idx;
            LB.entries[rs_lb_packet.lb_idx].PC <=`SD rs_lb_packet.PC;
            LB.entries[rs_lb_packet.lb_idx].load_byte <=`SD rs_lb_packet.load_byte;
        end

        // Some load inst can be issued
        // Once issued; Retire from LB
        if (!none_selected) begin
            lb_request_valid <= `SD 1;
            lb_request_entry <= `SD LB.entries[issue_idx];
            LB.free_list[j] <=`SD 1;
        end
    end

endmodule
