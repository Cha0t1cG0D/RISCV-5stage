`timescale 1ns / 1ps

module tb_riscv_top;

    // 1. Inputs to the processor
    logic clk;
    logic rst;

    // 2. Instantiate the Processor (Unit Under Test)
    // Note: If you added the 'led_debug' port from the previous step, 
    // you must uncomment the line below.
    // wire [3:0] led_debug; 
    
    riscv_top uut (
        .clk(clk),
        .rst(rst)
        // .led_debug(led_debug) // Uncomment if you modified the top module
    );

    // 3. Clock Generation (100 MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. Test Sequence
    initial begin
        // --- Initialize ---
        $display("-------------------------------------------------------------");
        $display("Starting RISC-V 5-Stage Pipeline Simulation");
        $display("-------------------------------------------------------------");
        
        rst = 1;
        #20; // Hold reset for 2 clock cycles
        
        rst = 0;
        $display("Reset released. Processor started.");

        // --- Monitor Signals ---
        // We will run for 20 cycles and print the status of key registers every cycle.
        // We look INSIDE the instance 'uut', into the register file 'regs', at the array 'regs'.
        
        for (int i = 0; i < 20; i++) begin
            @(negedge clk); // Check values at the falling edge (after updates happen)
            
            $display("Time: %0t | PC: %h | WriteBack Data: %h | x1: %d | x2: %d | x3: %d", 
                     $time, 
                     uut.if_pc,          // Current Program Counter
                     uut.wb_write_data,  // Data being written back this cycle
                     uut.regs.regs[1],   // Register x1 (should become 10)
                     uut.regs.regs[2],   // Register x2 (should become 5)
                     uut.regs.regs[3]    // Register x3 (should become 15)
            );
        end

        // --- Check Final Results ---
        // Based on the code in instruction_memory:
        // 1. ADDI x1, x0, 10
        // 2. ADDI x2, x0, 5
        // 3. ADD  x3, x1, x2
        
        $display("-------------------------------------------------------------");
        if (uut.regs.regs[3] === 32'd15) begin
            $display("SUCCESS: x3 contains 15 (10 + 5). Pipeline is working!");
        end else begin
            $display("FAILURE: x3 contains %d (Expected 15).", uut.regs.regs[3]);
        end
        $display("-------------------------------------------------------------");

        $stop; // Stop simulation
    end

endmodule