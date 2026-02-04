`timescale 1ns / 1ps

module instruction_memory(
    input logic [31:0] addr, 
    output logic [31:0] data
);
    logic [31:0] mem [255:0]; //32x256 = 8MB of instruction memory
    
    initial begin
    $readmemh("instructions.mem",mem); // the instructions are fed in as 'hex' by the readmemh where h is for hex

    end
    
    assign data = mem[addr[9:2]];
endmodule