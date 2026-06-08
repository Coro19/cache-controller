module cache_ctrl_tb;

    localparam INDEX_SIZE = 7;
    localparam TAG_SIZE   = 21;
    localparam SET_SIZE   = 4;
    localparam NUM_SETS   = 2**INDEX_SIZE;

    localparam TAGS_WIDTH  = NUM_SETS * TAG_SIZE * SET_SIZE;
    localparam VALID_WIDTH = NUM_SETS * SET_SIZE;
    localparam DIRTY_WIDTH = NUM_SETS * SET_SIZE;
    localparam AGE_WIDTH   = NUM_SETS * SET_SIZE * 2;

    reg clk, rst_b;
    reg cpu_req, cpu_wr, mem_ready;
    reg  [TAGS_WIDTH-1:0]  tags;
    reg  [VALID_WIDTH-1:0] valid_bits;
    reg  [DIRTY_WIDTH-1:0] dirty_bits;
    reg  [AGE_WIDTH-1:0]   age_bits;
    reg  [INDEX_SIZE-1:0]  index_to_test;
    reg  [TAG_SIZE-1:0]    tag_to_test;

    wire cpu_done;
    wire [14:0] c;

    cache_ctrl uut (
        .clk(clk),
        .rst_b(rst_b),
        .cpu_req(cpu_req),
        .cpu_wr(cpu_wr),
        .mem_ready(mem_ready),
        .tags(tags),
        .valid_bits(valid_bits),
        .dirty_bits(dirty_bits),
        .age_bits(age_bits),
        .index_to_test(index_to_test),
        .tag_to_test(tag_to_test),
        .cpu_done(cpu_done),
        .c(c)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer hits   = 0;
    integer misses = 0;
    integer total_cycles = 0;
    integer start_cycle  = 0;
    integer cur_cycle    = 0;
    always @(posedge clk) cur_cycle = cur_cycle + 1;

    // set a tag in a specific set and way
    task write_tag;
        input [INDEX_SIZE-1:0] set_idx;
        input [1:0] way;
        input [TAG_SIZE-1:0] tag_val;
        input v, d;
        begin
            tags[ set_idx*SET_SIZE*TAG_SIZE + way*TAG_SIZE +: TAG_SIZE ] = tag_val;
            valid_bits[ set_idx*SET_SIZE + way ] = v;
            dirty_bits[ set_idx*SET_SIZE + way ] = d;
        end
    endtask

    // set lru ages for a set (8 bits = 4 ways x 2 bits)
    task set_ages;
        input [INDEX_SIZE-1:0] set_idx;
        input [7:0] packed_ages;
        begin
            age_bits[ set_idx*8 +: 8 ] = packed_ages;
        end
    endtask

    // clear all cache state
    task cold_cache;
        begin
            tags       = 0;
            valid_bits = 0;
            dirty_bits = 0;
            age_bits   = 0;
        end
    endtask

    task do_reset;
        begin
            rst_b     = 0;
            cpu_req   = 0;
            cpu_wr    = 0;
            mem_ready = 0;
            @(posedge clk); #1;
            rst_b = 1;
            @(posedge clk); #1;
        end
    endtask

    // send one access and wait for cpu_done
    // mem_lat = how many cycles before mem_ready goes high (0 for hits)
    // is_hit  = 1 if we expect a hit (for counters)
    task send_op;
        input is_write;
        input [INDEX_SIZE-1:0] idx;
        input [TAG_SIZE-1:0]   tag_v;
        input integer mem_lat;
        input is_hit;
        integer lat;
        begin
            index_to_test = idx;
            tag_to_test   = tag_v;
            cpu_wr        = is_write;
            mem_ready     = 0;

            if (is_hit) hits   = hits   + 1;
            else        misses = misses + 1;

            start_cycle = cur_cycle;
            cpu_req = 1;
            @(posedge clk); #1;

            lat = 0;
            while (!cpu_done) begin
                lat = lat + 1;
                if (lat >= mem_lat && mem_lat > 0)
                    mem_ready = 1;
                @(posedge clk); #1;
            end

            total_cycles = total_cycles + (cur_cycle - start_cycle);

            cpu_req   = 0;
            mem_ready = 0;
            @(posedge clk); #1;

            $display("op=%s idx=%0d tag=%0h | %s | cycles=%0d",
                is_write ? "WR" : "RD", idx, tag_v,
                is_hit ? "HIT " : "MISS",
                cur_cycle - start_cycle);
        end
    endtask

    initial begin
        cold_cache;
        do_reset;

        //  READ HIT 
        write_tag(7'd0, 2'd0, 21'h1ABCD, 1, 0);
        set_ages(7'd0, 8'b00_01_10_00);
        send_op(0, 7'd0, 21'h1ABCD, 0, 1);  // hit

        //  WRITE HIT 
        do_reset; cold_cache;
        write_tag(7'd1, 2'd2, 21'h00111, 1, 0);
        set_ages(7'd1, 8'b11_01_00_10);
        send_op(1, 7'd1, 21'h00111, 0, 1);  // hit

        //  READ MISS clean victim 
        do_reset; cold_cache;
        send_op(0, 7'd5, 21'h3FFFF, 3, 0);  // miss, all invalid

        //  READ MISS dirty victim (write-back) 
        do_reset; cold_cache;
        write_tag(7'd2, 2'd0, 21'h00001, 1, 1);
        write_tag(7'd2, 2'd1, 21'h00002, 1, 1);
        write_tag(7'd2, 2'd2, 21'h00003, 1, 1);
        write_tag(7'd2, 2'd3, 21'h00004, 1, 1);
        set_ages(7'd2, 8'b01_01_01_11);  // way0 is LRU and dirty
        send_op(0, 7'd2, 21'h0FFFF, 4, 0);  // miss + write-back

        // WRITE MISS clean victim 
        do_reset; cold_cache;
        send_op(1, 7'd10, 21'h1CAFE, 3, 0);

        //  WRITE MISS dirty victim 
        do_reset; cold_cache;
        write_tag(7'd20, 2'd0, 21'h0AAAA, 1, 1);
        write_tag(7'd20, 2'd1, 21'h0BBBB, 1, 1);
        write_tag(7'd20, 2'd2, 21'h0CCCC, 1, 1);
        write_tag(7'd20, 2'd3, 21'h0DDDD, 1, 1);
        set_ages(7'd20, 8'b01_01_01_11);
        send_op(1, 7'd20, 21'h0EEEE, 4, 0);

        // MISS then HIT same address 
        do_reset; cold_cache;
        send_op(0, 7'd7, 21'h12345, 3, 0);  // cold miss
        write_tag(7'd7, 2'd0, 21'h12345, 1, 0);
        set_ages(7'd7, 8'b01_01_01_00);
        send_op(0, 7'd7, 21'h12345, 0, 1);  // now hits

        // stress: 5 preloaded hits 
        do_reset; cold_cache;
        write_tag(7'd10, 2'd0, 21'h11111, 1, 0); set_ages(7'd10, 8'b01_01_01_00);
        write_tag(7'd20, 2'd1, 21'h22222, 1, 0); set_ages(7'd20, 8'b01_00_01_01);
        write_tag(7'd30, 2'd2, 21'h33333, 1, 0); set_ages(7'd30, 8'b01_01_00_01);
        write_tag(7'd40, 2'd3, 21'h44444, 1, 0); set_ages(7'd40, 8'b00_01_01_01);
        write_tag(7'd50, 2'd0, 21'h55555, 1, 0); set_ages(7'd50, 8'b01_01_01_00);
        send_op(0, 7'd10, 21'h11111, 0, 1);
        send_op(1, 7'd20, 21'h22222, 0, 1);
        send_op(0, 7'd30, 21'h33333, 0, 1);
        send_op(1, 7'd40, 21'h44444, 0, 1);
        send_op(0, 7'd50, 21'h55555, 0, 1);

        // stress: 10 cold misses
        send_op(0, 7'd60, 21'h60001, 3, 0);
        send_op(1, 7'd61, 21'h61001, 3, 0);
        send_op(0, 7'd62, 21'h62001, 3, 0);
        send_op(1, 7'd63, 21'h63001, 3, 0);
        send_op(0, 7'd64, 21'h64001, 3, 0);
        send_op(1, 7'd65, 21'h65001, 3, 0);
        send_op(0, 7'd66, 21'h66001, 3, 0);
        send_op(1, 7'd67, 21'h67001, 3, 0);
        send_op(0, 7'd68, 21'h68001, 3, 0);
        send_op(1, 7'd69, 21'h69001, 3, 0);

        //  stress: 5 dirty-victim misses 
        write_tag(7'd70, 2'd0, 21'h70001, 1, 1); write_tag(7'd70, 2'd1, 21'h70002, 1, 1);
        write_tag(7'd70, 2'd2, 21'h70003, 1, 1); write_tag(7'd70, 2'd3, 21'h70004, 1, 1);
        set_ages(7'd70, 8'b01_01_01_11);
        send_op(0, 7'd70, 21'h70FFF, 4, 0);

        write_tag(7'd71, 2'd0, 21'h71001, 1, 1); write_tag(7'd71, 2'd1, 21'h71002, 1, 1);
        write_tag(7'd71, 2'd2, 21'h71003, 1, 1); write_tag(7'd71, 2'd3, 21'h71004, 1, 1);
        set_ages(7'd71, 8'b01_01_01_11);
        send_op(1, 7'd71, 21'h71FFF, 4, 0);

        write_tag(7'd72, 2'd0, 21'h72001, 1, 1); write_tag(7'd72, 2'd1, 21'h72002, 1, 1);
        write_tag(7'd72, 2'd2, 21'h72003, 1, 1); write_tag(7'd72, 2'd3, 21'h72004, 1, 1);
        set_ages(7'd72, 8'b01_01_01_11);
        send_op(0, 7'd72, 21'h72FFF, 4, 0);

        write_tag(7'd73, 2'd0, 21'h73001, 1, 1); write_tag(7'd73, 2'd1, 21'h73002, 1, 1);
        write_tag(7'd73, 2'd2, 21'h73003, 1, 1); write_tag(7'd73, 2'd3, 21'h73004, 1, 1);
        set_ages(7'd73, 8'b01_01_01_11);
        send_op(1, 7'd73, 21'h73FFF, 4, 0);

        write_tag(7'd74, 2'd0, 21'h74001, 1, 1); write_tag(7'd74, 2'd1, 21'h74002, 1, 1);
        write_tag(7'd74, 2'd2, 21'h74003, 1, 1); write_tag(7'd74, 2'd3, 21'h74004, 1, 1);
        set_ages(7'd74, 8'b01_01_01_11);
        send_op(0, 7'd74, 21'h74FFF, 4, 0);

        $display("---");
        $display("hits=%0d misses=%0d total=%0d hit_rate=%0.1f%%",
            hits, misses, hits+misses,
            (hits * 100.0) / (hits + misses));
        $display("avg access time = %0.1f cycles", total_cycles * 1.0 / (hits + misses));
    end

endmodule
