# Advanced-RISCV-SOC

only riscv core with all 37 instructions verified and hazards not the entire SOC

added Hazard Management through stall, forwarding 

Jump resolved in ID stage
Branch resovled in EX stage

It has positive slack at 100MHz, i couldn't completely optimize it for 125MHz,
It uses around 1500+ LUTs on PYNQ Z2 Board

