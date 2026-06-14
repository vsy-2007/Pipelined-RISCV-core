# RISC-V 5-Stage Pipelined Processor (RV32I)

A fully functional, synthesizable 5-Stage Pipelined RISC-V Processor implementing the complete RV32I Base Integer Instruction Set in SystemVerilog/Verilog. 

This core features a classic hardware pipeline architecture equipped with comprehensive data forwarding logic, load-use hazard stall detection, and automatic pipeline flushing for control hazards (branches/jumps).

---

## Verification Status: 100% Passed

The core has successfully passed 100% of the verification test variants within the RV32I base instruction test suite. 
* All computational (R-type, I-type), memory (Loads/Stores), control transfer (Branches, JAL, JALR), and upper-immediate (lui, auipc) instructions pass cycle-accurate architectural checks.
* Environment execution controls (ecall) are fully mapped to handle clean simulation halting (sim_halt).

---

## Pipeline Architecture

The core implements a classic 5-stage classic pipeline execution structure:

1. **Instruction Fetch (IF):** Tracks and increments the Program Counter (Pc), handling instruction memory retrieval from an asymmetric/synchronized 16KB space.
2. **Instruction Decode (ID):** Extracts standard RISC-V fields (opcode, rd, rs1, rs2, func3, func7), performs sign-extended immediate generation (imm_gen), and interfaces with a 32-register Register File featuring built-in internal bypassing.
3. **Execute (EX):** Contains a robust Arithmetic Logic Unit (ALU) processing mathematical, shifting, and comparison metrics alongside immediate resolution multiplexers. Branches and Jumps are calculated combinational here for rapid execution.
4. **Memory Access (MEM):** Connects to a synchronous 16KB Data Memory (Data_mem) configured to process byte, half-word, and word operations cleanly (lb, lh, lw, lbu, lhu, sb, sh, sw).
5. **Write Back (WB):** Routes processed ALU calculations, upper immediates, or memory elements to the destination register.
