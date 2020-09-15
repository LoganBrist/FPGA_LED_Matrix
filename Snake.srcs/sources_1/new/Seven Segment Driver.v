`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Logan Brist
// 
// Create Date: 04/09/2018 07:44:15 PM
// Finish Date: 04/16/2018
// Design Name: 
// Module Name: SEGdriver
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
// 7 Segment driver to be used as an instantiated module. Any connection that connects to periphials on the FPGA board need passed through the instantiated module I/O and also the top module I/O.
//
// Deriving update clock frequency:
// 8 digits need cycles every 60Hz --> clock of N > 480Hz --> divide global clock evenly 480 times --> every 200k cycles needs to be a complete cycle. 100k counter.
 
//////////////////////////////////////////////////////////////////////////////////
 
 //SEGdriver  SEGdriver_0(CLK, NUMBER, DECIMALS,  UPDATE, RESET, ANODE_OUT, CATHODE_OUT) 


module SEGdriver(
    input CLK, //Global on-board 100MHz clock, needs passed through the top module of the project.
    input [31:0] INPUT, //user's 8 digit number to display.
    input [7:0] DP,     //user's desired decimals to activate.                             
    input UPDATE_EN,    //Enables saving a new input to the 7 segment display.
    input RST,          //Reset
    output reg [7:0] ANODES, //on-board 7 segment anodes, set low to enable. Needs passed through the top module of the project.
    output reg [7:0] CATHODES //on-board 7 segment cathodes, set low to enable. Needs passed through the top module of the project.
    );
   
   //Display refresh counter
   reg [16:0] REFRESH_COUNTER; 
   reg REFRESH_CLK;
     
    //Registers 
    reg [2:0]  SEL = 0;              //Activated anode counter.
    reg [3:0] SAVEDNUMBER [7:0];     //Eight 4-bit registers holding digits.
    reg [7:0] SAVED_DP;              //holds decimal place on/off info.
 
/////////////////////////////////////////////////////////////////////////////////////////////   
always @(posedge CLK or posedge RST) begin

  REFRESH_COUNTER <= REFRESH_COUNTER + 1;
  
  if(REFRESH_COUNTER >= 17'd100000) begin 
         REFRESH_CLK <= ~REFRESH_CLK; 
         REFRESH_COUNTER <= 0; 
  end

 if(RST) begin 
    SAVED_DP <= 8'hFF;
   {SAVEDNUMBER[7],SAVEDNUMBER[6],SAVEDNUMBER[5],SAVEDNUMBER[4],SAVEDNUMBER[3],SAVEDNUMBER[2],SAVEDNUMBER[1],SAVEDNUMBER[0]} <= 32'd0;
 end
 else if (UPDATE_EN) begin
    SAVED_DP <= DP;
    {SAVEDNUMBER[7],SAVEDNUMBER[6],SAVEDNUMBER[5],SAVEDNUMBER[4],SAVEDNUMBER[3],SAVEDNUMBER[2],SAVEDNUMBER[1],SAVEDNUMBER[0]} <= INPUT;
  end
  
 end //end @(posedge CLK_100MHz)
 
 ///////////////////////////////////////////////////////////////////////////////////////////
 always @(posedge REFRESH_CLK) begin
 
 SEL <= SEL + 1;
 CATHODES[7] <= SAVED_DP[SEL];
 
 case(SAVEDNUMBER[SEL])
            4'h0: CATHODES[6:0] <= 7'b1000000;  //ZERO;
            4'h1: CATHODES[6:0] <= 7'b1111001; //ONE;
            4'h2: CATHODES[6:0] <= 7'b0100100; //TWO;
            4'h3: CATHODES[6:0] <= 7'b0110000; //THREE;
            4'h4: CATHODES[6:0] <= 7'b0011001; //FOUR;
            4'h5: CATHODES[6:0] <= 7'b0010010; //FIVE;
            4'h6: CATHODES[6:0] <= 7'b0000010; //SIX;
            4'h7: CATHODES[6:0] <= 7'b1111000; //SEVEN;
            4'h8: CATHODES[6:0] <= 7'b0000000; //EIGHT;
            4'h9: CATHODES[6:0] <= 7'b0011000; //NINE;
            4'hA: CATHODES[6:0] <= 7'b0001000; //A;
            4'hB: CATHODES[6:0] <= 7'b0000011; //B;
            4'hC: CATHODES[6:0] <= 7'b1000110; //C;
            4'hD: CATHODES[6:0] <= 7'b0100001; //D;
            4'hE: CATHODES[6:0] <= 7'b0000110; //E;
            4'hF: CATHODES[6:0] <= 7'b0001110; //F;
            default: CATHODES[6:0] <= 7'b1111111; //NULL; //All cases covered. Never going to happen.
          endcase
 
   case(SEL)
   3'b000:  ANODES <= 8'b11111110; 
   3'b001:  ANODES <= 8'b11111101; 
   3'b010:  ANODES <= 8'b11111011; 
   3'b011:  ANODES <= 8'b11110111; 
   3'b100:  ANODES <= 8'b11101111;
   3'b101:  ANODES <= 8'b11011111;
   3'b110:  ANODES <= 8'b10111111;
   3'b111:  ANODES <= 8'b01111111;
  default:  ANODES <= 8'b11111111;
  endcase
  
end //end @(posedge REFRESH_CLK)

endmodule
