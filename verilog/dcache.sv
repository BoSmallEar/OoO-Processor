`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __DCACHE_V__
`define __DCACHE_V__

// TODO: Victim Cache


/* Cache Restrictions:
 - 256 bytes of data in the data cache.   [32 blocks]
 - One victim cache of two 8-byte blocks (16 bytes of data)
        - Does not include whatever metadata you need for each block    */

/*  Tree Structure - Pseudo LRU
             Idx:0
            /    \
        Idx:1    Idx:2
        /   \    /   \
       0     1  2     3

       3'b: {Idx:2, Idx:1, Idx:0}
*/


module tree_plru(
    input       clock,
    input       reset,

    // Load instruction: Look for LRU block of the set
    input [2:0] load_set_idx_lookup,

    // Update the bit of the block
    input load_update_enable,
    input [2:0] load_set_idx_hit,
    input [1:0] load_way_idx_hit,

    input store_update_enable,
    input [2:0] store_set_idx_hit,
    input [1:0] store_way_idx_hit,
    
    output logic [`WAY_LEN-1:0] load_lru_way_idx
);

    // logic [2:0][2:0] status_bit_table;
    logic [`SET_SIZE-1:0][2:0] status_bit_table;

    always_comb begin
        case(status_bit_table[load_set_idx_lookup]) 
            3'b000: load_lru_way_idx = 0;
            3'b001: load_lru_way_idx = 2;
            3'b010: load_lru_way_idx = 1;
            3'b011: load_lru_way_idx = 2;
            3'b100: load_lru_way_idx = 0;
            3'b101: load_lru_way_idx = 3;
            3'b110: load_lru_way_idx = 1;
            3'b111: load_lru_way_idx = 3; 
        endcase
    end

    int i;
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (i=0; i<`SET_SIZE; i++)
                status_bit_table[i] <= `SD 3'h0;
        end 
        else begin 
            if(load_update_enable) begin
                case (load_way_idx_hit)
                    2'b00: status_bit_table[load_set_idx_hit] <= `SD {status_bit_table[load_set_idx_hit][2], 2'b11};
                    2'b01: status_bit_table[load_set_idx_hit] <= `SD {status_bit_table[load_set_idx_hit][2], 2'b10};
                    2'b10: status_bit_table[load_set_idx_hit] <= `SD {1'b1, status_bit_table[load_set_idx_hit][1], 1'b0};
                    2'b11: status_bit_table[load_set_idx_hit] <= `SD {1'b0, status_bit_table[load_set_idx_hit][1], 1'b0};
                endcase
            end
            if(store_update_enable) begin
                case (store_way_idx_hit)
                    2'b00: status_bit_table[store_set_idx_hit] <= `SD {status_bit_table[store_set_idx_hit][2], 2'b11};
                    2'b01: status_bit_table[store_set_idx_hit] <= `SD {status_bit_table[store_set_idx_hit][2], 2'b10};
                    2'b10: status_bit_table[store_set_idx_hit] <= `SD {1'b1, status_bit_table[store_set_idx_hit][1], 1'b0};
                    2'b11: status_bit_table[store_set_idx_hit] <= `SD {1'b0, status_bit_table[store_set_idx_hit][1], 1'b0};
                endcase
            end
        end
    end

endmodule


