`timescale 1ns / 1ps

module riscv_top(
    input logic clk,
    input logic rst,
    output logic [3:0] led
);
    // --- WIRES & INTERCONNECTS ---
    logic stall, flush; 
    //for hazards
    
    
// IF Signals
    logic [31:0] if_pc, if_pc_next, if_pc_plus4, if_instr;
    
    // IF/ID Pipeline Regs
    logic [31:0] if_id_pc, if_id_instr;
    
     
// ID Signals
    logic [31:0] id_rs1_data, id_rs2_data, id_imm;
    logic id_reg_write, id_mem_write, id_mem_read, id_mem_to_reg, id_alu_src, id_branch;
    logic [1:0] id_alu_op;
    
    // Muxed Control Signals (For Stalling)
    logic c_reg_write, c_mem_write, c_mem_read, c_mem_to_reg, c_alu_src, c_branch;
    logic [1:0] c_alu_op;

 
// ID/EX Pipeline Regs
    logic [31:0] id_ex_pc, id_ex_rs1, id_ex_rs2, id_ex_imm;
    logic [4:0]  id_ex_rd, id_ex_rs1_addr, id_ex_rs2_addr;
    logic [2:0]  id_ex_func3;
    logic [6:0]  id_ex_func7;
    logic        id_ex_reg_write, id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg, id_ex_alu_src, id_ex_branch;
    logic [1:0]  id_ex_alu_op;

// EX Signals
    logic [31:0] ex_alu_result, ex_pc_branch;
    logic [3:0]  ex_alu_ctrl;
    logic        ex_zero;
    logic [1:0]  forward_a, forward_b;
    logic [31:0] alu_src_a_fwd, alu_src_b_fwd, alu_src_b_final;
    logic [31:0] store_data_fwd;

// EX/MEM Pipeline Regs
    logic [31:0] ex_mem_alu_result, ex_mem_rs2;
    logic [4:0]  ex_mem_rd;
    logic        ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg;
    logic ex_pcsrc;
// MEM Signals
    logic [31:0] mem_read_data;

// MEM/WB Pipeline Regs
    logic [31:0] mem_wb_read_data, mem_wb_alu_result;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_write, mem_wb_mem_to_reg;
    
// WB Signals
    logic [31:0] wb_write_data;


    // ================= STAGE 1: FETCH =================
    assign if_pc_plus4 = if_pc + 4;
//runs the instructions in serial order, 

    always_ff @(posedge clk) begin
        if (rst) if_pc <= 32'h0000000;
        else if (flush) if_pc <= ex_pc_branch;
        else if (!stall) if_pc <= if_pc_plus4; // this halts the instruct fetch during stall operation

    end

    instruction_memory imem ( .addr(if_pc), .data(if_instr) ); //fetches the instruction from the instruction memory

    // IF/ID Pipeline Register
    always_ff @(posedge clk) begin
        if (rst || flush) begin 
            if_id_pc <= 0; if_id_instr <= 0;
        // when branch occurs, the instruction is flushed
        end else if (!stall) begin
            if_id_pc <= if_pc; if_id_instr <= if_instr;
        //for stalling, we don't move the IF instruction through to instruction decode,
        // we rerun it for few cycles
        end
    end


    // ================= STAGE 2: DECODE =================
    hazard_detection_unit hdu (
        .if_id_rs1(if_id_instr[19:15]), .if_id_rs2(if_id_instr[24:20]),.id_branch(id_branch), 
        .id_ex_rd(id_ex_rd), .id_ex_mem_read(id_ex_mem_read), .stall(stall)
    );
//gives the stall signal

    control_unit ctrl (
        .opcode(if_id_instr[6:0]),
        .reg_write(id_reg_write), .mem_write(id_mem_write), .mem_read(id_mem_read),
        .mem_to_reg(id_mem_to_reg), .alu_src(id_alu_src), .branch(id_branch), .alu_op(id_alu_op)
    );

    // Stall Logic (Muxing control signals to 0)
    assign c_reg_write = (stall) ? 0 : id_reg_write;
    assign c_mem_write = (stall) ? 0 : id_mem_write;
    assign c_mem_read  = (stall) ? 0 : id_mem_read;
    assign c_mem_to_reg= (stall) ? 0 : id_mem_to_reg;
    assign c_alu_src   = (stall) ? 0 : id_alu_src;
    assign c_branch    = (stall) ? 0 : id_branch;
    assign c_alu_op    = (stall) ? 0 : id_alu_op;

    register_file regs (
        .clk(clk), .rst(rst), .reg_write(mem_wb_reg_write),
        .rs1_addr(if_id_instr[19:15]), .rs2_addr(if_id_instr[24:20]), .rd_addr(mem_wb_rd),
        .write_data(wb_write_data), .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );

    imm_gen ig ( .instr(if_id_instr), .imm_out(id_imm) );

    // ID/EX Pipeline Register
    always_ff @(posedge clk) begin
        if (rst || flush) begin // Flush
            {id_ex_reg_write, id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg, id_ex_branch} <= 5'b0;
             id_ex_rd <= 0; id_ex_rs1_addr <= 0; id_ex_rs2_addr <= 0;
        end else begin //data path transfer
            id_ex_pc <= if_id_pc; 
            id_ex_rs1 <= id_rs1_data; id_ex_rs2 <= id_rs2_data; id_ex_imm <= id_imm;
            id_ex_rd <= if_id_instr[11:7]; 
            id_ex_rs1_addr <= if_id_instr[19:15]; id_ex_rs2_addr <= if_id_instr[24:20];
            id_ex_func3 <= if_id_instr[14:12]; id_ex_func7 <= if_id_instr[31:25];
            
            //these represent integration of stall unit between instruction decode and execution unit
            id_ex_reg_write <= c_reg_write; id_ex_mem_write <= c_mem_write;
            id_ex_mem_read <= c_mem_read;   id_ex_mem_to_reg <= c_mem_to_reg;
            id_ex_alu_src <= c_alu_src;     id_ex_branch <= c_branch;
            id_ex_alu_op <= c_alu_op;
        end
    end


    // ================= STAGE 3: EXECUTE =================
    forwarding_unit fwd (
        .id_ex_rs1(id_ex_rs1_addr), .id_ex_rs2(id_ex_rs2_addr),
        .ex_mem_rd(ex_mem_rd), .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_rd(mem_wb_rd), .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b)
    );

//Resolving the RAW Hazard (Read After Write) without stalling
    assign alu_src_a_fwd = (forward_a == 2'b10) ? ex_mem_alu_result : //Ex Hazard
                           (forward_a == 2'b01) ? wb_write_data : id_ex_rs1; //Mem Hazard
                           
    assign alu_src_b_fwd = (forward_b == 2'b10) ? ex_mem_alu_result : //Ex Hazard
                           (forward_b == 2'b01) ? wb_write_data : id_ex_rs2; //Mem Hazard
// it is for both source registers
// where rs1 and rs2 are input operands

//rs1 and rs2 are compared for branch instruction

    assign alu_src_b_final = (id_ex_alu_src) ? id_ex_imm : alu_src_b_fwd;
    assign store_data_fwd =
        (forward_b == 2'b10) ? ex_mem_alu_result :   // EX/MEM forward
        (forward_b == 2'b01) ? wb_write_data    :   // MEM/WB forward
                               id_ex_rs2;           // normal rs2
    
    alu_control alu_c ( .alu_op(id_ex_alu_op), .func3(id_ex_func3), .func7(id_ex_func7), .alu_ctrl(ex_alu_ctrl) );
    alu alu_main ( .src_a(alu_src_a_fwd), .src_b(alu_src_b_final), .alu_ctrl(ex_alu_ctrl), .alu_result(ex_alu_result), .zero(ex_zero) );

    // EX/MEM Pipeline Register
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            {ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg } <= 0;
            ex_mem_rd <= 0;
        end else begin
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_rs2 <= store_data_fwd; 
            ex_mem_rd <= id_ex_rd;
            
            ex_mem_reg_write <= id_ex_reg_write; ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_read <= id_ex_mem_read;   ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        end
    end

    // Branch decision in EX stage
    assign ex_pcsrc     = id_ex_branch & ex_zero;
    assign flush        = ex_pcsrc;
    assign ex_pc_branch = id_ex_pc + id_ex_imm;
    
    
    // ================= STAGE 4: MEMORY =================

    data_memory dmem (
        .clk(clk), .mem_write(ex_mem_mem_write), .mem_read(ex_mem_mem_read),
        .addr(ex_mem_alu_result), .write_data(ex_mem_rs2), .read_data(mem_read_data)
    );

    // MEM/WB Pipeline Register
    always_ff @(posedge clk) begin
        if (rst) begin
            {mem_wb_reg_write, mem_wb_mem_to_reg} <= 0;
            mem_wb_rd <= 0;
        end else begin
            mem_wb_read_data <= mem_read_data;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end


    // ================= STAGE 5: WRITEBACK =================
    assign wb_write_data = (mem_wb_mem_to_reg) ? mem_wb_read_data : mem_wb_alu_result;
    assign led = if_pc[5:2];
endmodule