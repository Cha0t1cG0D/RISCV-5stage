`timescale 1ns / 1ps

module data_memory(
    input  logic        clk,
    input  logic        mem_write,
    input  logic        mem_read,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    input  logic [2:0]  load_type,
    input  logic [2:0]  store_type,
    output logic [31:0] read_data
);
    // Memory array (256 words = 1KB)
    logic [31:0] mem [0:255];
    
    // Word-aligned read
    logic [31:0] word_data;
    assign word_data = mem[addr[9:2]];
    
    
    // ==================== LOAD PATH (Optimized) ====================
    // Single-level shift + mux
    logic [31:0] shifted_load;
    assign shifted_load = word_data >> {addr[1:0], 3'b000};
    
    always_comb begin
        if (mem_read) begin
            case(load_type)
                3'b000:  read_data = {{24{shifted_load[7]}},  shifted_load[7:0]};   // LB
                3'b001:  read_data = {{16{shifted_load[15]}}, shifted_load[15:0]};  // LH
                3'b010:  read_data = word_data;                                     // LW
                3'b100:  read_data = {24'b0, shifted_load[7:0]};                    // LBU
                3'b101:  read_data = {16'b0, shifted_load[15:0]};                   // LHU
                default: read_data = 32'b0;
            endcase
        end else begin
            read_data = 32'b0;
        end
    end
    
    
    // ==================== STORE PATH (Unified Flat Approach) ====================
    // Single-level mask and value calculation
    logic [31:0] write_mask;
    logic [31:0] write_val;
    
    always_comb begin
        // Default: no mask (for SW or no write)
        write_mask = 32'hFFFFFFFF;
        write_val  = write_data;
        
        if (mem_write) begin
            case ({store_type, addr[1:0]})  // Flattened 5-bit case (type + offset)
                // ===== STORE BYTE (SB) =====
                5'b000_00: begin  // SB at offset 0
                    write_mask = 32'h000000FF;
                    write_val  = {24'b0, write_data[7:0]};
                end
                5'b000_01: begin  // SB at offset 1
                    write_mask = 32'h0000FF00;
                    write_val  = {16'b0, write_data[7:0], 8'b0};
                end
                5'b000_10: begin  // SB at offset 2
                    write_mask = 32'h00FF0000;
                    write_val  = {8'b0, write_data[7:0], 16'b0};
                end
                5'b000_11: begin  // SB at offset 3
                    write_mask = 32'hFF000000;
                    write_val  = {write_data[7:0], 24'b0};
                end
                
                // ===== STORE HALFWORD (SH) =====
                5'b001_00: begin  // SH at lower half
                    write_mask = 32'h0000FFFF;
                    write_val  = {16'b0, write_data[15:0]};
                end
                5'b001_10: begin  // SH at upper half
                    write_mask = 32'hFFFF0000;
                    write_val  = {write_data[15:0], 16'b0};
                end
         
                5'b001_01, 5'b001_11: begin
                    write_mask = 32'hFFFFFFFF;  // Allow but don't modify (or can fault)
                    write_val  = write_data;
                end
                
                // ===== STORE WORD (SW) =====
                5'b010_00, 5'b010_01, 5'b010_10, 5'b010_11: begin
                    write_mask = 32'hFFFFFFFF;
                    write_val  = write_data;
                end
                
                default: begin
                    write_mask = 32'hFFFFFFFF;
                    write_val  = write_data;
                end
            endcase
        end
    end
    
    // Final write word: Single bitwise operation
    logic [31:0] write_word;
    assign write_word = (word_data & ~write_mask) | (write_val & write_mask);
    
    // Synchronous write
    always_ff @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= write_word;
    end
    
endmodule
