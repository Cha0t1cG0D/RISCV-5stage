# ========================================================================
# RISC-V Pipeline Coverage Simulation Script
# ========================================================================

# Close any existing simulation
close_sim -quiet

# Create waveform configuration
create_wave_config -name "coverage_waves"

# Launch simulation with coverage
launch_simulation -mode behavioral \
    -type functional \
    -simset sim_1 \
    -top tb_riscv_coverage

# Add all signals to waveform
add_wave {{/tb_riscv_coverage}}

# Add specific critical signals for monitoring
add_wave -group "PC & Control" {
    /tb_riscv_coverage/uut/if_pc
    /tb_riscv_coverage/uut/if_id_instr
    /tb_riscv_coverage/uut/stall
    /tb_riscv_coverage/uut/flush_if_id
    /tb_riscv_coverage/uut/flush_id_ex
}

add_wave -group "Forwarding" {
    /tb_riscv_coverage/uut/forward_a
    /tb_riscv_coverage/uut/forward_b
    /tb_riscv_coverage/sampled_forward_a
    /tb_riscv_coverage/sampled_forward_b
}

add_wave -group "Hazards" {
    /tb_riscv_coverage/uut/stall
    /tb_riscv_coverage/uut/id_ex_mem_read
    /tb_riscv_coverage/sampled_stall
    /tb_riscv_coverage/sampled_fwd_priority_conflict
}

add_wave -group "Branches" {
    /tb_riscv_coverage/uut/ex_branch_taken
    /tb_riscv_coverage/uut/id_jump
    /tb_riscv_coverage/sampled_branch_taken
}

add_wave -group "Memory" {
    /tb_riscv_coverage/uut/ex_mem_mem_write
    /tb_riscv_coverage/uut/ex_mem_mem_read
    /tb_riscv_coverage/sampled_load_type
    /tb_riscv_coverage/sampled_store_type
    /tb_riscv_coverage/sampled_addr_align
}

add_wave -group "Register File (x1-x10)" {
    /tb_riscv_coverage/uut/regs/regs[1]
    /tb_riscv_coverage/uut/regs/regs[2]
    /tb_riscv_coverage/uut/regs/regs[3]
    /tb_riscv_coverage/uut/regs/regs[4]
    /tb_riscv_coverage/uut/regs/regs[5]
    /tb_riscv_coverage/uut/regs/regs[6]
    /tb_riscv_coverage/uut/regs/regs[7]
    /tb_riscv_coverage/uut/regs/regs[8]
    /tb_riscv_coverage/uut/regs/regs[9]
    /tb_riscv_coverage/uut/regs/regs[10]
}

add_wave -group "Coverage Sampling" {
    /tb_riscv_coverage/sampled_opcode
    /tb_riscv_coverage/sampled_func3
    /tb_riscv_coverage/sampled_func7
}

# Configure waveform appearance
set_property display_name "Program Counter" [get_waves /tb_riscv_coverage/uut/if_pc]
set_property radix hex [get_waves /tb_riscv_coverage/uut/if_pc]
set_property radix hex [get_waves /tb_riscv_coverage/uut/if_id_instr]

# Run simulation
run 3000ns

# Print summary at end
puts "\n========================================================================"
puts "                    SIMULATION COMPLETE"
puts "========================================================================"
puts "Total simulation time: [current_time]"
puts "To view waveforms: View > Zoom > Zoom Fit"
puts "========================================================================"

# Keep waveform window open
# Don't close automatically