module dcache(
    // Inputs
    input                           clock,
    input                           reset,

    // Load buffer
    input           LB_ENTRY        lb2cache_request_entry,
    input                           lb2cache_request_valid,

    // Store queue
    input           SQ_ENTRY        sq2cache_request_entry,
    input                           sq2cache_request_valid,

    // Main Memory
	input           [63:0]          mem2Dcache_data,         // Data coming back from memory
	input           [3:0]           mem2Dcache_tag,          

    // D-cache/I-cache arbiter
    input                           mem2Dcache_response_valid,
    input           [3:0]           mem2Dcache_response,     // Tag from memory about current request

    //Rob
    input                           commit_mis_pred,        

    // Outputs
    // CDB
    output logic  	[`XLEN-1:0]     dcache_PC,
    output logic                    dcache_valid,
    output logic    [`XLEN-1:0]     dcache_value,
    output logic    [`PRF_LEN-1:0]  dcache_prf_idx,
    output logic    [`ROB_LEN-1:0]  dcache_rob_idx,

    // LB
    output logic                    load_buffer_full,
    output logic                    load_buffer_empty,

    // D-cache/I-cache Arbiter -> Main Memory
    output BUS_COMMAND              Dcache2mem_command,      // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    output MEM_SIZE                 Dcache2mem_size,         // load: always cache block; store: depends
    output logic    [2*`XLEN-1:0]     Dcache2mem_data 
    `ifdef DEBUG
        , output    DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks 
        , output    LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0] load_buffer
        , output    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr
        , output    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr
        , output    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr
    `endif
);
    `ifndef DEBUG
        // dcache
        DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks;
        // Load Buffer Table
        LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0] load_buffer;
        logic [`LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr;
        logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr;
        logic [`LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr;
    `endif

    logic [9:0] load_tag;                            // Unique identifier of a specific block
    logic [2:0] load_set;  
    logic [12:0] victim_load_tag;                          // Decides the position in the cache
    VICTIM_CACHE victim_cache;
    assign load_tag = lb2cache_request_entry.addr[15:6];
    assign load_set = lb2cache_request_entry.addr[5:3];
    assign victim_load_tag = lb2cache_request_entry.addr[15:3];

    // load instruction
    logic load_cache_hit;
    logic load_cache_hit_victim;
    logic load_buffer_forward;  
    logic load_buffer_hit;
    logic [63:0] cache_data;
    logic [`SET_LEN-1:0] load_cache_hit_set;
    logic [`WAY_LEN-1:0] load_cache_hit_way;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_hit_entry;

    // store instruction
    logic [9:0] store_tag;                            // Unique identifier of a specific block
    logic [2:0] store_set;   
    logic [12:0] victim_store_tag;                             // Decides the position in the cache
    assign store_tag = sq2cache_request_entry.addr[15:6];
    assign store_set = sq2cache_request_entry.addr[5:3];
    assign victim_store_tag = sq2cache_request_entry.addr[15:3]; 

    logic store_cache_hit;
    logic store_cache_hit_victim;
    logic [`SET_LEN-1:0] store_cache_hit_set;
    logic [`WAY_LEN-1:0] store_cache_hit_way;

	
    // Record value of load buffer send ptr last cycle
    //logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr_last_cycle;

    always_comb begin
        // check cache hit/miss
        if (lb2cache_request_valid) begin
            load_cache_hit = 0; 
            load_cache_hit_victim = 0; 
            load_cache_hit_set = load_set;
            load_cache_hit_way = 0;
            load_buffer_hit = 0;
            load_buffer_hit_entry = 0;
            load_buffer_forward = 0;

            for(int i = 0; i < `WAY_SIZE; i++) begin
                if (dcache_blocks[load_set][i].valid && (dcache_blocks[load_set][i].tag == load_tag)) begin
                    load_cache_hit = 1; 
                    load_cache_hit_victim = 0; 
                    load_buffer_forward = 0; 
                    load_cache_hit_way = i;
                end
            end
            for(int i = 0; i < 2; i++) begin
                if (victim_cache.victim_blocks[i].valid && (victim_cache.victim_blocks[i].tag == victim_load_tag)) begin
                    load_cache_hit = 1; 
                    load_cache_hit_victim = 1; 
                    load_buffer_forward = 0; 
                    load_cache_hit_way = i;
                end
            end
            for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin
                if (load_buffer[i].valid && load_buffer[i].address[15:3] == lb2cache_request_entry.addr[15:3]) begin
                    if (load_buffer[i].data_valid) begin
                        load_cache_hit = 1; 
                        load_cache_hit_victim = 0; 
                        load_buffer_hit_entry = i;
                        load_buffer_hit = 1;
                    end 
                    load_cache_hit_victim = 0;  
                    load_buffer_forward = 1;
                    load_cache_hit_way = 0;
                end 
            end
        end
        else begin 
            load_cache_hit = 0; 
            load_cache_hit_victim = 0; 
            load_cache_hit_set = 0;
            load_buffer_forward = 0;
            load_cache_hit_way = 0;
        end
    end

    assign load_buffer_full = (load_buffer_head_ptr == load_buffer_tail_ptr) && load_buffer[load_buffer_head_ptr].valid;
    assign load_buffer_empty = (load_buffer_head_ptr == load_buffer_tail_ptr) && (!load_buffer[load_buffer_head_ptr].valid);


    // 1st/2nd 4 byte of cache hit block data
    logic [31:0] cache_hit_data_select_word;
    logic [15:0] cache_hit_data_select_half;
    logic [7:0]  cache_hit_data_select_byte;
    assign cache_hit_data_select_word =  load_cache_hit_victim?  victim_cache.victim_blocks[load_cache_hit_way].data.words[lb2cache_request_entry.addr[2]] :
                                         load_buffer_hit? load_buffer[load_buffer_hit_entry].data.words[lb2cache_request_entry.addr[2]]  : dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.words[lb2cache_request_entry.addr[2]];
    assign cache_hit_data_select_half =  load_cache_hit_victim? victim_cache.victim_blocks[load_cache_hit_way].data.halves[lb2cache_request_entry.addr[2:1]] :
                                         load_buffer_hit? load_buffer[load_buffer_hit_entry].data.halves[lb2cache_request_entry.addr[2:1]] : dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.halves[lb2cache_request_entry.addr[2:1]];
    assign cache_hit_data_select_byte =  load_cache_hit_victim? victim_cache.victim_blocks[load_cache_hit_way].data.bytes[lb2cache_request_entry.addr[2:0]] : 
                                         load_buffer_hit? load_buffer[load_buffer_hit_entry].data.bytes[lb2cache_request_entry.addr[2:0]] :dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.bytes[lb2cache_request_entry.addr[2:0]];

    // 1st/2nd 4 byte of load_buffer_head_data
    logic [31:0] load_buffer_head_data_select_word; // [63:32] or [31:0] of the cache line
    logic [15:0] load_buffer_head_data_select_half;
    logic [7:0]  load_buffer_head_data_select_byte;
    assign load_buffer_head_data_select_word =  load_buffer[load_buffer_head_ptr].data.words[load_buffer[load_buffer_head_ptr].address[2]];
    assign load_buffer_head_data_select_half =  load_buffer[load_buffer_head_ptr].data.halves[load_buffer[load_buffer_head_ptr].address[2:1]];
    assign load_buffer_head_data_select_byte =  load_buffer[load_buffer_head_ptr].data.bytes[load_buffer[load_buffer_head_ptr].address[2:0]];
    // Outputs: CDB assignments
    always_comb begin
        dcache_valid = load_cache_hit || (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done);

        // cache hit
        if (load_cache_hit) begin
           
            case(lb2cache_request_entry.mem_size) 
                BYTE: dcache_value = lb2cache_request_entry.load_signed ? { {24{cache_hit_data_select_byte[7]}}, cache_hit_data_select_byte } : {24'b0,cache_hit_data_select_byte};
                HALF: dcache_value = lb2cache_request_entry.load_signed ? { {16{cache_hit_data_select_half[15]}}, cache_hit_data_select_half } : {16'b0,cache_hit_data_select_half};
                WORD: dcache_value = cache_hit_data_select_word;
                default: dcache_value = cache_hit_data_select_word;
            endcase

            //dcache_value = dcache_blocks[load_cache_hit_set][load_cache_hit_way].data[8 * (1<<lb2cache_request_entry.mem_size) +  8 * lb2cache_request_entry.addr[2:0] - 1 : 8 * lb2cache_request_entry.addr[2:0]];
            
            dcache_PC = lb2cache_request_entry.PC;
            dcache_prf_idx = lb2cache_request_entry.rd_preg;
            dcache_rob_idx = lb2cache_request_entry.rob_idx;
        end

        // cache miss & load_buffer_head is done
        else if (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done) begin
            case (load_buffer[load_buffer_head_ptr].mem_size) 
                BYTE: dcache_value = load_buffer[load_buffer_head_ptr].load_signed ? { {24{load_buffer_head_data_select_byte[7]} },  load_buffer_head_data_select_byte } : load_buffer_head_data_select_byte;
                HALF: dcache_value = load_buffer[load_buffer_head_ptr].load_signed ? { {16{load_buffer_head_data_select_half[15]} }, load_buffer_head_data_select_half } : load_buffer_head_data_select_half;
                WORD: dcache_value = load_buffer_head_data_select_word;
                default: dcache_value = load_buffer_head_data_select_word;
            endcase

            dcache_PC = load_buffer[load_buffer_head_ptr].PC;
            dcache_prf_idx = load_buffer[load_buffer_head_ptr].prf_idx;
            dcache_rob_idx = load_buffer[load_buffer_head_ptr].rob_idx;
        end

        else begin
            dcache_value = 0;
            dcache_PC = 0;
            dcache_prf_idx = 0;
            dcache_rob_idx = 0;
        end
    end


    always_comb begin
        if (sq2cache_request_valid) begin
            store_cache_hit = 0;
            store_cache_hit_victim = 0; 
            store_cache_hit_set = store_set;
            store_cache_hit_way = 0;

            for(int i = 0; i < `WAY_SIZE; i++) begin
                if (dcache_blocks[store_set][i].valid && (dcache_blocks[store_set][i].tag == store_tag)) begin
                    store_cache_hit = 1;
                    store_cache_hit_victim = 0; 
                    store_cache_hit_way = i;
                end
            end
            for(int i = 0; i < 2; i++) begin
                if (victim_cache.victim_blocks[i].valid && (victim_cache.victim_blocks[i].tag == victim_store_tag)) begin
                    store_cache_hit = 1; 
                    store_cache_hit_victim = 1; 
                    store_cache_hit_way = i;
                end
            end
        end
        else begin
            store_cache_hit = 0;
            store_cache_hit_victim = 0; 
            store_cache_hit_set = 0;
            store_cache_hit_way = 0;
        end
    end

    // Outputs: Main Memory
    assign Dcache2mem_command = sq2cache_request_valid ? BUS_STORE : 
                                (load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) ? BUS_LOAD : BUS_NONE;
    assign Dcache2mem_addr = sq2cache_request_valid ? sq2cache_request_entry.addr :
                                (load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) ? {load_buffer[load_buffer_send_ptr].address[15:3],3'b0} : 0;
    assign Dcache2mem_size = sq2cache_request_valid ? sq2cache_request_entry.mem_size : DOUBLE;
    assign Dcache2mem_data = sq2cache_request_valid ? sq2cache_request_entry.data : 0;


    logic [`WAY_SIZE-1:0] way_psel_gnt;
    logic no_way_selected;
    logic [`WAY_SIZE-1:0] way_gnt_bus;
    logic [`WAY_LEN-1:0] dcache_evict_way;
    logic [`WAY_LEN-1:0] load_buffer_head_plru_way;

    logic load_plru_update_enable;
    assign load_plru_update_enable = dcache_valid && !load_buffer_hit;

    logic [`SET_LEN-1:0] load_plru_update_set;
    assign load_plru_update_set = load_cache_hit ? load_set : load_buffer[load_buffer_head_ptr].set_idx;
    logic [`WAY_LEN-1:0] load_plru_update_way;
    assign load_plru_update_way = load_cache_hit&& !load_cache_hit_victim ? load_cache_hit_way : dcache_evict_way;

    
    logic [2:0] plru_set_idx_lookup;
    assign plru_set_idx_lookup = load_cache_hit? load_cache_hit_set : load_buffer[load_buffer_head_ptr].set_idx;
    
    tree_plru tree_plru_0(
        .clock(clock),
        .reset(reset),
        
        .load_set_idx_lookup(plru_set_idx_lookup),

        .load_update_enable(load_plru_update_enable),
        .load_set_idx_hit(load_plru_update_set),
        .load_way_idx_hit(load_plru_update_way),
        
        .store_update_enable(sq2cache_request_valid && store_cache_hit && ((store_cache_hit_set != load_plru_update_set) || (!load_plru_update_enable))),
        .store_set_idx_hit(store_cache_hit_set),
        .store_way_idx_hit(store_cache_hit_way),

        .load_lru_way_idx(load_buffer_head_plru_way)
    );
    
    psel_gen #(.WIDTH(`WAY_SIZE), .REQS(1)) psel (
        .req({~dcache_blocks[plru_set_idx_lookup][3].valid, ~dcache_blocks[plru_set_idx_lookup][2].valid, ~dcache_blocks[plru_set_idx_lookup][1].valid, ~dcache_blocks[plru_set_idx_lookup][0].valid}),
        .gnt(way_psel_gnt),
        .gnt_bus(way_gnt_bus),
        .empty(no_way_selected)
    );
    
    always_comb begin
        if (no_way_selected) begin
            dcache_evict_way = load_buffer_head_plru_way;
        end
        else begin
            case(way_psel_gnt) 
                4'b0001: dcache_evict_way = `WAY_LEN'h0;
                4'b0010: dcache_evict_way = `WAY_LEN'h1;
                4'b0100: dcache_evict_way = `WAY_LEN'h2;
                4'b1000: dcache_evict_way = `WAY_LEN'h3;
                default: dcache_evict_way = load_buffer_head_plru_way;
            endcase
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            for (int j = 0; j < `SET_SIZE; j++) begin
                for (int k = 0; k < `WAY_SIZE; k++) begin
                    dcache_blocks[j][k].valid <= `SD 1'b0;
                end
            end
            for(int i = 0; i < 2; i++) begin
                victim_cache.victim_blocks[i].valid <= `SD 1'b0;  
            end
            victim_cache.lru <= `SD 1'b0;

            for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin
                load_buffer[i].valid <= `SD 0;
                load_buffer[i].done <= `SD 0;
                load_buffer[i].data_valid <= `SD 0;
            end
            
            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;

        end
        else if(commit_mis_pred) begin
            for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin
                load_buffer[i].valid <= `SD 0;
                load_buffer[i].done <= `SD 0;
                load_buffer[i].data_valid <= `SD 0;
            end
            // for (int j = 0; j < `SET_SIZE; j++) begin
            //     for (int k = 0; k < `WAY_SIZE; k++) begin
            //         dcache_blocks[j][k].valid <= `SD 1'b0;
            //     end
            // end
        
            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;

        end
        else begin
            //load_buffer_send_ptr_last_cycle <= `SD load_buffer_send_ptr;

            // Update: load buffer tail ptr
           if (lb2cache_request_valid && !load_cache_hit) begin
                for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin 
                    if (load_buffer[i].valid && load_buffer[i].address[15:3] == lb2cache_request_entry.addr[15:3]) begin
                        load_buffer[i].allocate_dcache <= `SD 0; 
                    end
                end
                load_buffer[load_buffer_tail_ptr].valid       <= `SD 1; 
                
	            load_buffer[load_buffer_tail_ptr].data_valid  <= `SD 0;
                load_buffer[load_buffer_tail_ptr].PC          <= `SD lb2cache_request_entry.PC;
                load_buffer[load_buffer_tail_ptr].prf_idx     <= `SD lb2cache_request_entry.rd_preg;
                load_buffer[load_buffer_tail_ptr].rob_idx     <= `SD lb2cache_request_entry.rob_idx; 
                load_buffer[load_buffer_tail_ptr].address     <= `SD lb2cache_request_entry.addr;
                load_buffer[load_buffer_tail_ptr].mem_size    <= `SD lb2cache_request_entry.mem_size;
                load_buffer[load_buffer_tail_ptr].load_signed <= `SD lb2cache_request_entry.load_signed;
                load_buffer[load_buffer_tail_ptr].mem_tag     <= `SD 0;
                load_buffer[load_buffer_tail_ptr].done        <= `SD load_buffer_forward;
                load_buffer[load_buffer_tail_ptr].data        <= `SD 0;
                load_buffer[load_buffer_tail_ptr].allocate_dcache        <= `SD 1;
                load_buffer[load_buffer_tail_ptr].set_idx     <= `SD load_set;
                load_buffer_tail_ptr              <= `SD (load_buffer_tail_ptr == `LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_tail_ptr + 1);
            end
            // swap data between dcache and victim cache
            if (load_cache_hit && load_cache_hit_victim) begin
                dcache_blocks[load_cache_hit_set][dcache_evict_way].data <= `SD  victim_cache.victim_blocks[load_cache_hit_way].data;
                dcache_blocks[load_cache_hit_set][dcache_evict_way].tag <= `SD   victim_cache.victim_blocks[load_cache_hit_way].tag[12:3];
                dcache_blocks[load_cache_hit_set][dcache_evict_way].valid <= `SD  victim_cache.victim_blocks[load_cache_hit_way].valid;
                

                victim_cache.victim_blocks[load_cache_hit_way].tag <= `SD {dcache_blocks[load_cache_hit_set][dcache_evict_way].tag,load_cache_hit_set};
                if (!store_cache_hit || store_cache_hit_victim ||load_set != store_cache_hit_set || dcache_evict_way !=  store_cache_hit_way) begin
                    victim_cache.victim_blocks[load_cache_hit_way].data <= `SD dcache_blocks[load_cache_hit_set][dcache_evict_way].data;
                end
                victim_cache.victim_blocks[load_cache_hit_way].valid <= `SD dcache_blocks[load_cache_hit_set][dcache_evict_way].valid;
                victim_cache.lru <= `SD ~load_cache_hit_way[0];

            end

            // Update: load buffer head ptr
            if (!load_cache_hit && (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].data_valid)) begin
                for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin 
                    if (load_buffer[i].valid && load_buffer[i].address[15:3] ==  load_buffer[load_buffer_head_ptr].address[15:3]) begin
                        assert (load_buffer[i].done)  else $error("wrong go go");    
                        load_buffer[i].data <= `SD   load_buffer[load_buffer_head_ptr].data; 
	                    load_buffer[i].data_valid  <= `SD 1;
                    end
                end
                load_buffer[load_buffer_head_ptr].valid   <= `SD 0;
                load_buffer[load_buffer_head_ptr].done   <= `SD 0;
	            load_buffer[load_buffer_tail_ptr].data_valid  <= `SD 0;
                load_buffer_head_ptr                      <= `SD (load_buffer_head_ptr == `LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_head_ptr + 1);
                if (load_buffer[load_buffer_head_ptr].allocate_dcache) begin
                    dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data <= `SD load_buffer[load_buffer_head_ptr].data;
                    dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].tag <= `SD load_buffer[load_buffer_head_ptr].address[15:6];
                    dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].valid <= `SD 1;
                    for (int it = 0; it< `WAY_SIZE; it++) begin 
                        assert ((!dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][it].valid) || dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][it].tag != load_buffer[load_buffer_head_ptr].address[15:6])  else $error("It's gone wrong");    
                    end 
                    //if valid, we should update the evicted one to victim cache 
                    victim_cache.victim_blocks[victim_cache.lru].valid <= `SD dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].valid;
                    victim_cache.victim_blocks[victim_cache.lru].tag <= `SD {dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].tag,load_buffer[load_buffer_head_ptr].set_idx};
                    if (!store_cache_hit || store_cache_hit_victim || store_cache_hit_set !=load_buffer[load_buffer_head_ptr].set_idx || dcache_evict_way !=  store_cache_hit_way) begin
                        victim_cache.victim_blocks[victim_cache.lru].data <= `SD dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data;
                    end
                    victim_cache.lru <= `SD ~victim_cache.lru; 
                end
            end

            // Update: accept data from Main Memory
            if (!load_buffer_empty) begin      
                for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin 
                    if (load_buffer[i].valid && !load_buffer[i].done && (load_buffer[i].mem_tag == mem2Dcache_tag) && (mem2Dcache_tag != 0)) begin
                        load_buffer[i].done <= `SD 1;
                        load_buffer[i].data <= `SD mem2Dcache_data;
	                    load_buffer[i].data_valid  <= `SD 1;
                    end 
                end 
            end

            // Update: load buffer send ptr
            if ((mem2Dcache_response != 0 && mem2Dcache_response_valid && Dcache2mem_command == BUS_LOAD) ||   load_buffer[load_buffer_send_ptr].done) begin
                assert( load_buffer[load_buffer_send_ptr].valid) else  $error("ha ha ha ha");   
                if (!load_buffer[load_buffer_send_ptr].done) begin
                    load_buffer[load_buffer_send_ptr].mem_tag   <= `SD mem2Dcache_response;
                end
                load_buffer_send_ptr                        <= `SD (load_buffer_send_ptr == `LOAD_BUFFER_SIZE-1)? 0: (load_buffer_send_ptr + 1);
            end

            // Update: store hit -> cache
            if (store_cache_hit) begin
                if(!store_cache_hit_victim) begin
                    if  (!load_cache_hit && (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done)) begin
                        if (store_cache_hit_set ==load_buffer[load_buffer_head_ptr].set_idx && dcache_evict_way ==  store_cache_hit_way) begin
                    //dcache_blocks[store_cache_hit_set][store_cache_hit_way].valid <= `SD 1'b0;
                            case (sq2cache_request_entry.mem_size)
                                BYTE: begin
                                    for (int i=0; i<8 ; i++) begin
                                        victim_cache.victim_blocks[victim_cache.lru].data.bytes[i] <= `SD i==sq2cache_request_entry.addr[2:0] ? sq2cache_request_entry.data[7:0] :  dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data.bytes[i];
                                    end
                                end
                                HALF: begin
                                    for (int i=0; i<4 ; i++) begin
                                        victim_cache.victim_blocks[victim_cache.lru].data.halves[i] <= `SD i==sq2cache_request_entry.addr[2:1] ? sq2cache_request_entry.data[15:0] :  dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data.halves[i];
                                    end
                                end
                                WORD: begin 
                                    for (int i=0; i<2 ; i++) begin
                                        victim_cache.victim_blocks[victim_cache.lru].data.words[i] <= `SD i==sq2cache_request_entry.addr[2] ? sq2cache_request_entry.data:  dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data.words[i];
                                    end
                                end
                                default: begin
                                    for (int i=0; i<2 ; i++) begin
                                        victim_cache.victim_blocks[victim_cache.lru].data.words[i] <= `SD i==sq2cache_request_entry.addr[2] ? sq2cache_request_entry.data:  dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][dcache_evict_way].data.words[i];
                                    end
                                end
                            endcase
                        end
                        else begin
                            case (sq2cache_request_entry.mem_size)
                                BYTE: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.bytes[sq2cache_request_entry.addr[2:0]] <= `SD sq2cache_request_entry.data[7:0];
                                HALF: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.halves[sq2cache_request_entry.addr[2:1]] <= `SD sq2cache_request_entry.data[15:0];
                                WORD: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                                default: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                            endcase
                        end
                    end
                    //update victim 
                    else if (load_cache_hit && load_cache_hit_victim)  begin
                        if (load_set == store_cache_hit_set && dcache_evict_way ==  store_cache_hit_way) begin
                            case (sq2cache_request_entry.mem_size)
                                BYTE: begin
                                    for (int i=0; i<8 ; i++) begin
                                        victim_cache.victim_blocks[load_cache_hit_way].data.bytes[i] <= `SD i==sq2cache_request_entry.addr[2:0] ? sq2cache_request_entry.data[7:0] :  dcache_blocks[load_cache_hit_set][dcache_evict_way].data.bytes[i];
                                    end
                                end
                                HALF: begin
                                    for (int i=0; i<4 ; i++) begin
                                        victim_cache.victim_blocks[load_cache_hit_way].data.halves[i] <= `SD i==sq2cache_request_entry.addr[2:1] ? sq2cache_request_entry.data[15:0] :  dcache_blocks[load_cache_hit_set][dcache_evict_way].data.halves[i];
                                    end
                                end
                                WORD: begin 
                                    for (int i=0; i<2 ; i++) begin
                                        victim_cache.victim_blocks[load_cache_hit_way].data.words[i] <= `SD i==sq2cache_request_entry.addr[2] ? sq2cache_request_entry.data:  dcache_blocks[load_cache_hit_set][dcache_evict_way].data.words[i];
                                    end
                                end
                                default: begin
                                    for (int i=0; i<2 ; i++) begin
                                        victim_cache.victim_blocks[load_cache_hit_way].data.words[i] <= `SD i==sq2cache_request_entry.addr[2] ? sq2cache_request_entry.data:  dcache_blocks[load_cache_hit_set][dcache_evict_way].data.words[i];
                                    end
                                end
                            endcase 
                        end
                        else begin
                            case (sq2cache_request_entry.mem_size)
                                BYTE: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.bytes[sq2cache_request_entry.addr[2:0]] <= `SD sq2cache_request_entry.data[7:0];
                                HALF: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.halves[sq2cache_request_entry.addr[2:1]] <= `SD sq2cache_request_entry.data[15:0];
                                WORD: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                                default: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                            endcase
                        end
                    end
                    else begin
                        case (sq2cache_request_entry.mem_size)
                                BYTE: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.bytes[sq2cache_request_entry.addr[2:0]] <= `SD sq2cache_request_entry.data[7:0];
                                HALF: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.halves[sq2cache_request_entry.addr[2:1]] <= `SD sq2cache_request_entry.data[15:0];
                                WORD: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                                default: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                        endcase
                    end
                end
                else begin
                    if (!(!load_cache_hit && (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done) && (store_cache_hit_way == victim_cache.lru))) begin
                       case (sq2cache_request_entry.mem_size)
                                BYTE: victim_cache.victim_blocks[store_cache_hit_way].data.bytes[sq2cache_request_entry.addr[2:0]] <= `SD sq2cache_request_entry.data[7:0];
                                HALF: victim_cache.victim_blocks[store_cache_hit_way].data.halves[sq2cache_request_entry.addr[2:1]] <= `SD sq2cache_request_entry.data[15:0];
                                WORD: victim_cache.victim_blocks[store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                                default: victim_cache.victim_blocks[store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                        endcase    
                        victim_cache.lru <= `SD ~store_cache_hit_way[0];
                    end
                end
            end

            // Update: load buffer send ptr
            //if (!sq2cache_request_valid && load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) begin
            //    load_buffer_send_ptr                        <= `SD (load_buffer_send_ptr == `LOAD_BUFFER_SIZE-1)? 0: (load_buffer_send_ptr + 1);
            //end
        end
    end

endmodule

`endif