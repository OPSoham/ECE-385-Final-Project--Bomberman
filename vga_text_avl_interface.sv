	/************************************************************************
Avalon-MM Interface VGA Text mode display

Register Map:
0x000-0x0257 : VRAM, 80x30 (2400 byte, 600 word) raster order (first column then row)
0x258        : control register

VRAM Format:
X->
[ 31  30-24][ 23  22-16][ 15  14-8 ][ 7    6-0 ]
[IV3][CODE3][IV2][CODE2][IV1][CODE1][IV0][CODE0]

IVn = Draw inverse glyph
CODEn = Glyph code from IBM codepage 437

Control Register Format:
[[31-25][24-21][20-17][16-13][ 12-9][ 8-5 ][ 4-1 ][   0    ] 
[[RSVD ][FGD_R][FGD_G][FGD_B][BKG_R][BKG_G][BKG_B][RESERVED]

VSYNC signal = bit which flips on every Vsync (time for new frame), used to synchronize software
BKG_R/G/B = Background color, flipped with foreground when IVn bit is set
FGD_R/G/B = Foreground color, flipped with background when Inv bit is set

************************************************************************/
`define NUM_REGS 601 //80*30 characters / 4 characters per register
`define CTRL_REG 600 //index of control register

module vga_text_avl_interface (
	// Avalon Clock Input, note this clock is also used for VGA, so this must be 50Mhz
	// We can put a clock divider here in the future to make this IP more generalizable
	input logic CLK,
	
	// Avalon Reset Input
	input logic RESET,
	
	// Avalon-MM Slave Signals
	input  logic AVL_READ,					// Avalon-MM Read
	input  logic AVL_WRITE,					// Avalon-MM Write
	input  logic AVL_CS,					// Avalon-MM Chip Select
	input  logic [3:0] AVL_BYTE_EN,			// Avalon-MM Byte Enable
	input  logic [11:0] AVL_ADDR,			// Avalon-MM Address
	input  logic [31:0] AVL_WRITEDATA,		// Avalon-MM Write Data
	output logic [31:0] AVL_READDATA,		// Avalon-MM Read Data
	
	// Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
	output logic [3:0]  red, green, blue,	// VGA color channels (mapped to output pins in top-level)
	output logic hs, vs						// VGA HS/VS
);

logic [31:0] color_palette [8];	// Color Palette
//put other local variables here
logic blank, sync, VGA_Clk;
logic [9:0] drawxsig, drawysig;
//logic [31:0] word, read_temp, write_temp;
logic [31:0] word_data;
logic [15:0] char;
logic [7:0] font_data_char;
//logic bit_idk, inverse;
//logic [31:0] control_reg;
logic [11:0] word;
logic [10:0] font_addr, RAM_ADDR;
logic [31:0] ram_b_out, temp_out, RAM_READDATA;
logic [3:0] BKG_IDX, FGD_IDX;

//Declare submodules..e.g. VGA controller, ROMS, etc

vga_controller vgacontrol(.Reset(RESET), .Clk(CLK), .hs(hs), .vs(vs), .pixel_clk(VGA_Clk), .blank(blank), .sync(sync), .DrawX(drawxsig), .DrawY(drawysig));

font_rom fonty (.addr(font_addr), .data(font_data_char)); 

//color_mapper colormap(.DrawX(drawxsig), .DrawY(drawysig), .Red(red), .Green(green), .Blue(blue));
//ram get_ramdata (
//	.address_a(AVL_ADDR),
//	.address_b(),
//	.byteena_a(AVL_BYTE_EN),
//	.clock(CLK),
//	.data_a(write_temp), // 
//	.data_b(),
//	.rden_a(AVL_READ),
//	.rden_b(),
//	.wren_a(AVL_WRITE),
//	.wren_b(),
//	.q_a(read_temp),
//	.q_b());
   
