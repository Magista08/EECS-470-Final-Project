#!/bin/bash

set -eu
directory="verilog/"
files=$(find "$directory" -type f \( -name "*.svh" -o -name "*.sv" -o -name "*.svf" \))

for i in $files; do
    JAL_EXIST=`cat $i | grep -n "next_buffer[0].value" | grep -n "module" | wc -l`
    if [ $JAL_EXIST -ne 0 ]; then
        echo $i
    fi
done