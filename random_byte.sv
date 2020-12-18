module random_byte(
	input         clk,
	input         rst,
	output [9:0]	rand_byte // + 2 bit for sprite-rand
);
	logic [31:0] shift_reg;
	logic next;
	assign next = shift_reg[31] ^ shift_reg[30] ^ shift_reg[29] ^ shift_reg[27] ^ shift_reg[0];
	always_ff @(posedge clk, posedge rst)
		if (rst)	shift_reg <= 32'hdeaddaed;
		else 		  shift_reg <= { next, shift_reg[31:1] };
		
	assign rand_byte = shift_reg[10:1];

endmodule: random_byte
