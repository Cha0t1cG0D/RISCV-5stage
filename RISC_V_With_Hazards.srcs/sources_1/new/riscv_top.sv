`timescale 1ns / 1ps

    module riscv_top(
    input logic clk,
    input logic rst,
    output logic [3:0] led
);
    // --- WIRES & INTERCONNECTS ---
    (* max_fanout = 16 *) logic stall;
    logic flush;
    (* max_fanout = 8 *) logic flush_id_ex,flush_if_id;
    //for hazards
    
    
// IF Signals
    logic [31:0] if_pc, if_pc_next, if_pc_plus4, if_instr;
    
    // IF/ID Pipeline Regs
    logic [31:0] if_id_pc, if_id_instr;
    
     
// ID Signals
    logic [31:0] id_rs1_data, id_rs2_data, id_imm;
    logic [31:0] id_branch_target;
    logic id_reg_write, id_mem_write, id_mem_read, id_mem_to_reg, id_alu_src,id_branch;
    logic [1:0] id_alu_op;
    logic id_jal, id_jalr, id_lui, id_aupic, id_is_rtype;
    logic [2:0] id_load_type;
    logic [2:0] id_store_type;
    logic [31:0] id_rs1_data_fwd, id_rs2_data_fwd;
    
    logic [31:0] rs1_fwd_mem, rs1_fwd_wb, rs2_fwd_mem, rs2_fwd_wb;
    logic rs1_hazard_mem, rs1_hazard_wb, rs2_hazard_mem, rs2_hazard_wb;
    logic rs1_load_hazard, rs2_load_hazard;
    
    // Muxed Control Signals (For Stalling)
    logic c_reg_write, c_mem_write, c_mem_read, c_mem_to_reg, c_alu_src, c_branch;
    logic [1:0] c_alu_op;
    logic c_jal, c_jalr, c_lui, c_auipc, c_is_rtype;
    logic [2:0] c_load_type;
    logic [2:0] c_store_type;


 
// ID/EX Pipeline Regs
    logic [31:0] id_ex_pc, id_ex_rs1, id_ex_rs2, id_ex_imm;
    logic [31:0] id_ex_br_target;
    logic [4:0]  id_ex_rd, id_ex_rs1_addr, id_ex_rs2_addr;
    logic [2:0]  id_ex_func3;
    logic [6:0]  id_ex_func7;
    logic        id_ex_reg_write, id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg, id_ex_alu_src, id_ex_branch;
    logic [1:0]  id_ex_alu_op;
    logic id_ex_jal, id_ex_jalr, id_ex_lui, id_ex_auipc, id_ex_is_rtype;
    logic [2:0] id_ex_load_type;
    logic [2:0] id_ex_store_type;
    logic [31:0] id_ex_pc_plus4, ex_mem_pc_plus4, mem_wb_pc_plus4;

// EX Signals
    logic [31:0] ex_alu_result;
    logic [3:0]  ex_alu_ctrl;
    logic        ex_zero;
    logic [1:0]  forward_a, forward_b;
    logic [31:0] alu_src_a_fwd, alu_src_b_fwd, alu_src_b_final;
    logic [31:0] store_data_fwd;

// EX/MEM Pipeline Regs
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_rs2; 
    logic [4:0]  ex_mem_rd;
    logic        ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg;
    logic [2:0]  ex_mem_load_type;
    logic [2:0]  ex_mem_store_type;
    logic ex_mem_jal, ex_mem_jalr, ex_mem_lui, ex_mem_auipc;
    logic ex_mem_fwd_rs1_match, ex_mem_fwd_rs2_match;
    
// MEM Signals
    logic [31:0] mem_read_data;

// MEM/WB Pipeline Regs
    logic [31:0] mem_wb_read_data, mem_wb_alu_result;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_write, mem_wb_mem_to_reg;
    logic        mem_wb_jal, mem_wb_jalr, mem_wb_lui, mem_wb_auipc;
    logic        mem_wb_fwd_rs1_match, mem_wb_fwd_rs2_match;
    
// WB Signals
    logic [31:0] wb_write_data;


    logic [31:0] jump_target, branch_target;
    logic id_jump, ex_branch_taken;


// ================= STAGE 1: FETCH =================

    // PC Register
    always_ff @(posedge clk) begin
        if (rst) 
            if_pc <= 32'h00000000;
        else if (!stall) 
            if_pc <= if_pc_next;
    end
    
    // PC+4 Calculation
    assign if_pc_plus4 = if_pc + 32'd4;
    
    // Next PC Mux: Branch > Jump > Sequential
    assign if_pc_next = ex_branch_taken ? id_ex_br_target :
                        id_jump         ? jump_target :
                                          if_pc_plus4;
    
    // Instruction Memory (combinational, no clock/reset)
    instruction_memory imem (
        .pc(if_pc),            
        .instruction(if_instr)
    );
    
    // IF/ID Pipeline Register
    always_ff @(posedge clk) begin
        if (rst || flush_if_id) begin 
            if_id_pc    <= 32'h0;
            if_id_instr <= 32'h0;
        end else if (!stall) begin
            if_id_pc    <= if_pc;
            if_id_instr <= if_instr;
        end
    end
    
// ================= STAGE 2: DECODE =================
    
    imm_gen ig ( .instr(if_id_instr), .imm_out(id_imm) );
    
    
    control_unit ctrl (
        .opcode(if_id_instr[6:0]),.func3(if_id_instr[14:12]),
        .reg_write(id_reg_write), .mem_write(id_mem_write), .mem_read(id_mem_read),
        .mem_to_reg(id_mem_to_reg), .alu_src(id_alu_src), .branch(id_branch),
        .alu_op(id_alu_op),.jal(id_jal), .jalr(id_jalr),
        .lui(id_lui),.auipc(id_auipc),.is_rtype(id_is_rtype),  
        .load_type(id_load_type),.store_type(id_store_type)
    );

    // ===== HAZARD UNIT =====
    hazard_unit hu (
        .if_id_rs1(if_id_instr[19:15]),
        .if_id_rs2(if_id_instr[24:20]),
        .id_ex_rd(id_ex_rd),
        .id_ex_mem_read(id_ex_mem_read),
        .stall(stall)
    );
    
    // Stall Logic (Muxing control signals to 0)
    assign c_reg_write  = (stall) ? 1'b0 : id_reg_write;
    assign c_mem_write  = (stall) ? 1'b0 : id_mem_write;
    assign c_mem_read   = (stall) ? 1'b0 : id_mem_read;
    assign c_mem_to_reg = (stall) ? 1'b0 : id_mem_to_reg;
    assign c_alu_src    = (stall) ? 1'b0 : id_alu_src;
    assign c_branch     = (stall) ? 1'b0 : id_branch;
    assign c_alu_op     = (stall) ? 2'b00 : id_alu_op;
    assign c_jal        = (stall) ? 1'b0 : id_jal;
    assign c_jalr       = (stall) ? 1'b0 : id_jalr;
    assign c_load_type  = (stall) ? 3'b010 : id_load_type;  // (default to LW)
    assign c_store_type = (stall) ? 3'b010 : id_store_type;
    assign c_lui        = (stall) ? 1'b0 : id_lui;
    assign c_auipc      = (stall) ? 1'b0 : id_auipc;
    assign c_is_rtype   = (stall) ? 1'b0 : id_is_rtype;
        
    // ===== JUMP UNIT (ID STAGE) =====
    jump_unit ju (
        .if_id_jal(id_jal),
        .if_id_jalr(id_jalr),
        .if_id_pc(if_id_pc),
        .if_id_imm(id_imm),
        .rs1_data_fwd(id_rs1_data_fwd),
        .stall(stall),
        .jump_taken(id_jump),
        .jump_target(jump_target)
    );

    // ID STAGE FORWARDING
    // Detect hazards (separate from data selection)
    assign rs1_hazard_mem = ex_mem_reg_write && (ex_mem_rd != 0) && 
                            (ex_mem_rd == if_id_instr[19:15]);
    assign rs1_hazard_wb  = mem_wb_reg_write && (mem_wb_rd != 0) && 
                            (mem_wb_rd == if_id_instr[19:15]);
    assign rs1_load_hazard = rs1_hazard_mem && ex_mem_mem_to_reg;
    
    assign rs2_hazard_mem = ex_mem_reg_write && (ex_mem_rd != 0) && 
                            (ex_mem_rd == if_id_instr[24:20]);
    assign rs2_hazard_wb  = mem_wb_reg_write && (mem_wb_rd != 0) && 
                            (mem_wb_rd == if_id_instr[24:20]);
    assign rs2_load_hazard = rs2_hazard_mem && ex_mem_mem_to_reg;
    
    // Stage 1: MEM stage forwarding (2-input mux)
    assign rs1_fwd_mem = rs1_hazard_mem ? ex_mem_alu_result : id_rs1_data;
    assign rs2_fwd_mem = rs2_hazard_mem ? ex_mem_alu_result : id_rs2_data;
    
    // Stage 2: WB stage forwarding (2-input mux)
    assign rs1_fwd_wb = rs1_hazard_wb ? wb_write_data : rs1_fwd_mem;
    assign rs2_fwd_wb = rs2_hazard_wb ? wb_write_data : rs2_fwd_mem;
    
    // Stage 3: Load data forwarding (final, 2-input mux)
    assign id_rs1_data_fwd = rs1_load_hazard ? mem_read_data : rs1_fwd_wb;
    assign id_rs2_data_fwd = rs2_load_hazard ? mem_read_data : rs2_fwd_wb;
    
    assign id_branch_target = if_id_pc + id_imm;
        
    register_file regs (
        .clk(clk), .rst(rst), .reg_write(mem_wb_reg_write),
        .rs1_addr(if_id_instr[19:15]), .rs2_addr(if_id_instr[24:20]), .rd_addr(mem_wb_rd),
        .write_data(wb_write_data), .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );
          
    // ID/EX Pipeline Register
    always_ff @(posedge clk) begin
        if (rst || flush_id_ex ) begin // Flush
            {id_ex_reg_write, id_ex_mem_write, id_ex_mem_read, id_ex_mem_to_reg,
            id_ex_branch, id_ex_jal, id_ex_jalr,id_ex_lui,id_ex_auipc,id_ex_is_rtype} <= 0;
             id_ex_rd <= 0; id_ex_rs1_addr <= 0; id_ex_rs2_addr <= 0;
             id_ex_load_type <= 3'b010;
             id_ex_br_target <= 0;
             id_ex_store_type <= 3'b010;
        end else begin //data path transfer
            id_ex_pc <= if_id_pc;
            id_ex_rs1 <= id_rs1_data_fwd;  // USE FORWARDED DATA
            id_ex_rs2 <= id_rs2_data_fwd;  // USE FORWARDED DATA
            id_ex_imm <= id_imm;
            id_ex_lui <= c_lui;
            id_ex_auipc <= c_auipc;
            id_ex_is_rtype <= c_is_rtype;
            id_ex_br_target <= id_branch_target;
            id_ex_rd <= if_id_instr[11:7]; 
            id_ex_rs1_addr <= if_id_instr[19:15]; id_ex_rs2_addr <= if_id_instr[24:20];
            id_ex_func3 <= if_id_instr[14:12]; id_ex_func7 <= if_id_instr[31:25];
            
            id_ex_load_type <= c_load_type;
            id_ex_store_type <= c_store_type;
            id_ex_jal <= c_jal;             
            id_ex_jalr <= c_jalr;         
            id_ex_pc_plus4 <= if_id_pc + 4;  
            //these represent integration of stall unit between instruction decode and execution unit
            id_ex_reg_write <= c_reg_write; id_ex_mem_write <= c_mem_write;
            id_ex_mem_read <= c_mem_read;   id_ex_mem_to_reg <= c_mem_to_reg;
            id_ex_alu_src <= c_alu_src;     id_ex_branch <= c_branch;
            id_ex_alu_op <= c_alu_op;
        end
    end


// ================= STAGE 3: EXECUTE =================


    //exactly after decode
    assign ex_mem_fwd_rs1_match = (ex_mem_rd == id_ex_rs1_addr) && (ex_mem_rd != 0);
    assign ex_mem_fwd_rs2_match = (ex_mem_rd == id_ex_rs2_addr) && (ex_mem_rd != 0);
    assign mem_wb_fwd_rs1_match = (mem_wb_rd == id_ex_rs1_addr) && (mem_wb_rd != 0);
    assign mem_wb_fwd_rs2_match = (mem_wb_rd == id_ex_rs2_addr) && (mem_wb_rd != 0);
    
    forwarding_unit fwd (
        .ex_mem_fwd_rs1_match(ex_mem_fwd_rs1_match),
        .ex_mem_fwd_rs2_match(ex_mem_fwd_rs2_match),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_fwd_rs1_match(mem_wb_fwd_rs1_match),
        .mem_wb_fwd_rs2_match(mem_wb_fwd_rs2_match),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );
       
//Resolving the RAW Hazard (Read After Write) without stalling
    assign alu_src_a_fwd = (forward_a == 2'b10) ? ex_mem_alu_result : //Ex Hazard
                           (forward_a == 2'b01) ? wb_write_data : id_ex_rs1; //Mem Hazard
                           
    assign alu_src_b_fwd = (forward_b == 2'b10) ? ex_mem_alu_result : //Ex Hazard
                           (forward_b == 2'b01) ? wb_write_data : id_ex_rs2; //Mem Hazard
// it is for both source registers
// where rs1 and rs2 are input operands

//rs1 and rs2 are compared for branch instruction
    assign alu_src_b_final =
        (id_ex_branch) ? alu_src_b_fwd :
        (id_ex_alu_src) ? id_ex_imm :
                          alu_src_b_fwd;
    
    assign store_data_fwd =
        (forward_b == 2'b10) ? ex_mem_alu_result :   // EX/MEM forward
        (forward_b == 2'b01) ? wb_write_data    :   // MEM/WB forward
                               id_ex_rs2;           // normal rs2

// ===== LUI/AUIPC DATAPATH =====

//20 bit operations
    logic [31:0] alu_src_a_final, alu_src_b_adjusted;
    
    // For AUIPC: use PC as src_a, for others use forwarded rs1
    assign alu_src_a_final = id_ex_auipc ? id_ex_pc : alu_src_a_fwd;
    
    // For LUI/AUIPC: use immediate directly as src_b
    assign alu_src_b_adjusted = (id_ex_lui || id_ex_auipc) ? id_ex_imm : alu_src_b_final;
   
// ===== ALU Operations =====
    
    alu_control alu_c ( .alu_op(id_ex_alu_op), .func3(id_ex_func3),
    .func7(id_ex_func7), .alu_ctrl(ex_alu_ctrl),.is_rtype(id_ex_is_rtype));
    
    alu alu_main ( .src_a(alu_src_a_final), .src_b(alu_src_b_adjusted),
     .alu_ctrl(ex_alu_ctrl), .alu_result(ex_alu_result), .zero(ex_zero) );
    
            
    // ===== BRANCH UNIT (EX STAGE, COMBINATIONAL) =====
    
    branch_unit bru (
        .id_ex_branch(id_ex_branch),
        .id_ex_func3(id_ex_func3),
        .rs1(alu_src_a_fwd),
        .rs2(alu_src_b_fwd),
        .branch_taken(ex_branch_taken)
    );
    
    // ===== FLUSH UNIT =====
    flush_unit fu (
        .branch_taken(ex_branch_taken),
        .jump_taken(id_jump),
        .flush_if_id(flush_if_id),
        .flush_id_ex(flush_id_ex)
    );
    
    // EX/MEM Pipeline Register
    always_ff @(posedge clk) begin
        if (rst) begin
            {ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_read, ex_mem_mem_to_reg} <= 0;
            ex_mem_rd <= 0;
            ex_mem_jal <= 0;
            ex_mem_jalr <= 0;
            ex_mem_lui <= 0;
            ex_mem_auipc <= 0;
            ex_mem_load_type <= 3'b010;
            ex_mem_store_type <= 3'b010;
        end else begin
            ex_mem_pc_plus4 <= id_ex_pc_plus4;
            ex_mem_jal <= id_ex_jal;
            ex_mem_jalr <= id_ex_jalr;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_rs2 <= store_data_fwd;
            ex_mem_rd <= id_ex_rd;
            ex_mem_load_type <= id_ex_load_type;
            ex_mem_store_type <= id_ex_store_type;
            ex_mem_lui <= id_ex_lui;
            ex_mem_auipc <= id_ex_auipc;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        end
    end

    
    // ================= STAGE 4: MEMORY =================

    data_memory dmem (
        .clk(clk), .mem_write(ex_mem_mem_write), .mem_read(ex_mem_mem_read),
        .addr(ex_mem_alu_result),.load_type(ex_mem_load_type),.store_type(ex_mem_store_type),
         .write_data(ex_mem_rs2), .read_data(mem_read_data)
    );

    // MEM/WB Pipeline Register
    always_ff @(posedge clk) begin
        if (rst) begin
            {mem_wb_reg_write, mem_wb_mem_to_reg} <= 0;
            mem_wb_rd <= 0;
            mem_wb_jal <= 0;
            mem_wb_jalr <= 0;
            mem_wb_lui <= 0;
            mem_wb_auipc <= 0;
        end else begin
            mem_wb_pc_plus4 <= ex_mem_pc_plus4;
            mem_wb_jal <= ex_mem_jal;
            mem_wb_jalr <= ex_mem_jalr;
            mem_wb_read_data <= mem_read_data;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_lui <= ex_mem_lui;
            mem_wb_auipc <= ex_mem_auipc;
            
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            
        end
    end 


    // ================= STAGE 5: WRITEBACK =================
    assign wb_write_data = (mem_wb_jal | mem_wb_jalr) ? mem_wb_pc_plus4 :
                           (mem_wb_mem_to_reg) ? mem_wb_read_data : 
                           mem_wb_alu_result;  // Includes LUI/AUIPC results

    assign led = if_pc[5:2];
endmodule