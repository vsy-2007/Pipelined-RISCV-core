#!/bin/bash

# Exit immediately if a test script is missing
if [ ! -f "./run_test.sh" ]; then
    echo "Error: ./run_test.sh not found in the current directory!"
    exit 1
fi

# Array of RV32I Base Integer Instructions
rv32i_instructions=(
    # --- R-type (Register-Register Computational) ---
    "add" "sub" "sll" "slt" "sltu" "xor" "srl" "sra" "or" "and"

    # --- I-type (Register-Immediate Computational) ---
    "addi" "slti" "sltiu" "xori" "ori" "andi" "slli" "srli" "srai"

    # --- I-type (Loads) ---
    "lb" "lh" "lw" "lbu" "lhu"

    # --- S-type (Stores) ---
    "sb" "sh" "sw"

    # --- B-type (Conditional Branches) ---
    "beq" "bne" "blt" "bge" "bltu" "bgeu"

    # --- J-type & I-type (Jumps) ---
    "jal" "jalr"

    # --- U-type (Upper Immediates) ---
    "lui" "auipc"
)

echo "=================================================="
echo "Starting RV32I Instruction Test Suite"
echo "=================================================="

# FIX: Removed spaces around '='
passed=0
failed_count=0
failed_tests=()

for inst in "${rv32i_instructions[@]}"; do
    echo -n "Running test for: $inst... "
    
    # Run the test script and capture its exit status
    ./run_test.sh "$inst" > ./output_log_"$inst" 2>&1
    
    # FIX: Correct 'if' statement syntax for running grep
    if grep -qw "PASSED" ./output_log_"$inst"; then
        echo "[PASSED]"
        ((passed++)) # FIX: Bash arithmetic
    else 
        echo "[FAILED]"
        ((failed_count++))
        failed_tests+=("$inst") # Track the name of the failed test
    fi
done

# --- Summary Report ---
echo "=================================================="
echo "                TEST SUMMARY                      "
echo "=================================================="
echo "Total Instructions Tested: ${#rv32i_instructions[@]}"
echo "Passed: $passed"
echo "Failed: $failed_count"

# FIX: Variables now match what was accumulated in the loop
if [ $failed_count -gt 0 ]; then
    echo "--------------------------------------------------"
    echo "Failed Instructions list:"
    for failed in "${failed_tests[@]}"; do
        echo "  - $failed"
    done
    echo "=================================================="
    
    # Clean up logs before exiting with failure code
    rm -f ./output_log_*
    exit 1
else
    echo "All RV32I base instructions passed successfully!"
    echo "=================================================="
    
    # Clean up logs before exiting with success code
    rm -f ./output_log_*
    exit 0
fi
