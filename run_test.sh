#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: ./run_test.sh <instruction_test>"
    echo "Example: ./run_test.sh add"
    exit 1
fi

TEST_NAME=$1

# 1. Run Hex Extractor
./generate_all_hex.sh "$TEST_NAME"
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Hex file preparation failed! Check paths inside generate_all_hex.sh${NC}"
    exit 1
fi

echo -e "\nCompiling hardware layers with Verilator..."
rm -rf obj_dir

# 2. Verilator compilation (Suppresses warnings common to test rigs)
verilator -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL --trace -cc topmodule.sv --exe sim_main.cpp

# 3. Build native application binary
make -C obj_dir -f Vtopmodule.mk Vtopmodule
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Compilation failed! Fix syntax errors in your Verilog or C++ wrapper.${NC}"
    exit 1
fi

echo -e "\nExecuting Native Core Simulation Binary..."
echo "----------------------------------------------------------"

# 4. Run your simulation and track the exit status directly
./obj_dir/Vtopmodule
SIM_EXIT_CODE=$?

