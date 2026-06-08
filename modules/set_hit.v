module set_hit #(parameter set_size=4,parameter tag_size=21)
(
	input [tag_size*set_size-1:0] tags,
	input [set_size-1:0] valid,
	input [tag_size-1:0] tag_to_test,
	output hit
);

wire [tag_size*set_size-1:0] tag_xor;
wire [set_size-1:0] tag_equal;

genvar i;
genvar j;
generate
	for(i=0;i<set_size;i=i+1) begin: loop1
		for(j=0;j<tag_size;j=j+1) begin: loop2
			assign tag_xor[ tag_size*i+j ]=tags[ tag_size*i+j ] ^ tag_to_test[j];
		end

		assign tag_equal[i]=~(|tag_xor[ tag_size*(i+1)-1:tag_size*i ]);
	end

assign hit=|(tag_equal & valid);

endgenerate

endmodule