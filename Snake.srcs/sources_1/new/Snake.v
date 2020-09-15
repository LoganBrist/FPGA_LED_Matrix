`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2018 10:00:53 PM
// Design Name: 
// Module Name: DRAW_FUNCTION
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Snake(
// DRAW_FUNCTION Draw1(5_bit X output, 5-bit Y output, 24-bit COLOR output, USERFLAG output, CLK input, 32-bit FRAME_ID input);
///////////////////////////////////////////////////////////    
  //User drawing interface
  output reg [4:0] X = 0,           //X pixel
  output reg [4:0] Y = 0,           //Y pixel
  output reg [23:0] COLOR = 0,      //24 bit data for pixel
  output reg USER_FLAG = 0,         //USER sets when ready to skip to next frame. May not be needed if frame id is slower than the user drawing. 
  output wire [31:0] numba,
  input wire CLK,               //Clock data into buffer, one pixel per clock
  input wire [31:0] FRAME_ID,   //changed when buffers swap    
  input wire BTN_L,
  input wire BTN_R
    );



//Score Counter
assign numba = {score[15:0]-4,topscore[15:0]};


reg [10:0] PIXELNUMBER  = 11'd0; //first 10 bits count to 1023
reg [31:0]FRAME_ID_LAST = 31'b0;
reg             DRAW_EN = 1'b1; 

//Memory
reg [4:0] X_Head = 5'd1;
reg [4:0] Y_Head = 5'd1;
reg [4:0] X_Head_past;
reg [4:0] Y_Head_past;
reg [1:0] Direction     = 0;
reg [1:0] DirectionIncrement = 0;
reg BTN         = 0;
reg BTN_PAST    = 0;
reg BTN_POSEDGE = 0;
integer score = 4;
integer topscore = 0;
reg [9:0] readBodyAddr  = 0;
reg [9:0] writeBodyAddr = 0;
reg [9:0] writeBodyData = 0;
reg writeEn = 1'b1;
wire [9:0] BodyData;
integer SEQUENCE = 5; //0-Load head 1-refresh memory 2-draw frame 3-hold editing 4- end game 5-starting screen


Snake_Memory #(10, 1024) BodyMemory(readBodyAddr, writeBodyAddr, writeBodyData, writeEn, BodyData, CLK); //ten bit counter for each pixel
reg [31:0] speed_counter = 0; 
wire [31:0] spd =  31'd30 - (31'd1 * (score - 4)); //number of frames to wait before moving snake. Moves from 30-10 frames  
wire [31:0] speed; 
assign speed = (spd < 10) ? 31'd10 :
               (spd > 30) ? 31'd10 : spd ; //windows speed to count from 30 and then stay at 10

//Random Number
wire [9:0] Fruit;
reg GetNewFruit = 1'b0;
RandomNumberGenerator #(10) num(GetNewFruit,CLK,Fruit);

//starting screen data
reg [31:0] screentimer = 0;
wire [23:0] startingscreendata;
load BM(PIXELNUMBER,startingscreendata); 

//////////////////////////////////////////////////////////////////////////////
//at clock
always @(posedge CLK) begin
FRAME_ID_LAST <= FRAME_ID; //detect frame change, cannot be in another always block for some reason. multiple drivers for the net issue
if(FRAME_ID != FRAME_ID_LAST)                  begin USER_FLAG <= 1'b0; DRAW_EN <= 1'b1; end   //resets USER's "drawing is ready" flag and enables local drawing of the next frame
if (PIXELNUMBER == 11'd1024 && SEQUENCE == 2)  begin USER_FLAG <= 1'b1; DRAW_EN <= 1'b0; end   //if all pixels are drawn, disable drawing mode and send ready flag to LED Driver 


/////////////////////////////////////////////////////////////////////////////
//Game Sequence
 
//No draw condition 
if (!DRAW_EN) begin end  

//Update head location   
else if(SEQUENCE == 0) begin 
   writeBodyAddr <= {Y_Head,X_Head};
   writeBodyData <= score [9:0];
  
   case (Direction)
       2'b00: begin X_Head <= X_Head + 1; Y_Head <= Y_Head; end
       2'b01: begin X_Head <= X_Head; Y_Head <= Y_Head + 1; end
       2'b10: begin X_Head <= X_Head - 1; Y_Head <= Y_Head; end
       2'b11: begin X_Head <= X_Head; Y_Head <= Y_Head - 1; end
   endcase 
   SEQUENCE <= 1; //2 to skip body        
end  
       
//Refresh memory and game logic          
else if(SEQUENCE == 1) begin 
     readBodyAddr <=  PIXELNUMBER + 1; //Body data at PIXELNUMBER needs loaded fully in this same cycle, so the future one is used. 
     writeBodyAddr <= PIXELNUMBER;
     PIXELNUMBER <= PIXELNUMBER + 1;
     if(BodyData > 0) begin writeBodyData <= BodyData - 1;  end
     else             begin writeBodyData <= BodyData; end
     if(PIXELNUMBER == 11'd1024) begin SEQUENCE <= 2; PIXELNUMBER <= 0; end  
     
     //logic
     if (({Y_Head,X_Head} == PIXELNUMBER) && (BodyData > 0)) begin 
          score <= 4;
          SEQUENCE <= 4; //end game
          if (score >= topscore) begin topscore <= score-4; end 
          end 
     if (({Y_Head,X_Head}) == PIXELNUMBER && ({Y_Head,X_Head} == Fruit))  begin score <= score + 1; GetNewFruit <= 1; end
     else if ((Fruit == PIXELNUMBER) && (BodyData > 0)) begin GetNewFruit <= 1; end
     else                                          begin GetNewFruit <= 0; end
   end
   
//draw frame   
else if(SEQUENCE == 2) begin 
      readBodyAddr <= PIXELNUMBER + 1;   
      PIXELNUMBER <= PIXELNUMBER + 1;
      Y <= PIXELNUMBER[9:5];
      X <= PIXELNUMBER[4:0];
      
      if({Y_Head,X_Head} == {PIXELNUMBER[9:5],PIXELNUMBER[4:0]}) begin COLOR <= {8'd200,8'd100,8'd0};  end
      else if(BodyData > 0)              begin COLOR <= {8'd100,8'd100,8'd100};  end
      else if(Fruit == PIXELNUMBER)      begin COLOR <= {8'd0,8'd0,8'd200};  end
      else             begin COLOR <= {8'd0,8'd0,8'd0};  end
      if(PIXELNUMBER == 11'd1024) begin SEQUENCE <= 3; PIXELNUMBER <= 0; end
    end
   
//holds memory altering until desired frame    
else if(SEQUENCE == 3) begin 
   speed_counter <= speed_counter + 1;
   if (speed_counter >= speed)  begin SEQUENCE <= 0; speed_counter <= 0; end 
   else                         begin SEQUENCE <= 2; end     
   end
   
//end game   
else if(SEQUENCE == 4) begin  
     readBodyAddr <= PIXELNUMBER;   
     PIXELNUMBER <= PIXELNUMBER + 1;
     Y <= PIXELNUMBER[9:5];
     X <= PIXELNUMBER[4:0];
     COLOR <= 24'd0;
     
     //new
     writeBodyData <= 0;
     
     if(PIXELNUMBER == 11'd1024) begin SEQUENCE <= 5; PIXELNUMBER <= 0; end
  
          
end  

else if(SEQUENCE == 5) begin 

    if (DRAW_EN) begin
        PIXELNUMBER <= PIXELNUMBER + 1;
        Y <= PIXELNUMBER[9:5];
        X <= PIXELNUMBER[4:0];
        //copy data from bitmap text file
        COLOR <= startingscreendata;
        if(PIXELNUMBER == 11'd1024) begin PIXELNUMBER <= 0; USER_FLAG <= 1'b1; DRAW_EN <= 1'b0; end
    end    
    
    //title screen ends with timer
    screentimer <= screentimer + 1;
    if (screentimer >= 1000000) begin SEQUENCE <= 0; screentimer <= 0; end 
    
    //title screen ends at button press (doesnt work well?)
    //if (BTN) begin SEQUENCE <= 0; end   
end 


//End game sequence   
/////////////////////////////////////////////////////////////////////////////
//User Control (need positive edge buttons)
//needs to take buttons and produce a direction for the head to travel at any one time.

    BTN         <= ({BTN_L,BTN_R} > 0)  ? 1'b1 : 1'b0 ; //are buttons pressed
    BTN_PAST    <= BTN; //were buttons pressed
    BTN_POSEDGE <= ((BTN_PAST==0) && (BTN>0)) ? 1'b1: 1'b0; //flag for buttons being held.

    if (BTN_POSEDGE) begin
       case ({BTN_L,BTN_R})
        2'b00: begin DirectionIncrement <= 2'b00; end
        2'b01: begin DirectionIncrement <= 2'b01; end
        2'b10: begin DirectionIncrement <= 2'b10; end
        2'b11: begin DirectionIncrement <= 2'b00; end
       endcase    
    end
    
    if (DirectionIncrement > 0) begin 
      case (DirectionIncrement)
           2'b00: begin Direction <= Direction; end
           2'b01: begin Direction <= Direction + 1; end
           2'b10: begin Direction <= Direction - 1; end
           2'b11: begin Direction <= Direction; end
      endcase
      DirectionIncrement <= 2'b00;
    end

end //end @(posedge CLK)   
endmodule

//Additional modules
//////////////////////////////////////////////////////////////////////////////
module RandomNumberGenerator
#(
parameter integer data_width = 16 
)
(
input wire Request,
input wire CLK,
output wire [data_width-1:0] Number 
    );

reg [9:0] pointer = 0;
reg [31:0] numberlist[9:0];
  
 initial begin
   $readmemh("RandomNumbers.txt", numberlist); 
      end 
      
always @(posedge Request && CLK) begin 
pointer <= pointer + 1;
end    

assign Number = numberlist[pointer];

endmodule

//////////////////////////////////////////////////////////////////////////////
module Snake_Memory
  #(
     parameter integer bW = 10, //1024 count
     parameter integer eC = 1024,
     parameter integer aW=$clog2(eC)
     )
   (
    input  wire [aW-1:0] readAddr,
    input  wire [aW-1:0] writeAddr,
    input  wire [bW-1:0] writeData,
    input  wire          writeEn,
    output wire [bW-1:0] readData,
    input  wire          clk
    );

   reg [bW-1:0]         mem[eC-1:0];

   assign readData = mem[readAddr];

   
   always @(posedge clk)
     if( writeEn )
       mem[writeAddr] <= writeData ; // probably should be non-blocking

endmodule

//////////////////////////////////////////////////////////////////////////////
//bitmap loader
module load(
    input wire [9:0] index,
    output wire [23:0] data
    );
 
     reg [23:0] image1 [1023:0];
     integer i;
      
     initial begin
       $readmemh("snake.txt", image1);
      end 
         
     assign data = image1[index];
                   
    endmodule
