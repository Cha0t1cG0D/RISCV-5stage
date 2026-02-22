`timescale 1ns / 1ps


module instruction_memory(
    input  logic [31:0] pc,          // This is pc_next from top
    output logic [31:0] instruction
);
    logic [31:0] mem [255:0]; //32x256 = 8MB of instruction memory
//    logic [31:0] instruction_reg;
    
    
    initial begin
    $readmemh("instructions.mem",mem); // the instructions are fed in as 'hex' by the readmemh where h is for hex
    end

    assign instruction = mem[pc[9:2]]; 
endmodule
