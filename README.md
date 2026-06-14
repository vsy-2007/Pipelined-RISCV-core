# RISC-V 5-Stage Pipelined Processor (RV32I)

A fully functional 5-Stage Pipelined RISC-V Processor implementing the complete RV32I Base Integer Instruction Set in SystemVerilog/Verilog. 

This core features a  hardware pipeline architecture equipped with comprehensive data forwarding logic, load-use hazard stall detection, and automatic pipeline flushing for control hazards (branches/jumps) with a no branch taken prediction.

---

## Verified with the RISCV tests

The core has successfully passed 100% of the verification test variants within the RV32I base instruction test suite (https://github.com/riscv-software-src/riscv-tests/tree/master). 
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

### Advanced Hardware Features

* **Complete Data Forwarding:** Contains fully interlocked bypass channels from both EX/MEM and MEM/WB boundary stages directly back into the ALU execution stage inputs. This prevents pipeline bubbles for consecutive data dependencies.
* **Store-Word (SW) Bypass:** Implements custom data routing logic (forwarded_rs2_sw) targeting sequential Store-after-Load or Store-after-ALU dependency chains.
* **Load-Use Interlocks:** Automatically senses raw load hazards (when a load instruction is followed immediately by an instruction using its destination register), asserting stall signals to freeze the Fetch/Decode stages and inject a bubble into the execution stage.
* **Control Hazard Resolution:** Implements proactive pipeline flushing. When a conditional branch or unconditional jump resolves as taken in the EX stage, the preceding instructions in the pipeline (IF/ID` and ID/EX latches) are immediately flushed ('0) to prevent rogue execution paths.
* **Internal Register Bypassing:** The Register_file implements continuous assignment routing logic. If the pipeline attempts to read a register on the exact same cycle it is being written back to by a previous instruction, it forwards the incoming writeback data instantly.

---

## File Structure and Core Modules

The implementation is modular and structured as follows:

| Module Name | Type | Description |
| :--- | :--- | :--- |
| Pc | Sequential | Handles Program Counter tracking, stalling, and jump targets. |
| Register_file | Hybrid | 32-word RISC-V register space with synchronous writes and transparent asynchronous read forwarding. |
| Alu_MUX | Combinational | Switches ALU input operands between standard register channels and immediate values. |
| Alu | Combinational | 4-bit operational unit executing all baseline logic, arithmetic, and conditional comparisons. |
| Id | Combinational | Full instruction decoder and immediate sign-extension matrix. |
| Inst_mem | Combinational | 16KB byte-addressable instruction memory (loads program.hex). |
| Data_mem | Sequential | 16KB byte-addressable synchronous data memory with sign/zero-extension capabilities. |
| wb | Combinational | Manages writeback data prioritization across multiple execution formats. |
| topmodule | System/Core | Integrates all sub-modules and handles pipeline latches, forwarding networks, and stall logic. |

---

## Simulation and Automated Verification

The project includes an automated test framework designed to validate every individual RV32I instruction inside its own targeted simulation environment.

### 1. Verification Test Automation Script
Use the provided testing matrix script (`run_all_rv32i.sh`) to automatically sweep through all execution targets. It silences standard log congestion and outputs a clear diagnostic status report.

```bash
#!/bin/bash

# Exit immediately if a test script is missing
if [ ! -f "./run_test.sh" ]; then
    echo "Error: ./run_test.sh not found in the current directory!"
    exit 1
fi

rv32i_instructions=(
    "add" "sub" "sll" "slt" "sltu" "xor" "srl" "sra" "or" "and"
    "addi" "slti" "sltiu" "xori" "ori" "andi" "slli" "srli" "srai"
    "lb" "lh" "lw" "lbu" "lhu" "sb" "sh" "sw"
    "beq" "bne" "blt" "bge" "bltu" "bgeu" "jal" "jalr" "lui" "auipc"
)

echo "=================================================="
echo "Starting RV32I Instruction Test Suite"
echo "=================================================="

passed=0
failed_count=0
failed_tests=()

for inst in "${rv32i_instructions[@]}"; do
    echo -n "Running test for: $inst... "
    ./run_test.sh "$inst" > ./output_log_"$inst" 2>&1
    
    if grep -qw "PASSED" ./output_log_"$inst"; then
        echo "[PASSED]"
        ((passed++))
    else 
        echo "[FAILED]"
        ((failed_count++))
        failed_tests+=("$inst")
    fi
done

echo "=================================================="
echo "                TEST SUMMARY                      "
echo "=================================================="
echo "Total Instructions Tested: ${#rv32i_instructions[@]}"
echo "Passed: $passed"
echo "Failed: $failed_count"

if [ $failed_count -gt 0 ]; then
    echo "--------------------------------------------------"
    echo "Failed Instructions list:"
    for failed in "${failed_tests[@]}"; do
        echo "  - $failed"
    done
    echo "=================================================="
    rm -f ./output_log_*
    exit 1
else
    echo "All RV32I base instructions passed successfully!"
    echo "=================================================="
    rm -f ./output_log_*
    exit 0
fi
