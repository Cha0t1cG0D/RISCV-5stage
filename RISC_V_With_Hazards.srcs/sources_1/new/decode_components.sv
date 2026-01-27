`timescale 1ns / 1ps

// 1. HAZARD DETECTION UNIT
module hazard_detection_unit(
    input logic [4:0] if_id_rs1,
    input logic [4:0] if_id_rs2,
    input logic [4:0] id_ex_rd,
    input logic id_ex_mem_read,
    output logic stall
);
    always_comb begin
        if (id_ex_mem_read && ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)))//load then add/sub....
            stall = 1'b1;
        else
            stall = 1'b0;
    end
endmodule

// 2. CONTROL UNIT
module control_unit(
    input logic [6:0] opcode,
    output logic reg_write, mem_write, mem_read, mem_to_reg, alu_src, branch,
    output logic [1:0] alu_op
);
    always_comb begin
        {reg_write, mem_write, mem_read, mem_to_reg, alu_src, branch, alu_op} = 0;
        case(opcode)
            7'b0110011: begin reg_write=1; alu_op=2'b10; end // R-type
            7'b0010011: begin reg_write=1; alu_src=1; alu_op=2'b10; end // I-type
            7'b0000011: begin reg_write=1; mem_read=1; mem_to_reg=1; alu_src=1; alu_op=2'b00; end // LW mem_to_reg needed because you need to write back from memory
            7'b0100011: begin mem_write=1; alu_src=1; alu_op=2'b00; end // SW-ALU used to calculate address to store for alu_src
            7'b1100011: begin branch=1; alu_op=2'b01; end // BEQ
        endcase
    end
endmodule

// 3. REGISTER FILE
module register_file(
    input logic clk, rst, reg_write,
    input logic [4:0] rs1_addr, rs2_addr, rd_addr,
    input logic [31:0] write_data,
    output logic [31:0] rs1_data, rs2_data//these are address where to write in register array,like reg[0]....
);
    logic [31:0] regs [31:0];
    
    assign rs1_data = (rs1_addr==0) ? 0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr==0) ? 0 : regs[rs2_addr];
    
    always_ff @(posedge clk) begin
        if (rst) for(int i=0; i<32; i++) regs[i] <= 0;
        else if (reg_write && rd_addr!=0) regs[rd_addr] <= write_data;
    end
endmodule

// 4. IMMEDIATE GENERATOR
module imm_gen(input logic [31:0] instr, output logic [31:0] imm_out);
    always_comb begin
        case(instr[6:0])
            7'b0010011, 7'b0000011: imm_out={{20{instr[31]}}, instr[31:20]}; 
            7'b0100011: imm_out={{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: imm_out={{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            default: imm_out=0;
        endcase
    end
endmodule