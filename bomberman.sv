//-------------------------------------------------------------------------
//                                                                       --
//                                                                       --
//      For use with ECE 385 Lab 62                                      --
//      UIUC ECE Department                                              --
//-------------------------------------------------------------------------


module bomberman (

      ///////// Clocks /////////
      input     MAX10_CLK1_50, 

      ///////// KEY /////////
      input    [ 1: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LEDR /////////
      output   [ 9: 0]   LEDR,

      ///////// HEX /////////
      output   [ 7: 0]   HEX0,
      output   [ 7: 0]   HEX1,
      output   [ 7: 0]   HEX2,
      output   [ 7: 0]   HEX3,
      output   [ 7: 0]   HEX4,
      output   [ 7: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [15: 0]   DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_CS_N,
      output             DRAM_WE_N,
      output             DRAM_CAS_N,
      output             DRAM_RAS_N,

      ///////// VGA /////////
      output             VGA_HS,
      output             VGA_VS,
      output   [ 3: 0]   VGA_R,
      output   [ 3: 0]   VGA_G,
      output   [ 3: 0]   VGA_B,


      ///////// ARDUINO /////////
      inout    [15: 0]   ARDUINO_IO,
      inout              ARDUINO_RESET_N 

);




logic Reset_h, vssig, blank, sync, VGA_Clk;


//=======================================================
//  REG/WIRE declarations
//=======================================================
	logic SPI0_CS_N, SPI0_SCLK, SPI0_MISO, SPI0_MOSI, USB_GPX, USB_IRQ, USB_RST;
	logic [3:0] hex_num_4, hex_num_3, hex_num_1, hex_num_0; //4 bit input hex digits
	logic [1:0] signs;
	logic [1:0] hundreds;
	logic [9:0] drawxsig, drawysig;
	logic [7:0] Red, Blue, Green;
	logic [7:0] keycode;

//=======================================================
//  Structural coding
//=======================================================
	assign ARDUINO_IO[10] = SPI0_CS_N;
	assign ARDUINO_IO[13] = SPI0_SCLK;
	assign ARDUINO_IO[11] = SPI0_MOSI;
	assign ARDUINO_IO[12] = 1'bZ;
	assign SPI0_MISO = ARDUINO_IO[12];
	
	assign ARDUINO_IO[9] = 1'bZ; 
	assign USB_IRQ = ARDUINO_IO[9];
		
	//Assignments specific to Circuits At Home UHS_20
	assign ARDUINO_RESET_N = USB_RST;
	assign ARDUINO_IO[7] = USB_RST;//USB reset 
	assign ARDUINO_IO[8] = 1'bZ; //this is GPX (set to input)
	assign USB_GPX = 1'b0;//GPX is not needed for standard USB host - set to 0 to prevent interrupt
	
	//Assign uSD CS to '1' to prevent uSD card from interfering with USB Host (if uSD card is plugged in)
	assign ARDUINO_IO[6] = 1'b1;
	
	//HEX drivers to convert numbers to HEX output
	HexDriver hex_driver5 (Red[3:0], HEX5[6:0]);
	assign HEX5[7] = 1'b1;
	
	HexDriver hex_driver4 (Blue[3:0], HEX4[6:0]);
	assign HEX4[7] = 1'b1;
	
	HexDriver hex_driver3 (Green[3:0], HEX3[6:0]);
	assign HEX3[7] = 1'b1;
	
	HexDriver hex_driver0 (temp_data[3:0], HEX0[6:0]);
	assign HEX0[7] = 1'b1;
	
	HexDriver hex_driver1 (adrr_out[3:0], HEX1[6:0]);
	assign HEX1[7] = 1'b1;
	
	//fill in the hundreds digit as well as the negative sign
	//assign HEX1 = {1'b1, ~signs[1], 3'b111, ~hundreds[1], ~hundreds[1], 1'b1};
	assign HEX2 = {1'b1, ~signs[0], 3'b111, ~hundreds[0], ~hundreds[0], 1'b1};
	
	//Assign one button to reset
	assign {Reset_h}=~ (KEY[0]);

	//Our A/D converter is only 12 bit
	assign VGA_R = Red[7:4];
	assign VGA_B = Blue[7:4];
	assign VGA_G = Green[7:4];

//=======================================================
//  Logic Variables
//=======================================================
	 
logic p1bomb, p2bomb, bomb1_exist, bomb2_exist, collide1, collide2;	

logic [9:0] user1xsig, user1ysig, user1sizesig, bomb1xsig, bomb1ysig, bomb1sizesig;
logic [9:0] user2xsig, user2ysig, user2sizesig, bomb2xsig, bomb2ysig, bomb2sizesig;
logic [9:0] wall1xsig, wall1ysig, wall1sizesig;
logic [4:0] data_out;
logic [7:0] TR, TG, TB, wallr, wallg, wallb;
logic [3:0] temp_data, dummy1, dummy2, dummy3, dummy4, adrr_out;

	//remember to rename the SOC as necessary
	nios_soc u0 (
		.clk_clk                           (MAX10_CLK1_50),    //clk.clk
		.reset_reset_n                     (1'b1),             //reset.reset_n
		.altpll_0_locked_conduit_export    (),    			   //altpll_0_locked_conduit.export
		.altpll_0_phasedone_conduit_export (), 				   //altpll_0_phasedone_conduit.export
		.altpll_0_areset_conduit_export    (),     			   //altpll_0_areset_conduit.export    
		.key_external_connection_export    (KEY),    		   //key_external_connection.export

		//SDRAM
		.sdram_clk_clk(DRAM_CLK),            				   //clk_sdram.clk
	   .sdram_wire_addr(DRAM_ADDR),               			   //sdram_wire.addr
		.sdram_wire_ba(DRAM_BA),                			   //.ba
		.sdram_wire_cas_n(DRAM_CAS_N),              		   //.cas_n
		.sdram_wire_cke(DRAM_CKE),                 			   //.cke
		.sdram_wire_cs_n(DRAM_CS_N),                		   //.cs_n
		.sdram_wire_dq(DRAM_DQ),                  			   //.dq
		.sdram_wire_dqm({DRAM_UDQM,DRAM_LDQM}),                //.dqm
		.sdram_wire_ras_n(DRAM_RAS_N),              		   //.ras_n
		.sdram_wire_we_n(DRAM_WE_N),                		   //.we_n

		//USB SPI	
		.spi0_SS_n(SPI0_CS_N),
		.spi0_MOSI(SPI0_MOSI),
		.spi0_MISO(SPI0_MISO),
		.spi0_SCLK(SPI0_SCLK),
																																										
		//USB GPIO
		.usb_rst_export(USB_RST),
		.usb_irq_export(USB_IRQ),
		.usb_gpx_export(USB_GPX),
		
		//LEDs and HEX
		.hex_digits_export({dummy1, dummy2, dummy3, dummy4}),
		.leds_export({hundreds, signs, LEDR}),
		.keycode_export(keycode)
	 );
	 

vga_controller vgacontrol(.Reset(Reset_h), 
								  .Clk(MAX10_CLK1_50), 
								  .hs(VGA_HS), 
								  .vs(VGA_VS), 
								  .pixel_clk(VGA_Clk), 
								  .blank(blank), 
								  .sync(sync), 
								  .DrawX(drawxsig), 
								  .DrawY(drawysig));
								  
color_mapper colormap(.Clk(VGA_Clk),
							 .blank(blank),
							 .user1X(user1xsig), 
							 .user1Y(user1ysig), 
							 .user1S(user1sizesig),
							 .user2X(user2xsig), 
							 .user2Y(user2ysig), 
							 .user2S(user2sizesig),
							 .bomb1X(bomb1xsig), 
							 .bomb1Y(bomb1ysig), 
							 .bomb1S(bomb1sizesig),
							 .bomb2X(bomb2xsig), 
							 .bomb2Y(bomb2ysig), 
							 .bomb2S(bomb2sizesig), 
							 .wall1X(wall1xsig), 
							 .wall1Y(wall1ysig), 
							 .wall1S(wall1sizesig),
							 .DrawX(drawxsig), 
							 .DrawY(drawysig),
							 .wall_R(wallr),
							 .wall_G(wallg),
							 .wall_B(wallb),
							 .Red(Red), 
							 .Green(Green), 
							 .Blue(Blue));


user1 player1(.Reset(Reset_h), 
					  .frame_clk(VGA_VS),
					  .keycode(keycode),
					  .damage(),
					  .heart(),
					  .wall1X(wall1xsig),
					  .wall1Y(wall1ysig),
					  .wall1S(wall1sizesig),
					  .bomb2X(bomb2xsig),
					  .bomb2Y(bomb2ysig),
					  .bomb2S(bomb2sizesig),
					  .userX(user1xsig),
					  .userY(user1ysig),
					  .bomb_drop(p1bomb),
					  .userS(user1sizesig),
					  .collide(collide1));
					  
user2 player2(.Reset(Reset_h), 
					  .frame_clk(VGA_VS),
					  .keycode(keycode),
					  .damage(),
					  .heart(), 
					  .wall1X(wall1xsig),
					  .wall1Y(wall1ysig),
					  .wall1S(wall1sizesig),
					  .bomb1X(bomb1xsig),
					  .bomb1Y(bomb1ysig),
					  .bomb1S(bomb1sizesig),
					  .userX(user2xsig),
					  .userY(user2ysig),
					  .bomb_drop(p2bomb),
					  .userS(user2sizesig),
					  .collide(collide2));

bomb player1_bomb(.Reset(Reset_h), 
					  .frame_clk(VGA_VS),
					  .make(p1bomb),
					  .explode(collide2),
					  .userX(user1xsig),
					  .userY(user1ysig),		
					  
					  .bomb_check(bomb1_exist),
					  .bombS(bomb1sizesig),
					  .bombX(bomb1xsig),
					  .bombY(bomb1ysig));

bomb player2_bomb(.Reset(Reset_h), 
					  .frame_clk(VGA_VS),
					  .make(p2bomb),
					  .explode(collide1),
					  .userX(user2xsig),
					  .userY(user2ysig),		
					  
					  .bomb_check(bomb2_exist),
					  .bombS(bomb2sizesig),
					  .bombX(bomb2xsig),
					  .bombY(bomb2ysig));
					  
walls wall_make(.Reset(Reset_h), 
					  .frame_clk(VGA_VS),
					  .wall1X(wall1xsig),
					  .wall1Y(wall1ysig),
					  .wall1S(wall1sizesig),
					  .wall_R(wallr),
					  .wall_G(wallg),
					  .wall_B(wallb));
					  

endmodule
