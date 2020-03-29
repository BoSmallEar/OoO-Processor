typedef struct packed {          
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       addr;
    logic [4:0]             rd_preg;
    logic                   rob_idx;
    logic [`SQ_LEN-1:0]     age;
    logic                   rsvd;   //  Load address is resolved
    logic                   issue;
    logic                   no_preceding_store;
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
    input                                       oldest_unrsvd_sq_idx,  
    // From D$ or SQ
    input                                       retire_tag,
    // To previous stage : no space for you
    output  logic                               lb_full,
    // To RS 
    output  logic      [`LB_LEN-1:0]            asnd_lb_idx,    
    // To SQ
    output  logic                               lb_request_valid,
    output  LB_ENTRY                            lb_request_entry,
);
    LOAD_BUFFER                                 LB;
    logic                                       lb_full;
    assign                                      lb_full = LB.free_list==0;

    // Choose an entry to put the new instruction
    logic [`LB_LEN-1:0]                      free_idx;
    always_comb begin
        free_idx = `LB_LEN'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (LB.free_list[j]==0) free_idx = j; 
        end
    end

    // Loads are allowed to execute out-of-order when they
    // are not preceded by a store with an unresolved address
    always_comb begin
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (!LB.entries[j].rsvd) 
                LB.issue_list[j] = 0;
            else begin
                if (LB.entries[j].no_preceding_store || sq_addr_all_rsvd)
                    LB.issue_list[j] = 1;
                if (LB.entries[j].age == sq_head)
                    LB.issue_list[j] = 1;
                else begin
                    if (sq_head <= oldest_unrsvd_sq_idx) begin
                        if(LB.entries[j].age -1 <  oldest_unrsvd_sq_idx)
                            LB.issue_list[j] = 1;
                    end
                    else begin
                        if (LB.entries[j].age -1>sq_head&&LB.entries[j].age -1 < oldest_unrsvd_sq_idx)
                            LB.issue_list[j] = 1;
                        else
                            LB.issue_list[j] = 0;
                    end
                end
            end 
        end
    end

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
        issue_idx = `LB_CAPACITY'h0; // avoid additional latching
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (psel_gnt[j]) issue_idx = j; 
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i=0;i<`LB_CAPACITY;i++) begin
                LB.entries[i].rsvd <= `SD 0;
                LB.entries[i].rsvd <= `SD 0;
                LB.entries[i].no_preceding_store <= `SD 0;
            end 
            LB.free_list <= `SD {`LB_CAPACITY{1}};
            LB.rsvd_list <= `SD {`LB_CAPACITY{0}};
            LB.issue_list <= `SD {`LB_CAPACITY{0}};
        end
        
        if (lb_enable) begin  // An inst enters the load buffer
            LB.entries[free_idx].age <= `SD sq_tail;
            LB.free_list[free_idx] <= `SD 0;    
            asnd_LB_idx <= `SD free_idx;

            LB.rsvd_list[free_idx] <=`SD 0;
            LB.entries[free_idx].rsvd <=`SD 0;
            if (sq_empty)
                LB.entries[free_idx].no_preceding_store <= `SD 1;
        end 
        
        // The load address is resolved
        if (rs_lb_out_valid&&LB.entries[rs_lb_packet.lb_idx].rsvd==0) begin
            LB.entries[rs_lb_packet.lb_idx].rsvd <=`SD 1;
            LB.entries[rs_lb_packet.lb_idx].addr <= `SD rs_lb_packet.base_value + rs_lb_packet.offset;
            LB.entries[rs_lb_packet.lb_idx].rd_preg <=`SD rs_lb_packet.dest_preg_idx;
            LB.entries[rs_lb_packet.lb_idx].rob_idx <=`SD rs_lb_packet.rob_idx;
            LB.entries[rs_lb_packet.lb_idx].PC <=`SD rs_lb_packet.PC;
        end

        if (!none_selected) begin
            lb_request_valid <= `SD 1;
            lb_request_entry <= `SD LB.entries[issue_idx];
        end

        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (LB.entries[j].rob_idx==retire_tag) 
                LB.free_list[j] <=`SD 1;
        end   
    end

endmodule
