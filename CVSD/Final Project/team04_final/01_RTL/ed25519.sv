`define WIDTH_MUL 256
`define WIDTH_ADD 256
`define WIDTH_DATA 256


module ADD_SUB #( 
	parameter WIDTH = `WIDTH_ADD, 
	parameter mod = 0
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
	input  wire				addsub,
    output wire [WIDTH-1:0] out
);
	reg [WIDTH-1:0] out1;
	reg [WIDTH-1:0] out2;

	assign out = out1;

	always_comb begin
		if (addsub == 0) begin
			out1 = a + b;
		end
		else begin
			out1 = a - b ;
		end
		if (out1 >= mod) begin
			if (addsub == 0)
				out1 -= mod;
			else 
				out1 += mod;
		end
	end
endmodule


module MAC #( 
	parameter WIDTH = `WIDTH_ADD, 
	parameter c = 19
)(
    input  wire [WIDTH*2-1:0] a,
    output wire [WIDTH-1:0] out
);
	wire [WIDTH+4:0] reg0;

	
	assign reg0 = a[254:0] + a[WIDTH*2-1:255] * 19;
	assign out = reg0[254:0] + reg0[WIDTH+4:255] * 19;


endmodule



module ed25519 (
	input         i_clk,
	input         i_rst,
	input         i_in_valid,
	input  [63:0] i_in_data,
	input 		  i_out_ready,
	output        o_in_ready,
	output        o_out_valid,
	output [63:0] o_out_data
);


// ----------------
//  const
// ----------------

localparam [255:0] CONST_Q = (256'b1 << 255) - 19;
localparam [255:0] CONST_Q_INV = 256'd21330121701610878104342023554231983025602365596302209165163239159352418617883;
localparam [255:0] CONST_Q_MINUS_2 = CONST_Q-2;
// localparam [255:0] CONST_D = 256'h164115ad394fe29372c9c903de0c43480850c3bbd7e314b9c076c5ff6fa3f4fd;
localparam [255:0] CONST_D = 256'h52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3;
localparam [255:0] CONST_19_8 = 256'd16983563041;
localparam [255:0] CONST_19_2 = 256'd361;
localparam [255:0] CONST_19 = 256'd19;



// ----------------
//  wire & reg
// ----------------
reg [1:0] cur_state, next_state;
reg [2:0] cur_state_mul, next_state_mul;
reg [2:0] cur_state_reduce, next_state_reduce;


// reg out_valid, out_valid_ff;
reg [63:0] out_data, out_data_ff;
reg [3:0] count_input, count_input_ff;
reg [3:0] count_add, count_add_ff;
reg [7:0] count_mul, count_mul_ff;



reg [`WIDTH_DATA-1:0] M, M_ff;
reg [`WIDTH_DATA-1:0] x_raw, x_raw_ff;
reg [`WIDTH_DATA-1:0] y_raw, y_raw_ff;

reg [`WIDTH_DATA-1:0] mm_x, mm_x_ff;
reg [`WIDTH_DATA-1:0] mm_y, mm_y_ff;
reg [`WIDTH_DATA*2-1:0] mm_reg0, mm_reg0_ff;

// reg [`WIDTH_DATA-1:0] mm_xyq, mm_xyq_ff;
// reg [`WIDTH_DATA-1:0] mm_xyqq, mm_xyqq_ff;

reg [`WIDTH_DATA-1:0] add_0_x, add_0_x_ff;
reg [`WIDTH_DATA-1:0] add_0_y, add_0_y_ff;
reg [`WIDTH_DATA-1:0] add_0_z, add_0_z_ff;
reg [`WIDTH_DATA-1:0] add_1_x, add_1_x_ff;
reg [`WIDTH_DATA-1:0] add_1_y, add_1_y_ff;
reg [`WIDTH_DATA-1:0] add_1_z, add_1_z_ff;

reg [`WIDTH_DATA-1:0] add_reg0, add_reg0_ff;
reg [`WIDTH_DATA-1:0] add_reg1, add_reg1_ff;
reg [`WIDTH_DATA-1:0] add_reg2, add_reg2_ff;

reg [`WIDTH_DATA-1:0] add_add_a;
reg [`WIDTH_DATA-1:0] add_add_b;
reg add_add_ctrl;

reg [`WIDTH_DATA-1:0] reduce_reg0, reduce_reg0_ff;
reg [`WIDTH_DATA-1:0] reduce_add_a;
reg [`WIDTH_DATA-1:0] reduce_add_b;
reg reduce_add_ctrl;



