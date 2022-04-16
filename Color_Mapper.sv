//-------------------------------------------------------------------------
//    Color_Mapper.sv                                                    --
//    Stephen Kempf                                                      --
//    3-1-06                                                             --
//                                                                       --
//    Modified by David Kesler  07-16-2008                               --
//    Translated by Joe Meng    07-07-2013                               --
//                                                                       --
//    Fall 2014 Distribution                                             --
//                                                                       --
//    For use with ECE 385 Lab 7                                         --
//    University of Illinois ECE Department                              --
//-------------------------------------------------------------------------

module  color_mapper ( input        [9:0] user1X, user1Y, bomb1X, bomb1Y, bomb1S, user1S,
							  input 			[9:0] user2X, user2Y, bomb2X, bomb2Y, bomb2S, user2S,
							  input		   [9:0] DrawX, DrawY,
							  input 		   [3:0] data_out,
							  input			Clk,
							  
                       output logic [7:0]  Red, Green, Blue);
  logic user1_on;
  logic bomb1_on;
  logic user2_on;
  logic bomb2_on;
  logic [7:0] TR, TG, TB;
  logic [3:0] temp_data;
/* 
     New Ball: Generates (pixelated) circle by using the standard circle formula.  Note that while 
     this single line is quite powerful descriptively, it causes the synthesis tool to use up three
     of the 12 available multipliers on the chip!  Since the multiplicants are required to be signed,
	  we have to first cast them from logic to int (signed by default) before they are multiplied). 
*/
	  
    int user1DistX, user1DistY, user1Size, bomb1DistX, bomb1DistY, bomb1Size;
	 int user2DistX, user2DistY, user2Size, bomb2DistX, bomb2DistY, bomb2Size;
	 assign temp_data = data_out;
	 assign user1DistX = DrawX - user1X; //(x-h) 
    assign user1DistY = DrawY - user1Y;
    assign user1Size = user1S;
	 assign bomb1DistX = DrawX - bomb1X;
    assign bomb1DistY = DrawY - bomb1Y;
    assign bomb1Size = bomb1S;
	 
	 assign user2DistX = DrawX - user2X;
    assign user2DistY = DrawY - user2Y;
    assign user2Size = user2S;
	 assign bomb2DistX = DrawX - bomb2X;
    assign bomb2DistY = DrawY - bomb2Y;
    assign bomb2Size = bomb2S;
	 
	 
	 always_ff @(posedge Clk)
		begin
			case(temp_data)
				4'b0001:
					begin
					TR = 8'hff;
					TG = 8'h81;
					TB = 8'h70;
					end
					
				4'b0010:
					begin
					TR = 8'hff;
					TG = 8'hff;
					TB = 8'hff;
					end
					
				4'b0011:
					begin
					TR = 8'h64;
					TG = 8'hb0;
					TB = 8'hff;
					end
					
				4'b0100:
					begin
					TR = 8'h38;
					TG = 8'h87;
					TB =  8'h00;
					end
				default: ;
				endcase
		end
	
    always_comb
    begin
			//User 1 display
        if (DrawX >= user1X && DrawX < user1Y + 10'd256) 
			begin
				if(DrawY >= user1Y && DrawY < user1Y + 10'd256)
				begin
					user1_on = 1'b1;
				end
				else
					begin
					user1_on = 1'b0;
					end
			end		
		  else 
			begin
				user1_on = 1'b0;
			end
			
			
				//Bomb 1 Display
		  if ( ( bomb1DistX*bomb1DistX + bomb1DistY*bomb1DistY) <= (bomb1Size * bomb1Size) ) 
			begin
            bomb1_on = 1'b1;
			end
			
		  else 
			begin
				bomb1_on = 1'b0;
			end
			
			// User 2 Display
			if ( ( user2DistX*user2DistX + user2DistY*user2DistY) <= (user2Size * user2Size) ) 
			begin
            user2_on = 1'b1;
			end
			
		  else 
			begin
				user2_on = 1'b0;
			end
		
			//Bomb 2 Display
		  if ( ( bomb2DistX*bomb2DistX + bomb2DistY*bomb2DistY) <= (bomb2Size * bomb2Size) ) 
			begin
            bomb2_on = 1'b1;
			end
			
		  else 
			begin
				bomb2_on = 1'b0;
			end
end


 always_comb
    begin:RGB_Display
	 
        if ((user1_on == 1'b1)) 
		  begin
						Red = TR;
						Green = TG;
						Blue = TB;
			end 
		  
		  else if ((bomb1_on == 1'b1))
		  begin
				Red = 8'h00;
				Green = 8'hff;
				Blue = 8'h00;
			end
			
		  else if ((bomb2_on == 1'b1))
		  begin
				Red = 8'h00;
				Green = 8'hff;
				Blue = 8'h00;
		  end
		  
		  else if ((user2_on == 1'b1)) 
        begin 
            Red = 8'h00;
            Green = 8'h00;
            Blue = 8'hFF;
        end 
		  
        else 
        begin 
            Red = 8'h00; 
            Green = 8'h00;
            Blue = 8'h00;
        end      
    end 
    
endmodule
