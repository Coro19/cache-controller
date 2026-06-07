
//D-flipflop cell used in implementing all the types of registers 

module d_ff
(
	input clk,rst_b,set_b,load,data,
	output reg q,
	output q_b
);

assign q_b=~q;

always @(posedge clk or negedge rst_b or negedge set_b)
begin
	if(rst_b==1'b0)
		q<=1'b0;
	else if(set_b==1'b0)
		q<=1'b1;
	else if(load==1'b1)
		q<=data;
	else
		q<=q;
end

endmodule
