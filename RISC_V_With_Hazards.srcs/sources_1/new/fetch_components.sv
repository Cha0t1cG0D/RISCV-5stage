`timescale 1ns / 1ps

module instruction_memory(
    input logic clk,rst,stall,
    input logic [31:0] pc_next,
    output logic [31:0] pc,
    output logic [31:0] instruction
);
    (*ram_style = "block" *)
    logic [31:0] mem [255:0]; //32x256 = 8MB of instruction memory
    
    always_ff @(posedge clk) begin
        if (rst) pc <= 32'h0000000;
        else if (!stall) pc <= pc_next; // this halts the instruct fetch during stall operation
    end

    initial begin
    $readmemh("instructions.mem",mem); // the instructions are fed in as 'hex' by the readmemh where h is for hex

    end

    always_ff @(posedge clk) begin
        if (rst) instruction <= 32'h00000013;
        else if (!stall)
            instruction <= mem[pc_next[9:2]];
        // else maintain current instruction during stall
    end
endmodule