// ----------------
//  Multiplier & Adder
// ----------------
reg [`WIDTH_MUL-1:0] mult1_a;
reg [`WIDTH_MUL-1:0] mult1_b;
reg [`WIDTH_MUL*2-1:0] prod1;

reg [`WIDTH_ADD-1:0] add1_a;
reg [`WIDTH_ADD-1:0] add1_b;
reg [`WIDTH_ADD-1:0] sum1;
reg add1_ctrl;

reg [`WIDTH_ADD*2-1:0] mac_a;
reg [`WIDTH_ADD-1:0] mac_out;

DW02_mult #(.A_width(`WIDTH_MUL), .B_width(`WIDTH_MUL)) M1 ( .A(mult1_a), .B(mult1_b), .TC(1'b0), .PRODUCT(prod1) );

ADD_SUB #( .WIDTH(`WIDTH_ADD), .mod(CONST_Q) ) add_sub1 (.a(add1_a), .b(add1_b), .addsub(add1_ctrl), .out(sum1) );

MAC #( .WIDTH(`WIDTH_ADD), .c(19)) MAC1( .a(mac_a), .out(mac_out));


// DW01_addsub #(`WIDTH_ADD) A1 ( .A(add1_a), .B(add1_b), .CI(add1_carryin), .ADD_SUB(add1_ctrl), .SUM(sum1), .CO(add1_carryout) );
// DW01_addsub #(`WIDTH_ADD) A2 ( .A(add2_a_ff), .B(add2_b_ff), .CI(0), .ADD_SUB(add2_ctrl_ff), .SUM(sum2), .CO(add2_carryout) );

// DW01_cmp2 #(width) C1 ( .A(inst_A), .B(inst_B), .LEQ(inst_LEQ), .TC(inst_TC), .LT_LE(LT_LE_inst), .GE_GT(GE_GT_inst) );

// DW02_mult_2_stage #(.A_width(`TEST_WIDTH), .B_width(`TEST_WIDTH)) U1 ( .A(x_raw_ff), .B(y_raw_ff), .TC(0), .CLK(i_clk), .PRODUCT(prod) );
// DW01_add #(.width(`TEST_WIDTH)) U1 (.A(x_raw_ff), .B(y_raw_ff), .CI(0), .SUM(sum), .CO(dummy) );


// ----------------
//  parameters
// ----------------

localparam S_input = 0;
localparam S_mul_3 = 1;
localparam S_reduce = 2;
localparam S_output = 3;


localparam S_mul_idle_0 = 0;
localparam S_mul_double = 1;
localparam S_mul_idle_1 = 2;
localparam S_mul_add = 3;


localparam S_reduce_z0 = 0;
localparam S_reduce_z1 = 1;
localparam S_reduce_x = 2;
localparam S_reduce_y = 3;
localparam S_reduce_last = 4;
// localparam S_reduce_idle_1 = 3;
// localparam S_reduce_y = 4;


// ----------------
//  FLAG
// ----------------
wire FLAG_READ_DATA;
wire FLAG_SHIFT_M;
wire FLAG_Q_MINUS;
wire FLAG_OUTPUT_DATA;
// wire FLAG_LAST_MUL;

assign FLAG_READ_DATA = i_in_valid && o_in_ready;
assign FLAG_SHIFT_M = (cur_state == S_mul_3 && cur_state_mul == S_mul_idle_0);
assign FLAG_Q_MINUS = CONST_Q_MINUS_2[255-count_mul_ff];
assign FLAG_OUTPUT_DATA = (i_out_ready && o_out_valid);

// assign FLAG_LAST_MUL = ((count_mul_ff == 254) && 
// 						(cur_state_mul == S_mul_idle_0 || cur_state_mul == S_mul_idle_1) && 
// 						(next_state == S_mul_double));

// ----------------
//  state FSM
// ----------------

always @(posedge i_clk) begin
	if (i_rst) begin
		cur_state <= S_input;
		cur_state_mul <= S_mul_idle_0;
		cur_state_reduce <= S_reduce_z0;
	end
	else begin
		cur_state <= next_state;
		cur_state_mul <= next_state_mul;
		cur_state_reduce <= next_state_reduce;
	end
end

always_comb begin
	next_state = cur_state;
	case(cur_state)
	S_input: begin
		if (count_input == 12) next_state = S_mul_3;
	end
	S_mul_3: begin
		if (count_mul_ff == 0 && cur_state_mul == S_mul_double) 
			next_state = S_reduce;
	end
	S_reduce: begin
		if (cur_state_reduce == S_reduce_last && count_add_ff == 2)
			next_state = S_output;
	end
	endcase
