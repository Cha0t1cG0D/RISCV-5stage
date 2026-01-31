`timescale 1ns / 1ps

module data_memory(
    input logic clk, mem_write, mem_read, 
    input logic [31:0] addr, write_data, 
    output logic [31:0] read_data
);
    logic [31:0] mem [255:0];
    // 256 memories of 32bits
    assign read_data = (mem_read) ? mem[addr[9:2]] : 32'b0;
    
    // the memory is word addressed ie 0th and 1st bit is neglected
    // to take a complete 32bit word
    // we use 8bits to address the 256 memory locations
    always_ff @(posedge clk) begin
        if (mem_write) mem[addr[9:2]] <= write_data; //for writing in memory
  
//        if (mem_read)  read_data <= mem[addr[9:2]];  
//        else read_data <= 32'b0;
    end
endmodule