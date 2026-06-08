module check_lru_dirty_4wayAssoc_set
(
	input [3:0] valid_bits,
	input [3:0] dirty_bits,
	input [7:0] age_bits,
	output dirty
);

wire a,b,c,d;

assign a=age_bits[0] & age_bits[1];
assign b=age_bits[2] & age_bits[3];
assign c=age_bits[4] & age_bits[5];
assign d=age_bits[6] & age_bits[7];

wire [1:0] sel; //selects the index in the set of the lru block

assign sel[1]=(~a) & (~b) & (c | d);
assign sel[0]=(~a) & (b | ((~c) & d));

mux #(.input_size(1),.sel_size(2)) mux
(
	.sel(sel),
	.in(dirty_bits & valid_bits),
	.out(dirty)
);

endmodule