end

always_comb begin
	next_state_mul = cur_state_mul;
	if (cur_state == S_mul_3) begin
		case(cur_state_mul)
		S_mul_idle_0: begin
			next_state_mul = S_mul_double;
		end
		S_mul_double: begin
			if (count_add_ff == 11) begin
				if (M_ff[255]) next_state_mul = S_mul_idle_1;
				else next_state_mul = S_mul_idle_0;
			end
		end
		S_mul_idle_1: begin
			next_state_mul = S_mul_add;
		end
		S_mul_add: begin
			if (count_add_ff == 11) 
				next_state_mul = S_mul_idle_0; 
		end
		endcase
	end
end

always_comb begin
	next_state_reduce = cur_state_reduce;
	if (cur_state == S_reduce) begin
		case(cur_state_reduce)
		S_reduce_z0: begin
			if (count_add_ff == 1) begin
				if (FLAG_Q_MINUS) begin
					next_state_reduce = S_reduce_z1;
				end
			end
		end
		S_reduce_z1: begin
			if (count_add_ff == 1) begin
				if (count_mul_ff == 255)
					next_state_reduce = S_reduce_x;
				else 
					next_state_reduce = S_reduce_z0;
			end
		end
		S_reduce_x: begin
			if (count_add_ff == 1) begin
				next_state_reduce = S_reduce_y;
			end
		end
		S_reduce_y: begin
			if (count_add_ff == 2) begin
				next_state_reduce = S_reduce_last;
			end
		end
		S_reduce_last: begin
			if (count_add_ff == 2) begin
				next_state_reduce = S_reduce_z0;
			end
		end
		endcase
	end
end


// ----------------
//  I/O
// ----------------

assign o_in_ready = (cur_state == S_input);
assign o_out_valid = (cur_state == S_output);
assign o_out_data = x_raw_ff[255:192];

always_comb begin
	y_raw = y_raw_ff;
	x_raw = x_raw_ff;
	M = M_ff;

	if (FLAG_READ_DATA || FLAG_OUTPUT_DATA) begin
		y_raw = {y_raw_ff[191:0], i_in_data};
		x_raw = {x_raw_ff[191:0], y_raw_ff[255:192]};
		M = {M_ff[191:0], x_raw_ff[255:192]};
	end
	else if (cur_state == S_reduce) begin
		if (cur_state_reduce == S_reduce_y && count_add_ff == 0)
			x_raw = mac_out;
		else if (cur_state_reduce == S_reduce_y && count_add_ff == 1)
			x_raw = sum1;
		else if (cur_state_reduce == S_reduce_y && count_add_ff == 2 && x_raw_ff[0])
			x_raw = sum1;

		if (cur_state_reduce == S_reduce_last && count_add_ff == 0)
			y_raw = mac_out; 
		else if (cur_state_reduce == S_reduce_last && count_add_ff == 1)
			y_raw = sum1;
		else if (cur_state_reduce == S_reduce_last && count_add_ff == 2 && y_raw_ff[0])
			y_raw = sum1;
	end
	if (FLAG_SHIFT_M) begin
		M = M_ff << 1;
	end
end


// ----------------
//  COUNT
// ----------------


always_comb begin
	if(FLAG_READ_DATA)
		count_input = count_input_ff + 1; 
	else
		count_input = count_input_ff;
end

always_comb begin
	if (cur_state == S_mul_3) begin
		if ((cur_state_mul == S_mul_add || cur_state_mul == S_mul_double) && next_state == cur_state) begin
			count_add = count_add_ff + 1;
		end
		else begin
			count_add = 0;
		end
	end
	else if (cur_state == S_reduce) begin
		count_add = count_add_ff + 1;
		if (cur_state_reduce == S_reduce_y || cur_state_reduce == S_reduce_last) begin
			if (count_add_ff == 2)
				count_add = 0;
		end
		else if (count_add_ff == 1)
			count_add = 0;
	end
	else begin
		count_add = 0;
	end
end


always_comb begin
	if (cur_state == S_mul_3) begin
		if (cur_state_mul == S_mul_idle_0) begin
			count_mul = count_mul_ff + 1;
		end
		else begin
			count_mul = count_mul_ff;
		end
	end
	else if (cur_state == S_reduce) begin
		if ((cur_state_reduce == S_reduce_z0 && count_add_ff == 0)) begin
			count_mul = count_mul_ff + 1;
		end
		else begin
			count_mul = count_mul_ff;
		end
	end
	else begin
		count_mul = 0;
	end
