
//multiplexor cell

module mux_1sel #(parameter size=1)
(
	input sel,
	input [size-1:0] value1,value0,
	output [size-1:0] q
);

genvar i;
generate
	for(i=0;i<size;i=i+1) begin: loop
		assign q[i]=(value1[i] & sel) | (value0[i] & (~sel));
	end
endgenerate

endmodule
