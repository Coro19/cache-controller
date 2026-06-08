module check_lru_dirty_4wayAssoc_cache #(parameter index_size=7)
(
	input [index_size-1:0] index,
	input [(2**index_size)*4-1:0] valid_bits,
	input [(2**index_size)*4-1:0] dirty_bits,
	input [(2**index_size)*8-1:0] age_bits,
	output dirty
);

wire [2**index_size-1:0] dirty_set;

genvar i;
generate
	for(i=0;i<2**index_size;i=i+1) begin: loop1
		check_lru_dirty_4wayAssoc_set checki
		(
			.valid_bits(valid_bits[ (i+1)*4-1:i*4 ]),
			.dirty_bits(dirty_bits[ (i+1)*4-1:i*4 ]),
			.age_bits(age_bits[ (i+1)*8-1:i*8 ]),
			.dirty(dirty_set[i])
		);
	end
endgenerate

mux #(.input_size(1),.sel_size(index_size)) mux
(
	.sel(index),
	.in(dirty_set),
	.out(hit)
);

endmodule