end


// ----------------
//  MM_CTRL
// ----------------

always_comb begin
	mult1_a = mm_x_ff;
	mult1_b = mm_y_ff;
end


always_comb begin
	mm_reg0 = prod1;
	mac_a = mm_reg0_ff;
end

always_comb begin
	add1_a = 0;
	add1_b = 0;
	add1_ctrl = 0;

	if (cur_state == S_mul_3) begin
		add1_a = add_add_a;
		add1_b = add_add_b;
		add1_ctrl = add_add_ctrl;
	end
	else if (cur_state == S_reduce) begin
		add1_a = reduce_add_a;
		add1_b = reduce_add_b;
		add1_ctrl = reduce_add_ctrl;	
	end
end


// ----------------
//  S_mul_3_CTRL
// ----------------

always_comb begin

	mm_x = 0;
	mm_y = 0;
	add_add_a = 0;
	add_add_b = 0;
	add_add_ctrl = 0;

	reduce_add_a = CONST_Q;
	reduce_add_b = x_raw_ff;
	reduce_add_ctrl = 1;

	add_0_x = add_0_x_ff;
	add_0_y = add_0_y_ff;
	add_0_z = add_0_z_ff;
	add_1_x = add_1_x_ff;
	add_1_y = add_1_y_ff;
	add_1_z = add_1_z_ff;

	add_reg0 = add_reg0_ff;
	add_reg1 = add_reg1_ff;
	add_reg2 = add_reg2_ff;

	reduce_reg0 = reduce_reg0_ff;

	if (cur_state == S_mul_3) begin
		case(cur_state_mul)
		S_mul_double, S_mul_add: begin
			case(count_add_ff)
			0: begin
				mm_x = add_1_x_ff;
				mm_y = add_0_y_ff;

				if (count_mul_ff != 1) begin
					add_0_z = mac_out;
				end

				if (cur_state_mul == S_mul_double) begin
					add_1_z = add_0_z;
				end
				else begin
					add_1_z = 1'b1;
				end
			end
			1: begin
				mm_x = add_0_x_ff;
				mm_y = add_1_y_ff;

				add_add_a = add_0_x_ff;
				add_add_b = add_0_y_ff;
				add_add_ctrl = 0;
				add_reg1 = sum1;

			end
			2: begin
				mm_x = add_reg1_ff;
				mm_y = sum1;

				add_reg0 = mac_out;

				add_add_a = add_1_x_ff;
				add_add_b = add_1_y_ff;
				add_add_ctrl = 0;

			end
			3: begin
				mm_x = mac_out;
				mm_y = add_reg0_ff;

				add_reg1 = mac_out;
			end
			4: begin
				mm_x = add_0_z_ff;
				mm_y = add_1_z_ff;

				add_reg1 = mac_out;

				add_add_a = add_reg1_ff;
				add_add_b = add_reg0_ff;
				add_add_ctrl = 0;
				add_reg0 = sum1;
			end
			5: begin
				mm_x = mac_out;
				mm_y = CONST_D;

				add_add_a = add_reg1_ff;
				add_add_b = add_reg0_ff;
				add_add_ctrl = 1;
				add_reg1 = sum1;
			end
			6: begin
				mm_x = mac_out;
				mm_y = mac_out;

				add_0_z = mac_out;
			end
			7: begin
				mm_x = add_0_z_ff;
				mm_y = add_reg0_ff;

				add_reg0 = mac_out;
			end
			8: begin	
				mm_x = add_0_z_ff;
				mm_y = add_reg1_ff;

				add_0_z = mac_out;
			end
			9: begin
				mm_x = mac_out;
				mm_y = sum1;

				add_add_a = add_0_z_ff;
				add_add_b = add_reg0_ff;
				add_add_ctrl = 1;
				add_reg1 = sum1;
			end
			10: begin
				mm_x = mac_out;
				mm_y = sum1;

				add_add_a = add_0_z_ff;
				add_add_b = add_reg0_ff;
				add_add_ctrl = 0;
				add_reg0 = sum1;
			end
			11: begin
				mm_x = add_reg1_ff;
				mm_y = add_reg0_ff;

				add_0_x = mac_out;
			end
			endcase
		end

		S_mul_idle_0: begin
			if (count_mul_ff != 0) begin
				add_0_y = mac_out;
			end

			add_1_x = add_0_x_ff;
			add_1_y = add_0_y;

			add_reg0 = 0;
			add_reg1 = 0;
		end
		S_mul_idle_1: begin
			add_0_y = mac_out;

			add_1_x = x_raw_ff;
			add_1_y = y_raw;

			add_reg0 = 0;
			add_reg1 = 0;
		end

		endcase
	end
	else if (cur_state == S_reduce) begin
		case(cur_state_reduce)
		S_reduce_z0: begin
			if (count_add_ff == 0 && count_mul_ff !=0 )
				reduce_reg0 = mac_out;
			mm_x = reduce_reg0;
			mm_y = reduce_reg0;
		end
		S_reduce_z1: begin
			if (count_add_ff == 0)
				reduce_reg0 = mac_out;
			mm_x = reduce_reg0;
			mm_y = add_0_z_ff;
		end
		S_reduce_x: begin
			if (count_add_ff == 0)
				reduce_reg0 = mac_out;
			mm_x = reduce_reg0;
			mm_y = add_0_x_ff;
		end
		S_reduce_y: begin
			if (count_add_ff == 1) begin
				reduce_add_a = x_raw_ff;
				reduce_add_b = 0;
				reduce_add_ctrl = 0;
			end
			else if (count_add_ff == 2) begin
				reduce_add_a = CONST_Q;
				reduce_add_b = x_raw_ff;
				reduce_add_ctrl = 1;
			end

			mm_x = reduce_reg0;
			mm_y = add_0_y_ff;
		end
		S_reduce_last: begin
			if (count_add_ff == 1) begin
				reduce_add_a = y_raw_ff;
				reduce_add_b = 0;
				reduce_add_ctrl = 0;
			end
			else if (count_add_ff == 2) begin
				reduce_add_a = CONST_Q;
				reduce_add_b = y_raw_ff;
				reduce_add_ctrl = 1;
			end
		end
		endcase
	end
