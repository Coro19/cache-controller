module cache_hit #(parameter set_size=4,parameter tag_size=21,parameter index_size=7)
(
	input [index_size-1:0] index,
	input [(2**index_size)*tag_size*set_size-1:0] tags,
	input [(2**index_size)*set_size-1:0] valid,
	input [tag_size-1:0] tag_to_test,
	output hit
);

wire [2**index_size-1:0] hit_set;

genvar i;
generate
	for(i=0;i<2**index_size;i=i+1) begin: loop1
		set_hit #(.set_size(set_size),.tag_size(tag_size)) hiti
		(
			.tags(tags[ (i+1)*tag_size*set_size-1:i*tag_size*set_size ]),
			.valid(valid[ (i+1)*set_size-1:i*set_size ]),
			.tag_to_test(tag_to_test),
			.hit(hit_set[i])
		);
	end
endgenerate

mux #(.input_size(1),.sel_size(index_size)) mux
(
	.sel(index),
	.in(hit_set),
	.out(hit)
);

endmodule