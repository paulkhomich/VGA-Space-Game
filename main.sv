// Display:		  NEC (640x480)
// Input CLK: 	50MHz
// Work CLK: 	  25MHz (ICLK:2)
// FPGA:			  Cyclone IV
// Board:		    E10
// Author:		  Pavel Khomich
module main(
	input	logic			_clk, _rst,
	input logic			up, down,
	output logic		hsync, vsync,
	output logic		active,
	output logic		r, g, b			
);
	// --- FPGA FEATURES ---
	logic clk;
	logic rst;
	assign rst = ~_rst;
	always_ff @(posedge _clk, posedge rst) 
		if (rst)		clk <= '0;
		else			  clk <= ~clk;
	// ----- CONSTANTS & VARIABLES --------
	logic [9:0] hp, vp;
	logic frame;
	logic frame4;
	logic frame8;
	logic frame16;
	logic frame32;
	logic frame128;
	logic [1:0] frame4counter;
	logic [2:0] frame8counter;
	logic [3:0] frame16counter;
	logic [4:0] frame32counter;
	logic [6:0] frame128counter;
	always_ff @(posedge vsync, posedge rst)
		if (rst)		frame4counter <= '0;
		else			frame4counter <= frame4counter + 2'd1;
	assign frame4 = frame4counter == '0;
	always_ff @(posedge vsync, posedge rst)
		if (rst)		frame8counter <= '0;
		else			frame8counter <= frame8counter + 3'd1;
	assign frame8 = frame8counter == '0;
	always_ff @(posedge vsync, posedge rst)
		if (rst)		frame16counter <= '0;
		else			frame16counter <= frame16counter + 4'd1;
	assign frame16 = frame16counter == '0;
	always_ff @(posedge vsync, posedge rst)
		if (rst)		frame32counter <= '0;
		else			frame32counter <= frame32counter + 5'd1;
	assign frame32 = frame32counter == '0;
	always_ff @(posedge vsync, posedge rst)
		if (rst)		frame128counter <= '0;
		else			frame128counter <= frame128counter + 7'd1;
	assign frame128 = frame128counter == '0;
	assign frame = vsync;
	// Horizontal (0-1023 + invis) & Vertical (0-767 + invis) positions
	// Horizontal Timing Constants
	localparam AREA_H 	= 640;
	localparam FP_H 	= 16;
	localparam SYNC_H 	= 96;
	localparam BP_H 	= 48;
	localparam TIMING_H = AREA_H + FP_H + SYNC_H + BP_H;
	// Vertical Timing Constans
	localparam AREA_V 	= 480;
	localparam FP_V		= 10;
	localparam SYNC_V		= 2;
	localparam BP_V		= 33;
	localparam TIMING_V = AREA_V + FP_V + SYNC_V + BP_V;
	// Control Timing Constants
	localparam HSYNC_START = AREA_H + FP_H;
	localparam HSYNC_END   = AREA_H + FP_H + SYNC_H - 1;
	localparam MAX_H 	  = TIMING_H - 1;

	localparam VSYNC_START = AREA_V + FP_V;
	localparam VSYNC_END   = AREA_V + FP_V + SYNC_V - 1;
	localparam MAX_V       = TIMING_V - 1;

	// -------------- VGA LOGIC -----------
	// 			Horizontal Position
	always_ff @(posedge clk, posedge rst)
		if (rst)				hp <= '0;
		else if (hp == MAX_H)	hp <= '0;
		else					hp <= hp + 1'b1;
	// 			Vertical Position
	always_ff @(posedge clk, posedge rst)
		if (rst)				vp <= '0;
		else if (hp == MAX_H) begin
			if (vp == MAX_V)	vp <= '0;
			else 				vp <= vp + 1'b1;
		end
	// 			SYNC Signals Generator
	always_comb begin
		hsync = (HSYNC_START <= hp && hp <= HSYNC_END);
		vsync = (VSYNC_START <= vp && vp <= VSYNC_END);
	end
	// 			Active Indication
	assign active = (hp < AREA_H) && (vp < AREA_V);
	
	
	
	//						  	MAIN PART
	// 			SPRITE RAM + POSITION COUNTERS
	//			     640/16 x 480/16 = 40x30 map

	// SPRITES: 16x16
	// Y: 8-4 3-0
	// X: 9-4 3-0
	// SHIP  
	wire [3:0] ship_sprite_y = vp[3:0];
	wire [3:0] ship_sprite_x = hp[3:0];
	wire [15:0] ship_sprite_line;
	
	logic [4:0] ship_y;
	logic [5:0] ship_x;
	always_ff @(posedge frame8, posedge rst)
		if (rst) 										ship_y <= '0;
		else if (~up && (ship_y != '0))			ship_y <= ship_y - 6'b1;
		else if (~down && (ship_y != 6'd29))	ship_y <= ship_y + 6'b1;
		else												ship_y <= ship_y; // Inverse - FPGA Board Buttons 
	always_ff @(posedge frame, posedge rst)
		if (rst) ship_x <= 7'd3;
		else     ship_x <= ship_x;
	
	rom_ship rom_ship(.y(ship_sprite_y), .bits(ship_sprite_line));
	
	wire pixel_to_screen = (vp[8:4] == ship_y && hp[9:4] == ship_x) ? ship_sprite_line[~ship_sprite_x] : 1'b0;
	
	//+tail
	wire [15:0] tail_sprite_line;
	logic [1:0] tail_frame_counter;
	always_ff @(posedge frame8, posedge rst)
		if (rst)				tail_frame_counter <= '0;
		else					tail_frame_counter <= tail_frame_counter + 2'b1;
	
	rom_tail rom_tail(.y(ship_sprite_y), .frame(tail_frame_counter), .bits(tail_sprite_line));
	
	wire tail_pixel_to_screen = (vp[8:4] == (ship_y) && hp[9:4] == (ship_x - 5'b1)) ? tail_sprite_line[~ship_sprite_x] : 1'b0;
	
	// SCOREBOARD
	localparam score_y_pos = 1;
	localparam score_0_pos = 35;
	localparam score_1_pos = score_0_pos - 1;
	localparam score_2_pos = score_1_pos - 1;
	localparam score_3_pos = score_2_pos - 1;
	
	wire [3:0] score_sprite_y = vp[3:0];
	wire [3:0] score_sprite_x = hp[3:0];
	wire [15:0] score_digit_line;
	wire [1:0] score_num = hp[5:4];
	wire [3:0] digit_to_show;
	
	logic [3:0] score_0;
	logic [3:0] score_1;
	logic [3:0] score_2;
	logic [3:0] score_3;
	always_ff @(posedge ship_in_coin, posedge rst)
		if (rst)	begin
			score_0 <= '0;
			score_1 <= '0;
			score_2 <= '0;
			score_3 <= '0;
		end else begin
			if (score_0 == 4'd9) begin
				score_0 <= '0;
				if (score_1 == 4'd9) begin
					score_1 <= '0;
					if (score_2 == 4'd9) begin
						score_2 <= '0;
						if (score_3 == 4'd9) begin
							score_3 <= '0;
						end else begin
							score_3 <= score_3 + 4'd1;
						end
					end else begin
						score_2 <= score_2 + 4'd1;
					end
				end else begin
					score_1 <= score_1 + 4'd1;
				end
			end else begin
				score_0 <= score_0 + 4'd1;
			end
		end
		
	// Which score digit is showing
	always_comb begin
		case(score_num)
			2'b00: digit_to_show = score_3;
			2'b01: digit_to_show = score_2;
			2'b10: digit_to_show = score_1;
			2'b11: digit_to_show = score_0;
		endcase
	end
		
	digits digits(.digit(digit_to_show), .line(score_sprite_y), .data_line(score_digit_line));
	
	wire score_0_pixel_to_screen = (vp[8:4] == score_y_pos && hp[9:4] == score_0_pos) ? score_digit_line[~score_sprite_x] : 1'b0;
	wire score_1_pixel_to_screen = (vp[8:4] == score_y_pos && hp[9:4] == score_1_pos) ? score_digit_line[~score_sprite_x] : 1'b0;
	wire score_2_pixel_to_screen = (vp[8:4] == score_y_pos && hp[9:4] == score_2_pos) ? score_digit_line[~score_sprite_x] : 1'b0;
	wire score_3_pixel_to_screen = (vp[8:4] == score_y_pos && hp[9:4] == score_3_pos) ? score_digit_line[~score_sprite_x] : 1'b0;
	
	wire score_pixel_to_screen = score_0_pixel_to_screen || score_1_pixel_to_screen || score_2_pixel_to_screen || score_3_pixel_to_screen;
	
	// METEORS
	logic [9:0] rand_byte; // + 2 bit for sprite-rand
	random_byte random_byte(.*);
	// 30 shift regs length 40
	// << << << << << <<
	// from right edge - frame32 random add enemy
	// COLLISION
	wire ship_in_collision = enemies[ship_y][ship_x] == 1'b1;
	wire ship_in_coin = (ship_in_collision) && (sprites[ship_y][{ship_x,1'b0}] == 1'b1) && (sprites[ship_y][{ship_x,1'b1}] == 1'b1);
	wire ship_in_meteor = (ship_in_collision) && (sprites[ship_y][{ship_x,1'b0}] != 1'b1) && (sprites[ship_y][{ship_x,1'b1}] != 1'b1);
	
	logic [39:0] enemies [32]; 
	logic [79:0] sprites [32];
	genvar i;
	generate
		for (i = 0; i < 32; i = i + 1) begin: enemy
			always_ff @(posedge frame8, posedge rst)
				if (rst)		begin
					enemies[i] <= 40'd0;
					sprites[i] <= 2'd0;
				end
				else if (ship_in_coin && ship_y == i) begin
					enemies[i] <= { ((rand_byte[4:0] == i) ? 1'b1 : 1'b0), enemies[i][39:4], 1'b0, enemies[i][2], enemies[i][1] };
					sprites[i] <= { ((rand_byte[4:0] == i) ? rand_byte[9:8] : 2'd0), sprites[i][79:8], 2'b00, sprites[i][5:4], sprites[i][3:2] };
				end
				else			begin
					enemies[i] <= { ((rand_byte[4:0] == i) ? 1'b1 : 1'b0), enemies[i][39:1] };
					sprites[i] <= { ((rand_byte[4:0] == i) ? rand_byte[9:8] : 2'd0), sprites[i][79:2] };
				end
		end
	endgenerate
	// SPRITE
	wire [3:0] meteor_sprite_y = vp[3:0];
	wire [3:0] meteor_sprite_x = hp[3:0];
	wire [1:0] meteor_sprite_is;
	assign meteor_sprite_is[0] = sprites[vp[8:4]][{hp[9:4],1'b0}];
	assign meteor_sprite_is[1] = sprites[vp[8:4]][{hp[9:4],1'b1}];
	wire [15:0] meteor_sprite_line;
	
	rom_meteor rom_meteor(.y(meteor_sprite_y), .sprite(meteor_sprite_is), .bits(meteor_sprite_line));

	
	wire enemie_pixel_to_screen = (enemies[vp[8:4]][hp[9:4]] == 1'b1) ? meteor_sprite_line[~meteor_sprite_x] : 1'b0;
	wire coin_to_screen = enemie_pixel_to_screen && (meteor_sprite_is == 2'b11);	
	
	assign r = (active) ? (!enemie_pixel_to_screen && !pixel_to_screen && !score_pixel_to_screen && !tail_pixel_to_screen && !coin_to_screen) ? 1'b1 : pixel_to_screen || score_pixel_to_screen : 1'b0;
	assign g = (active) ? (!enemie_pixel_to_screen && !pixel_to_screen && !score_pixel_to_screen && !tail_pixel_to_screen && !coin_to_screen) ? 1'b1 : coin_to_screen && enemie_pixel_to_screen : 1'b0;
	assign b = (active) ? (!enemie_pixel_to_screen && !pixel_to_screen && !score_pixel_to_screen && !tail_pixel_to_screen && !coin_to_screen) ? 1'b1 : coin_to_screen && enemie_pixel_to_screen : 1'b0;

	
endmodule: main 