ram_new get_ramdata ( .address_a(AVL_ADDR),
									.address_b(word[11:1]),  //NEEDS TO CHANGE
									.byteena_a(AVL_BYTE_EN),
									.clock(CLK),
									.data_a(AVL_WRITEDATA), // 
									.data_b(), 
									.rden_a(AVL_READ & ~AVL_ADDR[11] & AVL_CS),
									.rden_b(1'b1), //always high?
									.wren_a(AVL_WRITE & ~AVL_ADDR[11] & AVL_CS),
									.wren_b(1'b0),  //always high?
									.q_a(RAM_READDATA),
									.q_b(ram_b_out));	
									

									
always_ff @(posedge CLK) 
begin
	
	if(AVL_CS & AVL_ADDR[11] & AVL_WRITE)
		begin
			case (AVL_BYTE_EN)
				4'b0001 : color_palette[AVL_ADDR[2:0]][7:0] <= AVL_WRITEDATA[7:0];  
				4'b0010 : color_palette[AVL_ADDR[2:0]][15:8] <= AVL_WRITEDATA[15:8];
				4'b0100 : color_palette[AVL_ADDR[2:0]][23:16] <= AVL_WRITEDATA[23:16];
				4'b1000 : color_palette[AVL_ADDR[2:0]][31:24] <= AVL_WRITEDATA[31:24];
				4'b0011 : color_palette[AVL_ADDR[2:0]][15:0] <= AVL_WRITEDATA[15:0];
				4'b1100 : color_palette[AVL_ADDR[2:0]][31:16] <= AVL_WRITEDATA[31:16];
				4'b1111 : color_palette[AVL_ADDR[2:0]][31:0] <= AVL_WRITEDATA[31:0];
	
				default: ;
				//else comb error make make color paalette 32'bX;
			endcase
		end
	else if(AVL_CS &  AVL_ADDR[11] & AVL_READ)
		begin

				temp_out<= color_palette[AVL_ADDR[2:0]];

		end
end

always_comb
begin

	if(AVL_READ & ~AVL_ADDR[11] & AVL_CS)
		begin
			
			AVL_READDATA = RAM_READDATA;
		end
	else if (AVL_READ & AVL_ADDR[11] & AVL_CS)
		begin
			AVL_READDATA = temp_out;
		end
	else
		begin
			AVL_READDATA = 32'hX;
		end
end


// Read and write from AVL interface to register block, note that READ waitstate = 1, so this should be in always_ff
//always_ff @(posedge CLK) begin
//
//if (RESET)
//begin
//end
//
//if(AVL_CS)
//	begin
//	
//	if (AVL_READ)
//		begin
//		
//		AVL_READDATA <= read_temp;
//		
//		end
//
//	else if (AVL_WRITE)	
//		begin
//		
//			case (AVL_BYTE_EN)
//				4'b0001 : write_temp[7:0] <= AVL_WRITEDATA[7:0];  
//				4'b0010 : write_temp[15:8] <= AVL_WRITEDATA[15:8];
//				4'b0100 : write_temp[23:16] <= AVL_WRITEDATA[23:16];
//				4'b1000 : write_temp[31:24] <= AVL_WRITEDATA[31:24];
//				4'b0011 : write_temp[15:0] <= AVL_WRITEDATA[15:0];
//				4'b1100 : write_temp[31:16] <= AVL_WRITEDATA[31:16];
//				4'b1111 : write_temp[31:0] <= AVL_WRITEDATA[31:0];
//	
//				default: ;
//			endcase
//		end
//	 else if (AVL_ADDR == 600)
//		begin
//		
//	end
//	
//end


//handle drawing (may either be combinational or sequential - or both).



always_comb 
	begin
	word = drawysig[9:4] * 80 + drawxsig[9:3];		//MATH
	//word_data = LOCAL_REG[word[11:2]]; //week 1	
	//RAM_ADDR = word[11:1]
	word_data = ram_b_out; 				//MATH

		//week 2
	if(word[0] == 1'b0) // check which of the two chars to print
		begin
			char = word_data[15:0]; //encoded fontcode and color of code 0
		end
	else 
		begin
			char = word_data[31:16]; //encoded fontcode and color of code 1
		end

	
	
	//week 1
	//case(word[1:0])
//	if(word[1:0] == 2'b00)
//		begin
//			
//			char = word_data[7:0];
//		end
//	else if(word[1:0] == 2'b01)
//		begin
//			
//			char = word_data[15:8];
//		end
//	else if(word[1:0] == 2'b10)
//		begin
//			
//			char = word_data[23:16];
//		end
//	else if(word[1:0] == 2'b11)
//		begin
//		
//			char = word_data[31:24];
//		end
//	else
//		begin
//		end
	
	
	

	//inverse = char[7];
	//font_addr = ((char[6:0]*16) + drawysig[3:0]);	//week 1
	font_addr = ((char[14:8] * 16) + drawysig[3:0]);
//	control_reg = LOCAL_REG[`CTRL_REG];
	//bit_idk = font_data_char[7 - drawxsig[2:0]];

	end 


always_ff @(posedge VGA_Clk) begin	

	
	if(blank) 
		begin
		
		if(font_data_char[7 - drawxsig[2:0]] ^ char[15])
		//if(font_data_char[7 - drawxsig[2:0]] ^ char[7])
			begin
			//FGD
			
			FGD_IDX = char[7:4];
			if(FGD_IDX[0] == 1'b0) //even color number. so right most to access in color palette
				begin
					red = color_palette[FGD_IDX[3:1]][12:9];
					green = color_palette[FGD_IDX[3:1]][8:5];
					blue = color_palette[FGD_IDX[3:1]][4:1];
				end
			else if(FGD_IDX[0] == 1'b1) //odd color number. so left most to access in color palatte
				begin
					red = color_palette[FGD_IDX[3:1]][24:21];
					green = color_palette[FGD_IDX[3:1]][20:17];
					blue = color_palette[FGD_IDX[3:1]][16:13];
				end
		
			end
		
		
		else
			begin
			//BGD
			BKG_IDX = char[3:0];
			if(BKG_IDX[0] == 1'b0) //even color number. so right most to access in color palette
				begin
					red = color_palette[BKG_IDX[3:1]][12:9];
					green = color_palette[BKG_IDX[3:1]][8:5];
					blue = color_palette[BKG_IDX[3:1]][4:1];
				end
			else if(BKG_IDX[0] == 1'b1) //odd color number. so left most to access in color palatte
				begin
					red = color_palette[BKG_IDX[3:1]][24:21];
					green = color_palette[BKG_IDX[3:1]][20:17];
					blue = color_palette[BKG_IDX[3:1]][16:13];
				end

			end
		end
	else 
		begin
		red = 4'h0;
		blue = 4'h0;
		green = 4'h0;
	
		end

	end
endmodule
