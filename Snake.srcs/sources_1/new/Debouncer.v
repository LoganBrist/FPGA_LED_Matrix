`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2018 04:07:45 PM
// Design Name: 
// Module Name: Button Debouncer
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


module Debouncer(
  input  wire BTN_IN,
  input  wire CLK,            
  output reg BTN_OUT = 1'b1

    );
  
  integer CLK_COUNT = 100000;         //Required count of constancy required for a button's value to be passed through the debouncer. 
  reg [63:0] BTN_STATE_COUNTER = 0; //Counts when the input button value is the same as the previous input button value. 
  reg LAST_BTN_IN_STATE  = 1'b0;    //Records the last button input state
  
  always @(posedge CLK) begin 
    LAST_BTN_IN_STATE <= BTN_IN;
    
    if (BTN_IN == LAST_BTN_IN_STATE) begin BTN_STATE_COUNTER <= BTN_STATE_COUNTER + 1; end
    else                             begin BTN_STATE_COUNTER <= 0; end
  
    //if constancy condition met, output input button. Else, don't change the output.
    if (BTN_STATE_COUNTER > CLK_COUNT) begin BTN_OUT <= BTN_IN;  end
    else                               begin BTN_OUT <= BTN_OUT; end 
  end
endmodule
