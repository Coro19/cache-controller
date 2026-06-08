
//multiplexor cell, any number (2 to the power sel_size) and size (input_size) 
//of inputs

module mux #(parameter input_size=1,parameter sel_size=1)
(
	input [sel_size-1:0] sel,
	input [(2**sel_size)*input_size-1:0] in,
	output [input_size-1:0] out
);

wire [(2**(sel_size+1)-1)*input_size-1:0] aux;

assign out={aux[input_size-1:0]};
assign aux[ (2**(sel_size+1)-1)*input_size-1:(2**sel_size-1)*input_size ]={in};

genvar i;
genvar j;
generate
	for(i=0;i<sel_size;i=i+1) begin: loop1
		for(j=0;j<2**i;j=j+1) begin: loop2
			mux_1sel #(.size(input_size)) muxij
			(
				.sel(sel[sel_size-i-1]),
				.value0({aux[ (2**(i+1)+2*j)*input_size-1:(2**(i+1)+2*j-1)*input_size ]}),
				.value1({aux[ (2**(i+1)+2*j+1)*input_size-1:(2**(i+1)+2*j)*input_size ]}),
				.q({aux[ (2**i+j)*input_size-1:(2**i+j-1)*input_size ]})
			);
		end
	end
endgenerate

endmodule
