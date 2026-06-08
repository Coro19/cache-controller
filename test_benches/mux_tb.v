module mux_tb;

reg [1:0] sel;
reg [3*(2**2)-1:0] in;
wire [2:0] out;

mux #(.input_size(3),.sel_size(2)) test
(
	.sel(sel),
	.in(in),
	.out(out)
);

initial begin
	sel=0;
	in={3'b101,3'b001,3'b110,3'b000};
	forever #50 sel=sel+1;
end

endmodule