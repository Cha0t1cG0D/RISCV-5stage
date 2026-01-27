`timescale 1ns / 1ps

module data_memory(
    input logic clk, mem_write, mem_read, 
    input logic [31:0] addr, write_data, 
    output logic [31:0] read_data
);
    logic [31:0] mem [255:0];
    
    assign read_data = (mem_read) ? mem[addr[9:2]] : 0;
    
    always_ff @(posedge clk) begin
        if (mem_write) mem[addr[9:2]] <= write_data;
    end
endmodule