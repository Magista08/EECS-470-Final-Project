#!/bin/bash

set -eu

if [ $# -ne 2 ]; then
    echo "USAGE: ./func/min_clk_prd.sh <lar_clk> <test_fils>"
    exit 1
fi

MIN_NUM=0;
MAX_NUM=$1;
TEST_FILS=$2;

DIFF=`expr $MAX_NUM - $MIN_NUM`;

mkdir -p synth_otuputs

while [ $DIFF -gt 3 ]; do
    # Calculate the mid point
    CLK_PRD=`python3 func/even.py $MAX_NUM $MIN_NUM`

    # Change the clock period
    sed -i "s/CLOCK_PERIOD = [0-9]*\.[0-9]*/CLOCK_PERIOD = $CLK_PRD/g" Makefile

    # Run the synthesis
    make $TEST_FILS.syn.out

    # Collect the output
    mkdir -p synth_otuputs/$CLK_PRD
    for i in `ls synth/*.rep`; do
        cp $i synth_otuputs/$CLK_PRD/$i.bak
    done
    for i in `ls synth/*.log`; do
        cp $i synth_otuputs/$CLK_PRD/$i.bak
    done
    for i in `ls synth/*.vg`; do
        cp $i synth_otuputs/$CLK_PRD/$i.bak
    done

    # Check if the design is feasible
    NEGATIVE_SLACK=`make slack | grep -e -[0-9] | wc -l`

    # Update the min and max
    if [ $NEGATIVE_SLACK -eq 0 ]; then
        MAX_NUM=`echo $CLK_PRD | cut -d'.' -f 1`
    else
        MIN_NUM=`echo $CLK_PRD | cut -d'.' -f 1`
    fi

    # Clean the synthesis files
    make nuke
done