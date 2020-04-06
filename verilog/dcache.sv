`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __DCACHE_V__
`define __DCACHE_V__

// TODO: Victim Cache



// typedef struct packed {
//     logic [7:0] tag;
//     logic [4:0] block_num;
//     logic [2:0] block_offset;
// } DMAP_ADDR; //address breakdown for a direct-mapped cache

// typedef struct packed {
//     logic [9:0] tag;
//     logic [2:0] set_index;
//     logic [2:0] block_offset;
// } SASS_ADDR; //address breakdown for a set associative cache

// typedef union packed {
//     DMAP_ADDR d; //for direct mapped
//     SASS_ADDR s; //for set associative
// } ADDR; //now we can pass around a common data type

// typedef struct packed {
//     logic [9:0]     tag;
//     CACHE_BLOCK     data;   // 8 Byte (64 bits) per block plus metadata
// } DCACHE_BLOCK;

// typedef struct packed {
//     logic [63:0]    data1;
//     logic [63:0]    data2;  
// } VICTIM;

// typedef struct packed {
//     logic valid;
//     logic [`XLEN-1:0] PC;
//     logic [`PRF_LEN-1:0]  prf_idx;
//     logic [`ROB_LEN-1:0]  rob_idx;  
//     logic [`XLEN-1:0] address;
//     MEM_SIZE mem_size;
//     logic load_signed;
//     logic [3:0] mem_tag;
//     logic done;
//     logic [`XLEN-1:0] data; 

