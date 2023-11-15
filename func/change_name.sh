#!/bin/bash

set -eu

# Define the directory where the files are located
directory="../verilog"

# Use find to locate all .svh, .sv, and .svf files
files=$(find "$directory" -type f \( -name "*.svh" -o -name "*.sv" -o -name "*.svf" \))

# Temperory backup for p3
# tar -czvf ../verilog/p3.tgz ../verilog/p3

# Iterate through the list of files and use sed for substitution
for file in $files; do
    # Perform the substitution using sed
    # sed -i 's/"../sys_defs.svh"/"verilog/sys_defs.svh"/g' "$file"
    # sed -i 's/"../ISA.svh"/"verilog/ISA.svh"/g' "$file"
    sed -i 's/RS_DP_PACKET/RS_IF_PACKET/g' "$file"
done

# Replace the original P3
# tar -xzvf ../verilog/p3.tgz ../verilog