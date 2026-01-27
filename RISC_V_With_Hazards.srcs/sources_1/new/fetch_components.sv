`timescale 1ns / 1ps

module instruction_memory(
    input logic [31:0] addr, 
    output logic [31:0] data
);
    logic [31:0] mem [255:0]; //32x256 = 8MB of instruction memory
    
    initial begin
    $readmemh("instructions.mem",mem); // the instructions are fed in as 'hex' by the readmemh where h is for hex
//        // --- TEST PROGRAM ---
//        // 1. ADDI x1, x0, 10  (x1 = 10)
//        mem[0] = 32'h00A00093; 
//        // 2. ADDI x2, x0, 5   (x2 = 5)
//        mem[1] = 32'h00500113; 
//        // 3. ADD  x3, x1, x2  (x3 = 15) -> Hazard Check!
//        mem[2] = 32'h002081B3; 
//        // 4. SW   x3, 4(x0)   (Store 15 to memory addr 4)
//        mem[3] = 32'h00302223;
//        // 5. LW   x4, 4(x0)   (Load 15 back to x4)
//        mem[4] = 32'h00402203;
//        // 6. LW  28th mem ->x6
//        mem[5] = 32'h01C02303;
//        // Fill the rest with NOPs
//        for (int i=6; i<256; i++) mem[i]=0;
    end
    
    assign data = mem[addr[9:2]];
endmodule