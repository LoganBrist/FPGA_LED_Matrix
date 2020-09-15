`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2018 04:27:35 PM
// Design Name: 
// Module Name: LEDMATRIX_DRIVER
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
// Requirement timeline:
// x 1. Get a single color loaded onto screen (interface)
// x 2. Load different colors on different rows (row select)
// x 3. Load different colors onto the same row (load timing)
// x 4. Load a basic RGB image (frame generation) 5/18/18
// x 5. Implement hues for an RGB image (PWM) 
//   6. Load different images based on frame ID (animation) - two buffers. Current frame buffer is continuously loaded
//                                                       until the other is updated by the user, then it loads the other.
// x 7. Gamma correction

//////////////////////////////////////////////////////////////////////////////////
//Module and IO

module LEDdriver(   
//Global clock 
    input GLOBAL_CLK,
    
//drawing signals    
    input [4:0] X,      //user X location input
    input [4:0] Y,      //user Y location input
    input [23:0] COLOR, //user 24-bit pixel color input
    input USER_FLAG,
    output reg [31:0] FRAME_ID = 0,
    
//PMOD signals     
    output [7:0] PMOD_C,
    output [7:0] PMOD_D
    );
    
    
//output signal splitting
 
    //top half of the display data  
        reg R1 = 0;
        reg B1 = 0;
        reg G1 = 0; 
    //bottom half of the display data  
        reg R2 = 0;
        reg G2 = 0;
        reg B2 = 0;
    //marks arrival of each bit of data   
        wire CLK_MATRIX;
    //marks the end of a row of data (latches whats in the shift registers)
        reg LAT = 0;
    //switches LEDs off when switching rows  
        reg OE = 0; 
    //select which two rows to light up with the data   
        wire A;
        wire B;
        wire C;
        wire D;
    //Grounds   
        wire GND1;
        wire GND2;
        wire GND3; 

assign PMOD_C = {GND2,GND1,B2,G2,R2,B1,G1,R1};
assign PMOD_D = {GND3,OE,LAT,CLK_MATRIX,D,C,B,A};

///////////////////////////////////////////////////////////////////////////////////////////////////////
//Parameter list  
  parameter integer BitDepth = 24; 
  parameter integer nRows = 32;
  parameter integer nCols = 32;
  
  //future parameters
  parameter integer R_Depth = 8;
  parameter integer G_Depth = 8;
  parameter integer B_Depth = 8;
  parameter integer RefreshRate = 60;
  parameter integer PWMdepth   = 256;

  parameter integer frequency = RefreshRate * (nRows / 2) * nCols * PWMdepth;
  parameter integer clockdivisor = 100000000 / (frequency/2); //global clock divided by one half required frequency. (assuming output clock only finishes half a cycle when divisor count is reached) =12.7 ~ 12 at 60Hz 
  parameter integer Brightness = 1;
  
  assign {GND1,GND2,GND3} = 3'b000;  
        
///////////////////////////////////////////////////////////////////////////////////////////////////////
//Creates new clocks
//reg [1:0] count = 0;
reg [3:0] count = 0;
reg         CLK = 0;

wire CLKUSER;
wire CLKDRIVER;
assign CLKDRIVER = CLK;
assign CLK_MATRIX = CLK;     //Driver and Matrix provided clock 
assign CLKUSER = GLOBAL_CLK; //Drawing user's provided clock

always @(posedge GLOBAL_CLK) begin 
count <= count + 1;
//if (count == 2'd3) begin CLK <= ~CLK; end
if (count >= 2'd3) begin CLK <= ~CLK; count <= 0; end // 100Mhz / 12 Hz signal = 7.86 Mhz
end    

///////////////////////////////////////////////////////////////////////////////////////////////////////
//User's drawing function

always @(posedge CLKUSER) begin 
   readAddrUSER <= 0;
   writeAddrUSER <= {Y,X};
   writeDataUSER <= COLOR;
   writeEnUSER <= ~USER_FLAG;
  end


/////////////////////////////////////////////////////////////////////////////////////////////////////
//Buffer control
reg DRIVERFLAG = 0;  //flag for Driver to set when it is done with a refresh cycle.
reg BUFFER_SEL = 0; //toggle between buffers;

//swaps buffers
always @(posedge (CLKDRIVER && USER_FLAG && DRIVERFLAG)) begin  
      BUFFER_SEL <= ~BUFFER_SEL;
      FRAME_ID <= FRAME_ID + 1;
end

///////////////////////////////////////////////////////////////////////////////////////////////////////
//Memory

//memory inputs
wire [9:0] readAddrA;
wire [9:0] writeAddrA;
wire [BitDepth-1:0] writeDataA;
wire writeEnA;
wire [BitDepth-1:0] dataA;
wire CLKA;
wire [9:0] readAddrB;
wire [9:0] writeAddrB;
wire [BitDepth-1:0] writeDataB;
wire writeEnB;
wire [BitDepth-1:0] dataB;
wire CLKB;

///user's access to memory
reg [9:0] readAddrUSER;
reg [9:0] writeAddrUSER;
reg [BitDepth-1:0] writeDataUSER;
reg writeEnUSER;
wire [BitDepth-1:0] dataUSER;

//Driver's access to memory
wire [9:0] readAddrDRIVER;
wire [9:0] writeAddrDRIVER;
wire [BitDepth-1:0] writeDataDRIVER;
wire writeEnDRIVER;
wire [BitDepth-1:0] dataDRIVER;

assign readAddrDRIVER  = {ROW_COUNT, COL_COUNT}; 
assign writeAddrDRIVER = 0;
assign writeDataDRIVER = 0;
assign writeEnDRIVER = 0;

//Multiplexing, to control which buffer is being written to by User and which is being read from by Driver.
assign {readAddrA,writeAddrA,writeDataA,writeEnA,CLKA} =  BUFFER_SEL ? {readAddrUSER,writeAddrUSER,writeDataUSER,writeEnUSER, CLKUSER} : {readAddrDRIVER,writeAddrDRIVER,writeDataDRIVER, writeEnDRIVER, CLKDRIVER}; 
assign {readAddrB,writeAddrB,writeDataB,writeEnB,CLKB} = ~BUFFER_SEL ? {readAddrUSER,writeAddrUSER,writeDataUSER,writeEnUSER, CLKUSER} : {readAddrDRIVER,writeAddrDRIVER,writeDataDRIVER, writeEnDRIVER, CLKDRIVER}; 

//dual port additions, for reading bottom half of the display in the same clock cycle.
wire [9:0] readAddrDRIVER2;
assign readAddrDRIVER2  = {ROW_COUNT+16,COL_COUNT};
wire [BitDepth-1:0] dataDRIVER2;
wire [BitDepth-1:0] dataA2;
wire [BitDepth-1:0] dataB2;
wire [9:0] readAddrA2;
wire [9:0] readAddrB2;
assign readAddrA2 = readAddrDRIVER2;
assign readAddrB2 = readAddrDRIVER2;
assign dataDRIVER2 = ~BUFFER_SEL ? dataA2 : dataB2;

//output multiplexing
assign dataUSER   =  BUFFER_SEL ? dataA : dataB;
assign dataDRIVER = ~BUFFER_SEL ? dataA : dataB;

//memory module instantiation
memory #(BitDepth, nRows*nCols) BufferA(readAddrA, writeAddrA, writeDataA, writeEnA, dataA, CLKA, readAddrA2, dataA2);
memory #(BitDepth, nRows*nCols) BufferB(readAddrB, writeAddrB, writeDataB, writeEnB, dataB, CLKB, readAddrB2, dataB2);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Prepares data from buffer
wire [7:0] RED_DATA;
wire [7:0] GREEN_DATA;
wire [7:0] BLUE_DATA;
wire [7:0] RED_DATA2;
wire [7:0] GREEN_DATA2;
wire [7:0] BLUE_DATA2;

//Gamma correction- routed through a lookup table.  
GammaLUT gamma1(dataDRIVER [15:8], RED_DATA);
GammaLUT gamma2(dataDRIVER [7:0], GREEN_DATA);
GammaLUT gamma3(dataDRIVER [23:16], BLUE_DATA);
GammaLUT gamma4(dataDRIVER2 [15:8], RED_DATA2);
GammaLUT gamma5(dataDRIVER2 [7:0], GREEN_DATA2);
GammaLUT gamma6(dataDRIVER2 [23:16], BLUE_DATA2);
//here data is changed from rgb to gbr, due to bitmap save format in bitmap applications. 
//COLOR format will need to be sent to this module in format COLOR <= {G,B,R}

///////////////////////////////////////////////////////////////////////////////////////////////////////
//Driver
reg [4:0] COL_COUNT          = 5'd0; //32 
reg [3:0] ROW_COUNT          = 4'd0; //16
reg [7:0] PWM_COUNT          = 8'd0; //256 

assign {A,B,C,D} = ROW_COUNT; // Example: {A,B,C,D} = 4'b0100; selects 5th and 21st row

//constant refresh of screen
always @(posedge CLKDRIVER) begin 
    OE <= 0;
    COL_COUNT <= COL_COUNT + 1;    
    
    if (COL_COUNT == 5'd31) begin LAT <= 1; PWM_COUNT <= PWM_COUNT + 1;  end //When a row is complete, increase PWM counter. Also latches data.
    else                    begin LAT <= 0; PWM_COUNT <= PWM_COUNT;      end

    if ((PWM_COUNT == 8'd255) && (COL_COUNT == 5'd31))begin ROW_COUNT <= ROW_COUNT + 1;            end //When a row PWM is complete, proceed to the next row.
    else                                              begin ROW_COUNT <= ROW_COUNT;                end

//When matrix is drawn, give buffer a chance to switch. 
if ((ROW_COUNT == 4'd15) && (COL_COUNT == 5'd31) && (PWM_COUNT == 8'd255)) begin DRIVERFLAG <= 1'b1; end 
else                                                                       begin DRIVERFLAG <= 1'b0; end


//set memory inputs
R1 <= (RED_DATA > PWM_COUNT)    ? 1'b1 : 1'b0; 
G1 <= (GREEN_DATA > PWM_COUNT)  ? 1'b1 : 1'b0;
B1 <= (BLUE_DATA > PWM_COUNT)   ? 1'b1 : 1'b0;
R2 <= (RED_DATA2 > PWM_COUNT)   ? 1'b1 : 1'b0; 
G2 <= (GREEN_DATA2 > PWM_COUNT) ? 1'b1 : 1'b0;
B2 <= (BLUE_DATA2 > PWM_COUNT)  ? 1'b1 : 1'b0;

end //end @(posedge CLK)

///////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule


//Additional modules
module memory
  #(
     parameter integer bW = 3, //r g b
     parameter integer eC = 1024,
     parameter integer aW=$clog2(eC)
     )
   (
    input  wire [aW-1:0] readAddr,
    input  wire [aW-1:0] writeAddr,
    input  wire [bW-1:0] writeData,
    input  wire          writeEn,
    output wire [bW-1:0] readData,
    input  wire          clk,
    
    input  wire [aW-1:0] readAddr2,
    output wire [bW-1:0] readData2
    );

   reg [bW-1:0]         mem[eC-1:0];

   assign readData = mem[readAddr];
   assign readData2 = mem[readAddr2];
   
   always @(posedge clk)
     if( writeEn )
       mem[writeAddr] <= writeData ; // probably should be non-blocking

endmodule



module GammaLUT(
input wire  [7:0] data,
output wire [7:0] data_updated);
 
 reg [7:0] gamma [255:0];
 integer i;
  
 initial begin
   $readmemh("GammaHEX.txt", gamma); 
   for(i=0;i<255;i=i+1)  begin           
   $display ("gamma[%d]=%h",i,gamma[i]); end  
      end 
      
 assign data_updated = gamma[data]; 
endmodule


   /*{      0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
          0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,
          1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,
          2,  3,  3,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,
          5,  6,  6,  6,  6,  7,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10,
         10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16,
         17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 24, 24, 25,
         25, 26, 27, 27, 28, 29, 29, 30, 31, 32, 32, 33, 34, 35, 35, 36,
         37, 38, 39, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 50,
         51, 52, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 66, 67, 68,
         69, 70, 72, 73, 74, 75, 77, 78, 79, 81, 82, 83, 85, 86, 87, 89,
         90, 92, 93, 95, 96, 98, 99,101,102,104,105,107,109,110,112,114,
        115,117,119,120,122,124,126,127,129,131,133,135,137,138,140,142,
        144,146,148,150,152,154,156,158,160,162,164,167,169,171,173,175,
        177,180,182,184,186,189,191,193,196,198,200,203,205,208,210,213,
        215,218,220,223,225,228,231,233,236,239,241,244,247,249,252,255 };
*/