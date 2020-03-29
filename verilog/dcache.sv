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
    logic [`XLEN-1:0] address;
    logic type;
    logic [3:0] mem_tag;
    logic done;
    logic [`XLEN-1:0] data;
    logic [2:0] set_index;
    logic [1:0] way_index;
} MSHRS_ENTRY;

/* Cache Restrictions:
 - 256 bytes of data in the data cache.   [32 blocks]
 - One victim cache of two 8-byte blocks (16 bytes of data)
        - Does not include whatever metadata you need for each block    */

parameter WAY_WIDTH=2;
parameter DCACHE_CAPACITY=32;
parameter NUM_SETS=8;
parameter NUM_WAYS=4;

parameter MSHRS_SIZE = 16;
parameter MSHRS_LEN = 4;


/*  Tree Structure - Pseudo LRU
             Idx:0
            /    \
        Idx:1    Idx:2
        /   \    /   \
       0     1  2     3
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

    logic [2:0][2:0] status_bit_table;

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
                2'b00: status_bit_table[set_index_mru] = {status_bit_table[set_index_mru][2], 2'b11};
                2'b01: status_bit_table[set_index_mru] = {status_bit_table[set_index_mru][2], 2'b10};
                2'b10: status_bit_table[set_index_mru] = {1'b1, status_bit_table[set_index_mru][1], 1'b0};
                2'b11: status_bit_table[set_index_mru] = {1'b0, status_bit_table[set_index_mru][1], 1'b0};
            end
        end
    end

endmodule

tree_plru tree_plru_0(
    .set_index_lookup(current_set),

    .set_index_mru(set_index_mru),
    .block_index_mru(block_index_mru),
    .update_enable(update_enable),

    .lru_block_index(block_index_lru)
);


module dcache(
    // Inputs
    input                           clock,
    input                           reset,

    // Load queue
    input           [`XLEN-1:0]     proc2Dcache_addr,
    input                           proc2Dcache_addr_enable,

    // Main Memory
    input           [3:0]           mem2Dcache_response,     // Tag from memory about current request
	input           [63:0]          mem2Dcache_data,         // Data coming back from memory
	input           [3:0]           mem2Dcache_tag,          

    // Outputs
    // Processor
    output logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic    [`XLEN-1:0]     Dcache2proc_addr,
    output logic                    Dcache2proc_valid, 
    output logic    [`ROB_LEN-1:0]  Dcache2proc_rob_idx, 

    // Main Memory
    output logic    [1:0]           Dcache2mem_command,      // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    output logic    [`XLEN-1:0]     Dcache2mem_data, 


mem2Dcache_response_valid



    // If SQ head entry is ready and Store at Rob head, retire SQ head
    //input  logic [`XLEN-1:0]           SQ_head_address,
    //input  logic [`XLEN-1:0]           SQ_head_source_data,
    //input                              SQ_head_resolved,
    //input                              store_at_rob_head,
    // To SQ
    //output [SQ_IDX_LEN-1:0]         Dcache2SQ_response
);


    DCACHE_BLOCK [7:0][3:0] dcache_blocks;

    // Extract the tag and index of the requested block
    logic [9:0] current_tag;                            // Unique identifier of a specific block
    logic [2:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];

    logic [2:0] current_set;
    assign current_set = current_index % 8;

    logic current_hit;
    logic [1:0] current_block;

    for(int i = 0; i < 4; i++) begin
        current_hit = 0;
        current_block = 0;

        if (proc2Dcache_addr_enable && dcache_blocks[current_set][i].valid && (dcache_blocks[current_set][i].tag == current_tag)) begin
            current_hit = 1;
            current_block = i;
        end
    end

    MSHRS_ENTRY [MSHRS_SIZE-1:0] mshrs_table;
    logic [MSHRS_LEN-1:0] head_ptr;
    logic [MSHRS_LEN-1:0] send_ptr;
    logic [MSHRS_LEN-1:0] tail_ptr;

    assign Dcache2proc_data = current_hit? (proc2Dcache_addr[2] ? dcache_blocks[hit_idx].data[63:32]:dcache_blocks[hit_idx].data[31:0]) : 
        | (mshrs_table[head_ptr].valid && mshrs_table[head_ptr].done)? (mshrs_table[head_ptr].address[2] ? mshrs_table[head_ptr].data[63:32] : mshrs_table[head_ptr].data[31:0]) : 0;
    assign Dcache2proc_addr = current_hit? proc2Dcache_addr : (mshrs_table[head_ptr].valid && mshrs_table[head_ptr].done)? mshrs_table[head_ptr].address : 0;
    assign Dcache2proc_valid = current_hit || (mshrs_table[head_ptr].valid && mshrs_table[head_ptr].done);


    logic mem_request_last_cycle;
    assign Dcache2mem_command = mshrs_table[send_index].valid && mshrs_table[send_index].mem_tag == 0;
    assign Dcache2mem_addr = mshrs_table[send_index].address;

    logic [2:0] set_index_mru;
    logic [1:0] block_index_mru;
    logic update_enable;
    logic [1:0] block_index_lru;

    assign set_index_mru = current_set;
    assign block_index_mru = current_hit? current_block : block_index_lru;
    assign update_enable = proc2Dcache_addr_enable;


    always_ff @(posedge clock) begin
        if(reset) begin
            head_ptr <= `SD 0;
            send_ptr <= `SD 0;
            tail_ptr <= `SD 0;
        end
        else begin
            logic mem_request_last_cycle <= `SD Dcache2mem_command;

            // Update mshrs_table: tail_ptr entry
            if (proc2Dcache_addr_enable && !current_hit) begin
                mshrs_table[tail_ptr].valid       <= `SD 1;
                mshrs_table[tail_ptr].address     <= `SD proc2Dcache_addr;
                mshrs_table[tail_ptr].mem_tag     <= `SD 0;
                mshrs_table[tail_ptr].done        <= `SD 0;
                mshrs_table[tail_ptr].data        <= `SD 0;
                mshrs_table[tail_ptr].set_index   <= `SD current_set;
                mshrs_table[tail_ptr].way_index   <= `SD block_index_mru;
                tail_ptr                          <= `SD (tail_ptr == MSHRS_SIZE-1)? 0: (tail_ptr + 1);
            end

            // Update mshrs_table: head_ptr
            if (!current_hit && (mshrs_table[head_ptr].valid && mshrs_table[head_ptr].done)) begin
                mshrs_table[head_ptr].valid   <= `SD 0;
                head_ptr                      <= `SD (head_ptr == MSHRS_SIZE-1)? 0: (head_ptr + 1);
            end

            //Update mshrs_table: head_ptr entry
            if (mem2Dcache_tag == mshrs_table[head_ptr].mem_tag && mshrs_table[head_ptr].mem_tag != 4'b0) begin
                mshrs_table[head_ptr].done   <= `SD 1;
                mshrs_table[head_ptr].data   <= `SD mem2Dcache_data;

                dcache_blocks[mshrs_table[head_ptr].set_index][mshrs_table[head_ptr].way_index]  <= `SD mem2Dcache_data;
            end

            //Update mshrs_table: send_ptr entry and send_ptr
            if (mem_request_last_cycle && mem2Dcache_response != 0) begin
                mshrs_table[send_ptr].mem_tag   <= `SD mem2Dcache_response;
                send_ptr                        <= `SD (send_ptr == MSHRS_SIZE-1)? 0: (send_ptr + 1);
            end

        end
    end



endmodule


//  Strangely deleted