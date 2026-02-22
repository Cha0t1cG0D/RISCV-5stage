`timescale 1ns / 1ps

module forwarding_unit(
    // Pre-computed match signals (from pipeline registers)
    input logic ex_mem_fwd_rs1_match,
    input logic ex_mem_fwd_rs2_match,
    input logic ex_mem_reg_write,
    input logic mem_wb_fwd_rs1_match,
    input logic mem_wb_fwd_rs2_match,
    input logic mem_wb_reg_write,
    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);
    // Just priority encoding
    always_comb begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // MEM stage forwarding (lower priority)
        if (mem_wb_reg_write && mem_wb_fwd_rs1_match) forward_a = 2'b01;
        if (mem_wb_reg_write && mem_wb_fwd_rs2_match) forward_b = 2'b01;
        
        // EX stage forwarding (higher priority, overrides)
        if (ex_mem_reg_write && ex_mem_fwd_rs1_match) forward_a = 2'b10;
        if (ex_mem_reg_write && ex_mem_fwd_rs2_match) forward_b = 2'b10;
    end
endmodule


// Combinational branch resolution (NO cycle penalty)
// Optimized branch unit with dedicated comparator
module branch_unit (
    input  logic        id_ex_branch,
    input  logic [2:0]  id_ex_func3,
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    output logic        branch_taken
);
    // Comparison results from dedicated comparator
    logic equal, lt_signed, lt_unsigned;
    
    // Instantiate fast dedicated comparator
    branch_comparator bc (
        .rs1(rs1),
        .rs2(rs2),
        .equal(equal),
        .less_than_signed(lt_signed),
        .less_than_unsigned(lt_unsigned)
    );
    
    // Branch condition evaluation using pre-computed comparisons
    logic cond;
    always_comb begin
        case (id_ex_func3)
            3'b000: cond = equal;               // BEQ
            3'b001: cond = !equal;              // BNE
            3'b100: cond = lt_signed;           // BLT
            3'b101: cond = !lt_signed || equal;          // BGE
            3'b110: cond = lt_unsigned;         // BLTU
            3'b111: cond = !lt_unsigned || equal;        // BGEU
            default: cond = 1'b0;
        endcase
    end

    assign branch_taken  = id_ex_branch & cond;
//    assign branch_target = pc + imm;
endmodule

// Dedicated comparator for branch instructions (faster than ALU)
module branch_comparator (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    output logic        equal,
    output logic        less_than_signed,
    output logic        less_than_unsigned
);
    // Parallel comparison operations (all computed simultaneously)
    assign equal = (rs1 == rs2);
    assign less_than_unsigned = (rs1 < rs2);
    assign less_than_signed = ($signed(rs1) < $signed(rs2));
    
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
            4'b0011: alu_result = src_a ^ src_b; //XOR/XORI
            4'b0100: alu_result = src_a << src_b[4:0]; // SLL/SLLI
            4'b0101: alu_result = src_a >> src_b[4:0]; // SRL/SRLI
            4'b0110: alu_result = src_a - src_b; // SUB
            4'b0111: alu_result = $signed(src_a) >>> src_b[4:0]; //SRA/SRAI
            4'b1000: alu_result = ($signed(src_a) < $signed(src_b)) ? 32'd1 : 32'd0; // SLT/SLTI
            4'b1001: alu_result = (src_a < src_b) ? 32'd1 : 32'd0; // SLTU/ SLTIU
            4'b1010: alu_result = src_b; //u-type, lui
            default: alu_result = 0;
        endcase
    end
    assign zero = (alu_result == 0); // it is the zero flag
endmodule

// 3. ALU CONTROL
module alu_control(
    input logic [1:0] alu_op, input logic [2:0] func3, input logic [6:0] func7,
    input logic is_rtype,
    output logic [3:0] alu_ctrl
);
//since multiple instructions like ADD,SUB,MUL use the same opcode, funct3 and funct7 is used to distinguish differences between them
// alu_op = 00 for load
// alu_op = 01 for branch, beq
//alu_op = 10 for ADD,SUB,OR
    always_comb begin 
        if(alu_op==2'b00) alu_ctrl=4'b0010; // In load Instruction, the ALU is used to calculate the address ( RegValue + ImmOffset)
        else if(alu_op==2'b01) alu_ctrl=4'b0110; // SUB
        else if(alu_op == 2'b11) alu_ctrl = 4'b1010; // U-type      
        else begin
            case(func3)
            3'b000: alu_ctrl=(is_rtype && func7 == 7'b0100000)? 4'b0110:4'b0010;//Sub Add have same func3 so func7[5] differentiate it
            3'b001: alu_ctrl = 4'b0100; // sll/slli
            3'b010: alu_ctrl = 4'b1000; //slt/slti
            3'b011: alu_ctrl = 4'b1001; //sltu/sltiu
            3'b100: alu_ctrl = 4'b0011; // xor
            3'b101: alu_ctrl = (func7 == 7'b0100000) ? 4'b0111 : 4'b0101; // srl/srai or srl/srli
            3'b110: alu_ctrl=4'b0001; //bitwise OR
            3'b111: alu_ctrl=4'b0000; //bitwise AND
            default: alu_ctrl = 4'b0000;
        endcase
        end
    end
endmodule