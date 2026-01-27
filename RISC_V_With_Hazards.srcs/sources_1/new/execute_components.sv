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
);
    always_comb begin
        forward_a = 0; forward_b = 0;

        // EX Hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) forward_a = 2'b10;
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) forward_b = 2'b10;

        // MEM Hazard
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
        case(alu_ctrl)
            4'b0000: alu_result = src_a & src_b; // AND
            4'b0001: alu_result = src_a | src_b; // OR
            4'b0010: alu_result = src_a + src_b; // ADD
            4'b0110: alu_result = src_a - src_b; // SUB
            default: alu_result = 0;
        endcase
    end
    assign zero = (alu_result == 0);
endmodule

// 3. ALU CONTROL
module alu_control(
    input logic [1:0] alu_op, input logic [2:0] func3, input logic [6:0] func7,
    output logic [3:0] alu_ctrl
);
    always_comb begin
        if(alu_op==2'b00) alu_ctrl=4'b0010; // ADD
        else if(alu_op==2'b01) alu_ctrl=4'b0110; // SUB
        else begin
            if(func3==3'b000) alu_ctrl=(func7[5])? 4'b0110:4'b0010;//Add Sub have same func3 so func7[5] differentiate it
            else if(func3==3'b111) alu_ctrl=4'b0000;
            else if(func3==3'b110) alu_ctrl=4'b0001;
            else alu_ctrl=4'b0000;
        end
    end
endmodule