//     logic [`SET_LEN-1:0] set_idx;
//     logic [`WAY_LEN-1:0] way_idx;
// } LOAD_BUFFER_ENTRY;


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
    // tree_plru tree_plru_0(
    //     .load_set_idx_lookup(load_set),

    //     .load_update_enable(),
    //     .load_set_idx_hit(load_set),
    //     .load_way_idx_hit(),
        
    //     .store_update_enable(),
    //     .store_set_idx_hit(),
    //     .store_way_idx_hit(),

    //     .load_lru_way_idx(block_index_lru)
    // );

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
    always_ff @(posedge clock) begin
        if (reset) begin
            for (i=0; i<`SET_SIZE; i++)
                status_bit_table[i] <= `SD 3'h0;
        end 
        else if(load_update_enable) begin
            case (load_way_idx_hit)
                2'b00: status_bit_table[load_set_idx_hit] <= `SD {status_bit_table[load_set_idx_hit][2], 2'b11};
                2'b01: status_bit_table[load_set_idx_hit] <= `SD {status_bit_table[load_set_idx_hit][2], 2'b10};
                2'b10: status_bit_table[load_set_idx_hit] <= `SD {1'b1, status_bit_table[load_set_idx_hit][1], 1'b0};
                2'b11: status_bit_table[load_set_idx_hit] <= `SD {1'b0, status_bit_table[load_set_idx_hit][1], 1'b0};
            endcase
        end
        else if(store_update_enable) begin
            case (store_way_idx_hit)
                2'b00: status_bit_table[store_set_idx_hit] <= `SD {status_bit_table[store_set_idx_hit][2], 2'b11};
                2'b01: status_bit_table[store_set_idx_hit] <= `SD {status_bit_table[store_set_idx_hit][2], 2'b10};
                2'b10: status_bit_table[store_set_idx_hit] <= `SD {1'b1, status_bit_table[store_set_idx_hit][1], 1'b0};
                2'b11: status_bit_table[store_set_idx_hit] <= `SD {1'b0, status_bit_table[store_set_idx_hit][1], 1'b0};
            endcase
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

    // D-cache/I-cache Arbiter -> Main Memory
    output BUS_COMMAND              Dcache2mem_command,      // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    output MEM_SIZE                 Dcache2mem_size,         // load: always cache block; store: depends
    output logic    [2*`XLEN-1:0]     Dcache2mem_data 
    `ifdef DEBUG
        , output    DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks
        , output    LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0] load_buffer
    `endif
);
    `ifndef DEBUG
        // dcache
        DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks;
        // Load Buffer Table
        LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0] load_buffer;
    `endif

    logic [9:0] load_tag;                            // Unique identifier of a specific block
    logic [2:0] load_set;                            // Decides the position in the cache
    assign { load_tag, load_set } = lb2cache_request_entry.addr[31:3];

    // load instruction
    logic load_cache_hit;
    logic [`SET_LEN-1:0] load_cache_hit_set;
    logic [`WAY_LEN-1:0] load_cache_hit_way;

    // store instruction
    logic [9:0] store_tag;                            // Unique identifier of a specific block
    logic [2:0] store_set;                            // Decides the position in the cache
    assign { store_tag, store_set } = sq2cache_request_entry.addr[31:3];

    logic store_cache_hit;
    logic [`SET_LEN-1:0] store_cache_hit_set;
    logic [`WAY_LEN-1:0] store_cache_hit_way;

    // Load Buffer Table
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr;
    logic load_buffer_full;
	
    // Record value of load buffer send ptr last cycle
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr_last_cycle;

    always_comb begin
        load_cache_hit = 0;
        load_cache_hit_set = load_set;
        load_cache_hit_way = 0;

        // check cache hit/miss
        if (lb2cache_request_valid) begin
            for(int i = 0; i < `WAY_SIZE; i++) begin
                if (dcache_blocks[load_set][i].valid && (dcache_blocks[load_set][i].tag == load_tag)) begin
                    load_cache_hit = 1;
                    load_cache_hit_way = i;
                end
            end
        end
    end

    assign load_buffer_full = (load_buffer_head_ptr == load_buffer_tail_ptr) && load_buffer[load_buffer_head_ptr].valid;
    assign load_buffer_empty = (load_buffer_head_ptr == load_buffer_tail_ptr) && (!load_buffer[load_buffer_head_ptr].valid);


    // 1st/2nd 4 byte of cache hit block data
    logic [31:0] cache_hit_data_select_word;
    logic [15:0] cache_hit_data_select_half;
    logic [7:0] cache_hit_data_select_byte;
    assign cache_hit_data_select_word =  dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.words[lb2cache_request_entry.addr[2]];
    assign cache_hit_data_select_half =  dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.halves[lb2cache_request_entry.addr[2:1]];
    assign cache_hit_data_select_byte =  dcache_blocks[load_cache_hit_set][load_cache_hit_way].data.bytes[lb2cache_request_entry.addr[2:0]];

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
                BYTE: dcache_value = lb2cache_request_entry.load_signed ? { {24{cache_hit_data_select_byte[7]}}, cache_hit_data_select_byte } : cache_hit_data_select_byte;
                HALF: dcache_value = lb2cache_request_entry.load_signed ? { {16{cache_hit_data_select_half[15]}}, cache_hit_data_select_half } : cache_hit_data_select_half;
                WORD: dcache_value = cache_hit_data_select_word;
                default: dcache_value = load_buffer_head_data_select_word;
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
            //store_cache_hit_set = store_set;
            store_cache_hit_way = 0;

            for(int i = 0; i < `WAY_SIZE; i++) begin
                if (dcache_blocks[store_set][i].valid && (dcache_blocks[store_set][i].tag == store_tag)) begin
                    store_cache_hit = 1;
                    store_cache_hit_way = i;
                end
            end
        end
    end

    // Outputs: Main Memory
    // BUS_LOAD在此判定条件下会连续high两个cycle，应该为high一次cycle
    assign Dcache2mem_command = sq2cache_request_valid ? BUS_STORE : 
                                (load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) ? BUS_LOAD : BUS_NONE;
    assign Dcache2mem_addr = sq2cache_request_valid ? sq2cache_request_entry.addr :
                                (load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) ? load_buffer[load_buffer_send_ptr].address : 0;
    assign Dcache2mem_size = sq2cache_request_valid ? sq2cache_request_entry.mem_size : DOUBLE;
    assign Dcache2mem_data = sq2cache_request_valid ? sq2cache_request_entry.data : 0;


    logic [`WAY_SIZE-1:0] way_psel_gnt;
    logic no_way_selected;
    logic [`WAY_SIZE-1:0] gnt_bus;
    logic [`WAY_LEN-1:0] current_load_assigned_way;
    logic [`WAY_LEN-1:0] current_load_plru_way;

    logic load_plru_update_enable;
    assign load_plru_update_enable = dcache_valid;

    logic [`SET_LEN-1:0] load_plru_update_set;
    assign load_plru_update_set = load_cache_hit ? load_set : load_buffer[load_buffer_head_ptr].set_idx;
    logic [`WAY_LEN-1:0] load_plru_update_way;
    assign load_plru_update_way = load_cache_hit ? load_cache_hit_way : load_buffer[load_buffer_head_ptr].way_idx;
    
    tree_plru tree_plru_0(
        .clock(clock),
        .reset(reset),
        
        .load_set_idx_lookup(load_set),

        .load_update_enable(load_plru_update_enable),
        .load_set_idx_hit(load_plru_update_set),
        .load_way_idx_hit(load_plru_update_way),
        
        .store_update_enable(sq2cache_request_valid && store_cache_hit),
        .store_set_idx_hit(store_cache_hit_set),
        .store_way_idx_hit(store_cache_hit_way),

        .load_lru_way_idx(current_load_plru_way)
    );
    
    psel_gen #(.WIDTH(`WAY_SIZE), .REQS(1)) psel (
        .req({~dcache_blocks[load_set][3].valid, ~dcache_blocks[load_set][2].valid, ~dcache_blocks[load_set][1].valid, ~dcache_blocks[load_set][0].valid}),
        .gnt(way_psel_gnt),
        .gnt_bus(way_gnt_bus),
        .empty(no_way_selected)
    );
    
    always_comb begin
        if (no_way_selected) begin
            current_load_assigned_way = current_load_plru_way;
        end
        else begin
            case(way_psel_gnt) 
                4'b0001: current_load_assigned_way = `WAY_LEN'h0;
                4'b0010: current_load_assigned_way = `WAY_LEN'h1;
                4'b0100: current_load_assigned_way = `WAY_LEN'h2;
                4'b1000: current_load_assigned_way = `WAY_LEN'h3;
                default: current_load_assigned_way = current_load_plru_way;
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

            for(int i = 0; i < `LOAD_BUFFER_SIZE; i++)
                load_buffer[i].valid <= `SD 0;
            
            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;

        end
        else if(commit_mis_pred) begin
            for(int i = 0; i < `LOAD_BUFFER_SIZE; i++)
                load_buffer[i].valid <= `SD 0;
        
            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;

        end
        else begin
            load_buffer_send_ptr_last_cycle <= `SD load_buffer_send_ptr;

            // Update: load buffer tail ptr
            if (lb2cache_request_valid && !load_cache_hit) begin
                load_buffer[load_buffer_tail_ptr].valid       <= `SD 1;
                load_buffer[load_buffer_tail_ptr].PC          <= `SD lb2cache_request_entry.PC;
                load_buffer[load_buffer_tail_ptr].prf_idx     <= `SD lb2cache_request_entry.rd_preg;
                load_buffer[load_buffer_tail_ptr].rob_idx     <= `SD lb2cache_request_entry.rob_idx;

                load_buffer[load_buffer_tail_ptr].address     <= `SD lb2cache_request_entry.addr;
                load_buffer[load_buffer_tail_ptr].mem_size    <= `SD lb2cache_request_entry.mem_size;
                load_buffer[load_buffer_tail_ptr].load_signed <= `SD lb2cache_request_entry.load_signed;
                load_buffer[load_buffer_tail_ptr].mem_tag     <= `SD 0;
                load_buffer[load_buffer_tail_ptr].done        <= `SD 0;
                load_buffer[load_buffer_tail_ptr].data        <= `SD 0;

                load_buffer[load_buffer_tail_ptr].set_idx     <= `SD load_set;
                load_buffer[load_buffer_tail_ptr].way_idx     <= `SD current_load_assigned_way;

                load_buffer_tail_ptr              <= `SD (load_buffer_tail_ptr == `LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_tail_ptr + 1);
            end

            // Update: load buffer head ptr
            if (!load_cache_hit && (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done)) begin
                load_buffer[load_buffer_head_ptr].valid   <= `SD 0;
                load_buffer_head_ptr                      <= `SD (load_buffer_head_ptr == `LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_head_ptr + 1);

                // update cache block data
                dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][load_buffer[load_buffer_head_ptr].way_idx].data <= `SD load_buffer[load_buffer_head_ptr].data;
                dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][load_buffer[load_buffer_head_ptr].way_idx].tag <= `SD load_buffer[load_buffer_head_ptr].address[15:6];
                dcache_blocks[load_buffer[load_buffer_head_ptr].set_idx][load_buffer[load_buffer_head_ptr].way_idx].valid <= `SD 1;
            end


            // Update: accept data from Main Memory
            if (!load_buffer_empty) begin
                if (load_buffer_head_ptr < load_buffer_tail_ptr) begin
                    for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin
                        if (i >= load_buffer_head_ptr && i < load_buffer_tail_ptr) begin
                            if (load_buffer[i].valid && !load_buffer[i].done && (load_buffer[i].mem_tag == mem2Dcache_tag) && (mem2Dcache_tag != 0)) begin
                                load_buffer[i].done <= `SD 1;
                                load_buffer[i].data <= `SD mem2Dcache_data;
                            end
                        end
                    end
                end
                else begin
                    for(int i = 0; i < `LOAD_BUFFER_SIZE; i++) begin
                        if ((i >= load_buffer_head_ptr) || (i < load_buffer_tail_ptr))
                            if (load_buffer[i].valid && !load_buffer[i].done && (load_buffer[i].mem_tag == mem2Dcache_tag) && (mem2Dcache_tag != 0)) begin
                                load_buffer[i].done <= `SD 1;
                                load_buffer[i].data <= `SD mem2Dcache_data;
                            end
                    end
                end
            end

            // Update: load buffer [send ptr last cycle] entry memory tag
            if (mem2Dcache_response != 0 && mem2Dcache_response_valid && Dcache2mem_command == BUS_LOAD) begin
                
                load_buffer[load_buffer_send_ptr_last_cycle].mem_tag   <= `SD mem2Dcache_response;
                //load_buffer_send_ptr                        <= `SD (load_buffer_send_ptr == `LOAD_BUFFER_SIZE-1)? 0: (load_buffer_send_ptr + 1);
            end

            // Update: store hit -> cache
            if (store_cache_hit) begin
                case (sq2cache_request_entry.mem_size)
                    BYTE: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.bytes[sq2cache_request_entry.addr[2:0]] <= `SD sq2cache_request_entry.data[7:0];
                    HALF: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.halves[sq2cache_request_entry.addr[2:1]] <= `SD sq2cache_request_entry.data[15:0];
                    WORD: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                    default: dcache_blocks[store_cache_hit_set][store_cache_hit_way].data.words[sq2cache_request_entry.addr[2]] <= `SD sq2cache_request_entry.data;
                endcase
            end


            // Update: load buffer send ptr
            if (!sq2cache_request_valid && load_buffer[load_buffer_send_ptr].valid && ~load_buffer[load_buffer_send_ptr].done) begin
                load_buffer_send_ptr                        <= `SD (load_buffer_send_ptr == `LOAD_BUFFER_SIZE-1)? 0: (load_buffer_send_ptr + 1);
            end
        end
    end

endmodule

`endif
