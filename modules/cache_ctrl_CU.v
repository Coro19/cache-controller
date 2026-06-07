
//the control unit handling the cache controller FSM
//4-way set associative, 32KB, 64B blocks, 128 sets
//write-back with write-allocate, LRU replacement

module cache_ctrl_CU (
    input clk, rst_b,
    input cpu_req,          /// CPU requests cache access
    input cpu_wr,           /// CPU write (1) or read (0)
    input hit,              /// tag comparison hit (any way)
    input dirty_victim,     /// LRU victim block has dirty bit set
    input mem_ready,        /// memory operation complete
    output cpu_done,        /// operation finished
    output [14:0] c         /// control signals
);

    /// state register (one-hot FSM, 11 states)
    wire [10:0] state, next;

    /// individual state bits
    wire s0  = state[0];   /// IDLE
    wire s1  = state[1];   /// TAG_CMP
    wire s2  = state[2];   /// READ_HIT
    wire s3  = state[3];   /// WRITE_HIT
    wire s4  = state[4];   /// EVICT_CHECK
    wire s5  = state[5];   /// WRITE_BACK
    wire s6  = state[6];   /// WB_WAIT
    wire s7  = state[7];   /// MEM_FETCH
    wire s8  = state[8];   /// FETCH_WAIT
    wire s9  = state[9];   /// REFILL
    wire s10 = state[10];  /// DONE

    /// next state logic

    assign next[0]  = (s0 & ~cpu_req) | s2 | s3 | s10;                 /// IDLE: no request, or completion
    assign next[1]  = s0 & cpu_req;                                      /// TAG_CMP: start on CPU request
    assign next[2]  = s1 & hit & ~cpu_wr;                                /// READ_HIT: tag hit on read
    assign next[3]  = s1 & hit & cpu_wr;                                 /// WRITE_HIT: tag hit on write
    assign next[4]  = s1 & ~hit;                                         /// EVICT_CHECK: tag miss
    assign next[5]  = s4 & dirty_victim;                                 /// WRITE_BACK: victim is dirty
    assign next[6]  = s5 | (s6 & ~mem_ready);                            /// WB_WAIT: waiting for write-back
    assign next[7]  = (s4 & ~dirty_victim) | (s6 & mem_ready);           /// MEM_FETCH: clean victim or WB done
    assign next[8]  = s7 | (s8 & ~mem_ready);                            /// FETCH_WAIT: waiting for memory read
    assign next[9]  = s8 & mem_ready;                                    /// REFILL: memory data ready
    assign next[10] = s9;                                                 /// DONE: after refill complete

    /// control signal outputs

    assign c[0]  = s1;                              /// tag_cmp_en: enable tag comparison
    assign c[1]  = s2;                              /// cache_rd_en: read data from cache to CPU
    assign c[2]  = s3;                              /// cache_wr_cpu: write CPU data to cache
    assign c[3]  = s3 | (s9 & cpu_wr);              /// set_dirty: write hit or write-allocate refill
    assign c[4]  = s9 & ~cpu_wr;                    /// clr_dirty: read miss refill
    assign c[5]  = s9;                              /// set_valid: mark cache line valid on refill
    assign c[6]  = s9;                              /// tag_wr_en: write new tag on refill
    assign c[7]  = s7;                              /// mem_rd_req: request memory read
    assign c[8]  = s5;                              /// mem_wr_req: request memory write-back
    assign c[9]  = s2 | s3 | s10;                   /// lru_update: update LRU on any completion
    assign c[10] = s9;                              /// refill_en: write memory data to cache line
    assign c[11] = s4 | s5 | s6;                    /// victim_sel: select LRU victim way
    assign c[12] = s9 & cpu_wr;                     /// cache_wr_refill: write CPU data after refill
    assign c[13] = s1 | s4 | s5 | s6 | s7 | s8 | s9; /// stall: stall CPU pipeline
    assign c[14] = s5;                              /// evict_dirty_rd: read dirty block for write-back

    /// done signal
    assign cpu_done = s2 | s3 | s10;

    /// state flip-flops

    /// state[0] set to 1 on async reset (IDLE active)
    d_ff ff0 (
        .clk(clk),
        .rst_b(1'b1),
        .set_b(rst_b),
        .load(1'b1),
        .data(next[0]),
        .q(state[0]),
        .q_b()
    );

    /// remaining states reset to 0
    genvar i;
    generate
        for(i=1;i<=10;i=i+1) begin: FF
            d_ff ff (
                .clk(clk),
                .rst_b(rst_b),
                .set_b(1'b1),
                .load(1'b1),
                .data(next[i]),
                .q(state[i]),
                .q_b()
            );
        end
    endgenerate
endmodule
