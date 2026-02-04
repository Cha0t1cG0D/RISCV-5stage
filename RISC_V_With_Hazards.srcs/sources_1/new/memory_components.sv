`timescale 1ns / 1ps

module data_memory(
    input logic clk, mem_write, mem_read, 
    input logic [31:0] addr, write_data, 
    input logic [2:0] load_type,
    output logic [31:0] read_data
);
    logic [31:0] mem [255:0];
    logic [31:0] word_data;
    logic [15:0] halfword;
    logic [7:0] byte_data;
    // 256 memories of 32bits
    assign word_data = mem[addr[9:2]];
    
    always_comb begin
        read_data = 32'b0;
        
        if (mem_read) begin
            case(load_type)
                3'b000: begin //LOAD BYTE
                    case(addr[1:0])
                        2'b00: byte_data = word_data[7:0];
                        2'b01: byte_data = word_data[15:8];
                        2'b10: byte_data = word_data[23:16];
                        2'b11: byte_data = word_data[31:24];
                   endcase
                   read_data = {{24{byte_data[7]}}, byte_data};
               end
               
               3'b001: begin
                    case(addr[1])
                        1'b0: halfword = word_data[15:0];
                        1'b1: halfword = word_data[31:16];
                    endcase
                    read_data = {{16{halfword[15]}}, halfword};
               end
                  
                 3'b010: read_data = word_data;
                 
                 3'b100: begin
                    case(addr[1:0])
                        2'b00: byte_data = word_data[7:0];
                        2'b01: byte_data = word_data[15:8];
                        2'b10: byte_data = word_data[23:16];
                        2'b11: byte_data = word_data[31:24];
                    endcase
                    read_data = {24'b0, byte_data};
                end
                
                3'b101: begin
                    case(addr[1])
                        1'b0: halfword = word_data[15:0];
                        1'b1: halfword = word_data[31:16];
                    endcase
                    read_data = {16'b0,halfword};
                end
                
                default: read_data = 32'b0;
         endcase
     end
 end
                
    // the memory is word addressed ie 0th and 1st bit is neglected
    // to take a complete 32bit word
    // we use 8bits to address the 256 memory locations
    always_ff @(posedge clk) begin
        if (mem_write) mem[addr[9:2]] <= write_data; //for writing in memory
  
//        if (mem_read)  read_data <= mem[addr[9:2]];  
//        else read_data <= 32'b0;
    end
endmodule