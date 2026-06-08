module cache_ctrl
(
    	input clk, rst_b,
    	input cpu_req,          
    	input cpu_wr,           
    	input mem_ready,        
	input [(2**/*index_size*/7)*/*tag_size*/21*/*set_size*/4-1:0] tags,
	input [(2**/*index_size*/7)*/*set_size*/4-1:0] valid_bits,
	input [(2**/*index_size*/7)*/*set_size*/4-1:0] dirty_bits,
	input [(2**/*index_size*/7)*/*set_size*/4*/*bits_needed_to_represent_age*/2-1:0] age_bits,
	input [6:0] index_to_test,
	input [20:0] tag_to_test,
    	output cpu_done,        
    	output [14:0] c        
);

wire hit, dirty_victim;

cache_hit #(.set_size(4),.tag_size(21),.index_size(7)) test_hit
(
	.index(index_to_test),
	.tags(tags),
	.valid(valid_bits),
	.tag_to_test(tag_to_test),
	.hit(hit)
);

check_lru_dirty_4wayAssoc_cache #(.index_size(7)) test_dirty
(
	.index(index_to_test),
	.valid_bits(valid_bits),
	.dirty_bits(dirty_bits),
	.age_bits(age_bits),
	.dirty(dirty_victim)
);

cache_ctrl_CU CU
(
    	.clk(clk),
	.rst_b(rst_b),
    	.cpu_req(cpu_req),          
    	.cpu_wr(cpu_wr),           
    	.hit(hit),              
    	.dirty_victim(dirty_victim),     
    	.mem_ready(mem_ready),        
    	.cpu_done(cpu_done),        
    	.c(c)         
);

endmodule