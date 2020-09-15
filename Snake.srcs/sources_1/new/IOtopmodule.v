`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/31/2018 04:26:10 PM
// Design Name: 
// Module Name: IOtopmodule
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
//all project code will be isntantiated here as sub-modules 

module IOtopmodule(

//switch and buttons to be accessed by modules
input CLK,       
//input [15:0] SW, 
input BTNU,
input BTND,
input BTNL,
input BTNR,
input BTNC,
input CPU_RESETN,

//output connections sent by modules
//output [7:0] JA,
//output [7:0] JB,
output [7:0] JC,
output [7:0] JD,
output [7:0] AN,
output [7:0] CA
    );

/////////////////////////////////////////////////////////////////////////////////
//Seven Segment Driver   

//control signals to be accessed by other modules
wire [31:0] NUMBER;
reg [7:0] DECIMALS  = 8'd0;
reg       UPDATE_EN = 1'b1;
reg       RESET     = 1'b0;

SEGdriver  SEGdriver_a(CLK, NUMBER, DECIMALS, UPDATE_EN, RESET, AN, CA);  

/////////////////////////////////////////////////////////////////////////////////
//LED Driver 

//control signals to be accessed by other modules
wire [4:0] X;
wire [4:0] Y;
wire [23:0] COLOR;
wire [31:0] FRAME_ID;
wire USER_FLAG;

LEDdriver LEDdriver_a(CLK,X,Y,COLOR,USER_FLAG,FRAME_ID,JC,JD);
/////////////////////////////////////////////////////////////////////////////////
//Button Debouncers
wire BTN_L; //debounced output
wire BTN_R; //debounced output
Debouncer Debouncer_a(BTNL,CLK,BTN_L);
Debouncer Debouncer_b(BTNR,CLK,BTN_R);
      
/////////////////////////////////////////////////////////////////////////////////
//Game Function

Snake Snake_a(X,Y,COLOR,USER_FLAG,NUMBER,CLK,FRAME_ID,BTN_L,BTN_R);


endmodule