end



// ----------------
//  FLIP-FLOP
// ----------------



always @(posedge i_clk) begin
	if (i_rst) begin
		out_data_ff <= 0;
		count_input_ff <= 0;
		count_add_ff <= 15;
		count_mul_ff <= 0;

		M_ff <= 0;
		x_raw_ff <= 0;
		y_raw_ff <= 0;

		mm_x_ff <= 0;
		mm_y_ff <= 0;
		mm_reg0_ff <= 0;
	
		add_0_x_ff <= 0;
		add_0_y_ff <= 1;
		add_0_z_ff <= 1;
		add_1_x_ff <= 0;
		add_1_y_ff <= 0;
		add_1_z_ff <= 0;

		add_reg0_ff <= 0;
		add_reg1_ff <= 0;
		add_reg2_ff <= 0;
		
		reduce_reg0_ff <= 1;
	end
	else begin
		out_data_ff <= out_data;
		count_input_ff <= count_input;
		count_add_ff <= count_add;
		count_mul_ff <= count_mul;

		M_ff <= M;
		x_raw_ff <= x_raw;
		y_raw_ff <= y_raw;

		mm_x_ff <= mm_x;
		mm_y_ff <= mm_y;
		mm_reg0_ff <= mm_reg0;

		add_0_x_ff <= add_0_x;
		add_0_y_ff <= add_0_y;
		add_0_z_ff <= add_0_z;
		add_1_x_ff <= add_1_x;
		add_1_y_ff <= add_1_y;
		add_1_z_ff <= add_1_z;

		add_reg0_ff <= add_reg0;
		add_reg1_ff <= add_reg1;
		add_reg2_ff <= add_reg2;

		reduce_reg0_ff <= reduce_reg0;
	end
end


// reg [15:0] latency, latency_ff;

// always_comb begin
// 	latency = latency_ff + 1;
// end

// always @(posedge i_clk, posedge i_rst) begin
// 	if (i_rst) latency_ff <= 0;
// 	else latency_ff <= latency;
// end

endmodule

// DW01_addsub #(`WIDTH_ADD) A1 ( .A(add1_a), .B(add1_b), .CI(add1_carryin), .ADD_SUB(add1_ctrl), .SUM(sum1), .CO(add1_carryout) );
// DW01_addsub #(`WIDTH_ADD) A2 ( .A(add2_a_ff), .B(add2_b_ff), .CI(0), .ADD_SUB(add2_ctrl_ff), .SUM(sum2), .CO(add2_carryout) );

