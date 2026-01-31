`timescale 1ns / 1ps

module instruction_memory(
    input logic [31:0] addr, 
    output logic [31:0] data
);
    logic [31:0] mem [255:0]; //32x256 = 8MB of instruction memory
    
    initial begin
    $readmemh("instructions.mem",mem); // the instructions are fed in as 'hex' by the readmemh where h is for hex

    //ADDI x1, x0, 10        # x1 = 10
    //ADDI x2, x0, 5         # x2 = 5
    //ADD  x3, x1, x2        # x3 = x1 + x2 = 15
    
    //SW   x3, 4(x0)         # MEM[4]  = 15
    //SW   x1, 32(x0)        # MEM[32] = 10
    
    //LW   x4, 4(x0)         # x4 = MEM[4] = 15
    //ADDI x6, x3, 1         # x6 = 16
    
    //SW   x6, 28(x2)        # MEM[x2 + 28] = MEM[33] = 16  (misaligned)
    //LW   x6, 28(x2)        # x6 = MEM[33]
// HOW TO FIX MISALIGNMENT
    //LW   x4, 4(x0)         # x4 = 15
    //ADD  x5, x4, x2        # x5 = 20
    //BEQ x3, x4, +8

    end
    
    assign data = mem[addr[9:2]];
endmodule