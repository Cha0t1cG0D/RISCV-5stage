`timescale 1ns / 1ps

// 1. FORWARDING UNIT
module forwarding_unit(
    input logic [4:0] id_ex_rs1,
    input logic [4:0] id_ex_rs2,
    input logic [4:0] ex_mem_rd,
    input logic ex_mem_reg_write,
    input logic [4:0] mem_wb_rd,
    input logic mem_wb_reg_write,
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
); // for solving read after write hazard without stalling
// we aim to improve or maintain CPI
// The instruction is between EX/MEM and another is MEM/WB

// Inputs : Two from ID/EX, the rd from EX/MM, the rd from MM/WB


//Outputs: forward_a and forward_b, controls the ALU input
// forces the data from the MEM/WB into the alu rather than the normal flow, basically a mux switch 
 
    always_comb begin
        forward_a = 0; forward_b = 0; // normally we won't be forwarding any data, we will do so after any condition gets fulfilled

        // EX Hazard
        // ahead instruction is writing to the register which is needed right now
        
        //ex_mem_reg_write and ex_mem_rd comes from the forward module
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) forward_a = 2'b10; //if memory rd matches r1
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) forward_b = 2'b10; //if memory rd matches rs2
        
        // MEM Hazard
        // if the instruction which is two cycles ahead is writing to a register, which is currently needed
        
        // we have a double hazard check, so the two cycle ahead and one cycle ahead are not writing to the same register
        if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1) && 
           !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))) forward_a = 2'b01;
        
        if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2) && 
           !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))) forward_b = 2'b01;
    end
endmodule

// 2. ALU
module alu(
    input logic [31:0] src_a, src_b, 
    input logic [3:0] alu_ctrl, 
    output logic [31:0] alu_result, output logic zero
);
    always_comb begin
        case(alu_ctrl) //only 5 instructions for now
            4'b0000: alu_result = src_a & src_b; // AND
            4'b0001: alu_result = src_a | src_b; // OR
            4'b0010: alu_result = src_a + src_b; // ADD
            4'b0110: alu_result = src_a - src_b; // SUB
            default: alu_result = 0;
        endcase
    end
    assign zero = (alu_result == 0); // it is the zero flag
endmodule

// 3. ALU CONTROL
module alu_control(
    input logic [1:0] alu_op, input logic [2:0] func3, input logic [6:0] func7,
    output logic [3:0] alu_ctrl
);
//since multiple instructions like ADD,SUB,MUL use the same opcode, funct3 and funct7 is used to distinguish differences between them
// alu_op = 00 for load
// alu_op = 01 for branch, beq
//alu_op = 10 for ADD,SUB,OR
    always_comb begin 
        if(alu_op==2'b00) alu_ctrl=4'b0010; // In load Instruction, the ALU is used to calculate the address ( RegValue + ImmOffset)
        else if(alu_op==2'b01) alu_ctrl=4'b0110; // SUB
        else begin
            case(func3)
            3'b000: alu_ctrl=(func7[5])? 4'b0110:4'b0010;//Sub Add have same func3 so func7[5] differentiate it
            3'b111: alu_ctrl=4'b0000; //bitwise AND
            3'b110: alu_ctrl=4'b0001; //bitwise OR
            default: alu_ctrl=4'b0000;
        endcase
        end
    end
endmodule