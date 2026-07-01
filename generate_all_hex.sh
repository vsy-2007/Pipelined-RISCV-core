#!/bin/bash

# Configuration Paths
ISA_DIR= "$2" ## path to the isa directory in the cloned riscv test suite repo 
PREFIX="riscv-none-elf-"

if [ -z "$1" ]; then
    echo "Usage: ./generate_all_hex.sh <instruction_test>"
    echo "Example: ./generate_all_hex.sh add"
    exit 1
fi

TEST_NAME=$1
TARGET_ELF="$ISA_DIR/rv32ui-p-$TEST_NAME"

echo "=========================================================="
echo " Preparing Unified Test Memory: [rv32ui-p-$TEST_NAME]"
echo "=========================================================="

if [ ! -f "$TARGET_ELF" ]; then
    echo "Error: Test binary code not found for '$TEST_NAME' at $TARGET_ELF"
    exit 1
fi

# Clean up old files
rm -f program.hex data.hex flat_mem.bin

# 1. Convert the ENTIRE ELF into a flat, absolute binary starting at 0x0.
# This forces objcopy to automatically pad everything so the internal offsets
# align perfectly with your raw Verilog PC and memory addresses.
${PREFIX}objcopy -O binary "$TARGET_ELF" flat_mem.bin

# 2. Convert the flat binary into your byte-wide text list (1 byte per line)
# Both your Inst_mem and Data_mem can read this same file, or you can copy it.
hexdump -v -e '1/1 "%02x\n"' flat_mem.bin > program.hex

# 3. Create a mirror for data.hex so your untouched Data_mem module can load it
cp program.hex data.hex

LINES=$(wc -l < program.hex)
echo "-> Created unified program.hex & data.hex ($LINES bytes, perfectly aligned)"
echo "=========================================================="
echo " Ready! Run your simulator now."
echo "=========================================================="

# Clean up temporary binary
rm -f flat_mem.bin
