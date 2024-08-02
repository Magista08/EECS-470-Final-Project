#!/bin/bash

set -eu
directory="verilog/"
files=$(find "$directory" -type f \( -name "*.svh" -o -name "*.sv" -o -name "*.svf" \))

for i in $files; do
    JAL_EXIST=`cat $i | grep -n "display" | wc -l`
    if [ $JAL_EXIST -ne 0 ]; then
        echo $i
    fi
done