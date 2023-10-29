#!/bin/bash

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 <ONE_LINE = 1 | RS = 2>"
    exit 1
fi

TEST_MODE=$1

if [ $TEST_MODE -eq 1 ]; then
    echo -e "\e[1m=== Testing RS_ONE_LINE.sv ===\e[0m"
    
    # Change the variable in Makefile
    sed -i "s/RS.sv RS_ONE_LINE.sv/RS_ONE_LINE.sv/g" Makefile
    sed -i "s/RS_tb.sv/RS_LINE_test.sv/g" Makefile

    # Run the test
    make clean
    make sim
    
else
    echo -e "\e[1m=== Testing RS.sv RS_ONE_LINE.sv ===\e[0m"
    
    # Change the variable in Makefile
    unchanged=`cat Makefile | grep "RS.sv RS_ONE_LINE.sv" | wc -l`
    if [ $unchanged -eq 0 ]; then
        sed -i "s/RS_ONE_LINE.sv/RS.sv RS_ONE_LINE.sv/g" Makefile
    fi
    sed -i "s/RS_LINE_test.sv/RS_tb.sv/g" Makefile

    # Run the test
    make clean
    make sim
fi