typedef union packed {
    logic [63:0] double;
    logic [1:0][31:0] words;
    logic [3:0][15:0] halves;
    logic [7:0][7:0] bytes;
} CACHE_BLOCK;

typedef struct packed {
    logic [7:0] tag;
    logic [4:0] block_num;
    logic [2:0] block_offset;
} DMAP_ADDR; //address breakdown for a direct-mapped cache

typedef struct packed {
    logic [9:0] tag;
    logic [2:0] set_index;
    logic [2:0] block_offset;
} SASS_ADDR; //address breakdown for a set associative cache

typedef union packed {
    DMAP_ADDR d; //for direct mapped
    SASS_ADDR s; //for set associative
} ADDR; //now we can pass around a common data type

typedef struct packed {
    logic [7:0]     tag;
    logic           valid;
    CACHE_BLOCK     data;   // 8 Byte (64 bits) per block plus metadata
} DCACHE_BLOCK;

typedef struct packed {
    logic [63:0]    data1;
    logic [63:0]    data2;  
} VICTIM;

typedef struct packed {
    logic valid;
    logic [`XLEN-1:0] PC;
    logic [`PRF_LEN-1:0]  prf_idx;
    logic [`ROB_LEN-1:0]  rob_idx;  
    logic [`XLEN-1:0] address;
    logic MEM_SIZE mem_size;
    logic load_signed;
    logic [3:0] mem_tag;
    logic done;
    logic [`XLEN-1:0] data; 
} LOAD_BUFFER_ENTRY;

typedef struct packed {
    logic valid;
    logic [`XLEN-1:0] address;
    logic MEM_SIZE mem_size;
    logic [3:0] mem_tag;
    logic done;
    logic [`XLEN-1:0] data;
} STORE_BUFFER_ENTRY;

/* Cache Restrictions:
 - 256 bytes of data in the data cache.   [32 blocks]
 - One victim cache of two 8-byte blocks (16 bytes of data)
        - Does not include whatever metadata you need for each block    */

parameter WAY_WIDTH = 2;
parameter DCACHE_CAPACITY = 32;
parameter SET_SIZE = 8;
parameter SET_LEN = 3;
parameter WAY_SIZE = 4;
parameter SET_LEN = 2;

parameter LOAD_BUFFER_SIZE = 16;
parameter LOAD_BUFFER_LEN = 4;

parameter STORE_BUFFER_SIZE = 16;
parameter STORE_BUFFER_LEN = 4;


/*  Tree Structure - Pseudo LRU
             Idx:0
            /    \
        Idx:1    Idx:2
        /   \    /   \
       0     1  2     3

       3'b: {Idx:2, Idx:1, Idx:0}
*/

module tree_plru(
    // Look for LRU block of the set
    input [2:0] set_index_lookup,

    // Update the bit of the block
    input [2:0] set_index_mru,
    input [1:0] block_index_mru,
    input update_enable,

    output logic [WAY_WIDTH-1:0] lru_block_index
);

    // logic [2:0][2:0] status_bit_table;
    logic [NUM_SETS-1:0][2:0] status_bit_table;

    always_comb begin
        case(status_bit_table[set_index_lookup]) begin
            3'b000: lru_block_index = 0;
            3'b001: lru_block_index = 2;
            3'b010: lru_block_index = 1;
            3'b011: lru_block_index = 2;
            3'b100: lru_block_index = 0;
            3'b101: lru_block_index = 3;
            3'b110: lru_block_index = 1;
            3'b111: lru_block_index = 3;
        end
    end


    always_ff @(posedge clock) begin
        if(update_enable) begin
            case (block_index_mru) begin
                2'b00: status_bit_table[set_index_mru] <= `SD {status_bit_table[set_index_mru][2], 2'b11};
                2'b01: status_bit_table[set_index_mru] <= `SD {status_bit_table[set_index_mru][2], 2'b10};
                2'b10: status_bit_table[set_index_mru] <= `SD {1'b1, status_bit_table[set_index_mru][1], 1'b0};
                2'b11: status_bit_table[set_index_mru] <= `SD {1'b0, status_bit_table[set_index_mru][1], 1'b0};
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

 

    // Main Memory
    output logic    [1:0]           Dcache2mem_command,      // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    output MEM_SIZE                 Dcache2mem_size,
    output logic    [`XLEN-1:0]     Dcache2mem_data 
);


    DCACHE_BLOCK [SET_SIZE-1:0][WAY_SIZE-1:0] dcache_blocks;

    logic [9:0] load_tag;                            // Unique identifier of a specific block
    logic [2:0] load_set;                            // Decides the position in the cache
    assign { load_tag, load_set } = lb2cache_request_entry.addr[31:3];

    logic current_store_hit;

    logic load_cache_hit;
    logic [SET_LEN-1:0] load_cache_hit_set;
    logic [WAY_LEN-1:0] load_cache_hit_way;

    logic store_buffer_hit;
    logic [STORE_BUFFER_LEN-1:0] store_buffer_hit_idx;
 


    // Load Buffer Table & Store Buffer Table
    LOAD_BUFFER_ENTRY [LOAD_BUFFER_SIZE-1:0] load_buffer;
    logic [LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr;
    logic [LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr;
    logic [LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr;
    logic load_buffer_full;

    STORE_BUFFER_ENTRY [STORE_BUFFER_SIZE-1:0] store_buffer;
    logic [STORE_BUFFER_LEN-1:0] store_buffer_head_ptr;
    logic [STORE_BUFFER_LEN-1:0] store_buffer_send_ptr;
    logic [STORE_BUFFER_LEN-1:0] store_buffer_tail_ptr;
    logic store_buffer_full;
    logic store_buffer_empty;

    //TODO
    assign load_buffer_full = (load_buffer_head_ptr == load_buffer_tail_ptr) && load_buffer[load_buffer_head_ptr].valid;
    assign load_buffer_empty = (load_buffer_head_ptr == load_buffer_tail_ptr) && (!load_buffer[load_buffer_head_ptr].valid);
    assign store_buffer_full = (store_buffer_head_ptr == store_buffer_tail_ptr) && store_buffer[store_buffer_head_ptr].valid;
    assign store_buffer_empty = (store_buffer_head_ptr == store_buffer_tail_ptr) && (!store_buffer[store_buffer_head_ptr].valid);




    always_comb begin

        current_store_hit = 0;
        
        load_cache_hit = 0;
        load_cache_hit_set = load_set;
        load_cache_hit_way = 0;

        store_buffer_hit = 0;
        store_buffer_hit_idx = 0;

        if (lb2cache_request_valid) begin
            if (sq2cache_request_valid && sq2cache_request_entry.addr <= lb2cache_request_entry.addr &&  sq2cache_request_entry.addr + 1'b1<<sq2cache_request_entry.mem_size >= lb2cache_request_entry.addr + 1'b1<<lb2cache_request_entry.mem_size) begin
                current_store_hit = 1;
            end

            for(int i = 0; i < WAY_SIZE; i++) begin
                if (dcache_blocks[load_set][i].valid && (dcache_blocks[load_set][i].tag == load_tag)) begin
                    load_cache_hit = 1;
                    load_cache_hit_way = i;
                end
            end

            if (!store_buffer_empty) begin
                if (store_buffer_head_ptr < store_buffer_tail_ptr) begin
                    for (int i = store_buffer_head_ptr; i < store_buffer_tail_ptr; i++) begin
                        if (store_buffer[i].addr <= lb2cache_request_entry.addr && store_buffer[i].addr + 1'b1<<store_buffer[i].mem_size >= lb2cache_request_entry.addr + 1'b1<<lb2cache_request_entry.mem_size ) begin
                            store_buffer_hit = 1;
                            store_buffer_hit_idx = i;
                        end
                    end
                end

                else begin
                    for (int i = store_buffer_head_ptr; i < STORE_BUFFER_LEN; i++) begin
                        if (store_buffer[i].addr <= lb2cache_request_entry.addr && store_buffer[i].addr + 1'b1<<store_buffer[i].mem_size >= lb2cache_request_entry.addr + 1'b1<<lb2cache_request_entry.mem_size ) begin
                            store_buffer_hit = 1;
                            store_buffer_hit_idx = i;
                        end
                    end

                    for (int i = 0; i < store_buffer_tail_ptr; i++) begin
                        if (store_buffer[i].addr <= lb2cache_request_entry.addr && store_buffer[i].addr + 1'b1<<store_buffer[i].mem_size >= lb2cache_request_entry.addr + 1'b1<<lb2cache_request_entry.mem_size ) begin
                            store_buffer_hit = 1;
                            store_buffer_hit_idx = i;
                        end
                    end
                end
            end
        end
    end




typedef struct packed {            
	logic [`XLEN-1:0]       PC;                
    logic [`XLEN-1:0]       addr;
    logic [`XLEN-1:0]       data;
    logic                   rob_idx;
    logic                   rsvd;
	MEM_SIZE                mem_size;
} SQ_ENTRY;

    output logic  	[`XLEN-1:0]     dcache_PC,
    output logic                    dcache_valid,
    output logic    [`XLEN-1:0]     dcache_value,
    output logic    [`PRF_LEN-1:0]  dcache_prf_idx,
    output logic    [`ROB_LEN-1:0]  dcache_rob_idx,


    always_comb begin
        dcache_valid = current_store_hit || load_cache_hit || store_buffer_hit || (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done);

        if (current_store_hit) begin
            dcache_value = sq2cache_request_entry.data[8 * (1<<lb2cache_request_entry.mem_size) + 8 * (lb2cache_request_entry.addr - sq2cache_request_entry.addr) - 1 : 8 * (lb2cache_request_entry.addr - sq2cache_request_entry.addr)];
            dcache_PC = sq2cache_request_entry.PC;
            dcache_prf_idx = sq2cache_request_entry.rd_preg;
            dcache_rob_idx = sq2cache_request_entry.rob_idx;
        end

        else if (load_cache_hit) begin
            dcache_value = dcache_blocks[load_cache_hit_set][load_cache_hit_way].data[8 * (1<<lb2cache_request_entry.mem_size) +  8 * lb2cache_request_entry.addr[2:0] - 1 : 8 * lb2cache_request_entry.addr[2:0]];
            dcache_PC = lb2cache_request_entry.PC;
            dcache_prf_idx = lb2cache_request_entry.rd_preg;
            dcache_rob_idx = lb2cache_request_entry.rob_idx;
        end
        else if (store_buffer_hit) begin
            dcache_value = store_buffer[store_buffer_hit_idx].data[8 * (1<<lb2cache_request_entry.mem_size) + 8 * (lb2cache_request_entry.addr - store_buffer[store_buffer_hit_idx].addr) - 1 : 8 * (lb2cache_request_entry.addr - store_buffer[store_buffer_hit_idx].addr)];
            dcache_PC = lb2cache_request_entry.PC;
            dcache_prf_idx = lb2cache_request_entry.rd_preg;
            dcache_rob_idx = lb2cache_request_entry.rob_idx;
        end
        else if (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done) begin
            //TO BE EDITED
            dcache_value = load_buffer[load_buffer_head_ptr].data;
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

    // TODO
    assign Dcache2mem_command = ;
    assign Dcache2mem_addr = ;



    logic [2:0] set_index_mru;
    logic [1:0] block_index_mru;
    logic update_enable;
    logic [1:0] block_index_lru;

    assign set_index_mru = current_set;
    assign block_index_mru = current_hit? current_block : block_index_lru;
    assign update_enable = proc2Dcache_addr_enable;


    tree_plru tree_plru_0(
        .set_index_lookup(load_buffer[load_buffer_head_ptr]),
        .set_index_mru(set_index_mru),
        .block_index_mru(block_index_mru),
        .update_enable(update_enable),

        .lru_block_index(block_index_lru)
    );


    always_ff @(posedge clock) begin
        if(reset) begin
            for(i = 0; i < LOAD_BUFFER_SIZE; i++) begin
                load_buffer[i].valid <= `SD 0;
            end

            for(i = 0; i < STORE_BUFFER_SIZE; i++) begin
                store_buffer[i].valid <= `SD 0;
            end

            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;

            store_buffer_head_ptr <= `SD 0;
            store_buffer_send_ptr <= `SD 0;
            store_buffer_tail_ptr <= `SD 0;
        end

        else if (commit_mis_pred) begin
            for(i = 0; i < LOAD_BUFFER_SIZE; i++) begin
                load_buffer[i].valid <= `SD 0;
            end

            load_buffer_head_ptr <= `SD 0;
            load_buffer_send_ptr <= `SD 0;
            load_buffer_tail_ptr <= `SD 0;
        end

        else begin

            if (lb2cache_request_valid && !load_cache_hit && !store_buffer_hit && !current_store_hit ) begin
                load_buffer[load_buffer_tail_ptr].valid       <= `SD 1;
                load_buffer[load_buffer_tail_ptr].PC          <= `SD lb2cache_request_entry.PC;
                load_buffer[load_buffer_tail_ptr].prf_idx     <= `SD lb2cache_request_entry.prd_idx;
                load_buffer[load_buffer_tail_ptr].rob_idx     <= `SD lb2cache_request_entry.rob_idx;


                load_buffer[load_buffer_tail_ptr].address     <= `SD lb2cache_request_entry.rob_idx.addr;
                load_buffer[load_buffer_tail_ptr].mem_size    <= `SD lb2cache_request_entry.rob_idx.mem_size;
                load_buffer[load_buffer_tail_ptr].load_signed <= `SD lb2cache_request_entry.rob_idx.load_signed;
                load_buffer[load_buffer_tail_ptr].mem_tag     <= `SD 0;
                load_buffer[load_buffer_tail_ptr].done        <= `SD 0;
                load_buffer[load_buffer_tail_ptr].data        <= `SD 0;


                load_buffer_tail_ptr              <= `SD (load_buffer_tail_ptr == LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_tail_ptr + 1);
            end

            if (!current_store_hit && !load_cache_hit && !store_buffer_hit && (load_buffer[load_buffer_head_ptr].valid && load_buffer[load_buffer_head_ptr].done)) begin
                load_buffer[load_buffer_head_ptr].valid   <= `SD 0;
                load_buffer_head_ptr                      <= `SD (load_buffer_head_ptr == LOAD_BUFFER_SIZE-1) ? 0 : (load_buffer_head_ptr + 1);
            end

    input                           mem2Dcache_response_valid,
    input           [3:0]           mem2Dcache_response,     // Tag from memory about current request

    // Main Memory
	input           [63:0]          mem2Dcache_data,         // Data coming back from memory
	input           [3:0]           mem2Dcache_tag,  


            if (!load_buffer_empty) begin
                if (load_buffer_head_ptr < load_buffer_tail_ptr) begin
                    for(i = load_buffer_head_ptr; i < load_buffer_tail_ptr; i++) begin
                        if (load_buffer[i].valid && !load_buffer[i].done && load_buffer[i].mem_tag == mem2Dcache_tag && mem2Dcache_tag != 0) begin
                            load_buffer[i].done <= `SD 1;
                            load_buffer[i].data <= `SD mem2Dcache_data;


                        end
                    end
                end
                else begin

                end
            end


            if (load_buffer[load_buffer_head_ptr].valid && !load_buffer[load_buffer_head_ptr].done && mem2Dcache_tag == load_buffer[load_buffer_head_ptr].mem_tag && mem2Dcache_tag != 0) begin
                load_buffer[load_buffer_head_ptr]
            end
                

                mem2Dcache_tag == mshrs_table[head_ptr].mem_tag && mshrs_table[head_ptr].mem_tag != 4'b0) begin
                mshrs_table[head_ptr].done   <= `SD 1;
                mshrs_table[head_ptr].data   <= `SD mem2Dcache_data;
                // 这边应该是修改dcache_block里面的data成员吧？tag和valid要改吗？
                dcache_blocks[mshrs_table[head_ptr].set_index][mshrs_table[head_ptr].way_index]  <= `SD mem2Dcache_data;
            end


            if (mem_request_last_cycle && mem2Dcache_response != 0 && mem2Dcache_response_valid) begin
                mshrs_table[send_ptr].mem_tag   <= `SD mem2Dcache_response;
                send_ptr                        <= `SD (send_ptr == MSHRS_SIZE-1)? 0: (send_ptr + 1);
            end




typedef struct packed {          
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       addr;
    logic [4:0]             rd_preg;
    logic                   rob_idx;
    logic [`SQ_LEN-1:0]     age;
    logic                   rsvd;   //  Load address is resolved
	MEM_SIZE                mem_size;
	logic                   load_signed;
} LB_ENTRY;

typedef struct packed {          
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       addr;
    logic [4:0]             rd_preg;
    logic                   rob_idx;
    logic [`SQ_LEN-1:0]     age;
    logic                   rsvd;   //  Load address is resolved
    logic                   issue;
    logic  [2:0]            load_type; // 000 LB  - 001 LH - 010 LW
									   // 100 LBU - 101 LHU
} LB_ENTRY;










        end
    end



endmodule

