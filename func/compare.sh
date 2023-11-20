#!/bin/bash

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: ./compare.sh <compare_content = wb=1, out=2, all=3>"
    exit 1
fi
DIFF_TYPE=$1
if [ $DIFF_TYPE -ne 1 ]; then
    diff -u ../correct_output/p3_mult_no_lsq.out ../output/mult_no_lsq.out > ../output/out_diff.out.txt | true
    LINE_NUM=`cat ../output/out_diff.out.txt | wc -l`
    if [ $LINE_NUM -eq 1 ]; then
        echo "@@@Output File is correct"
    else
        echo "@@@Output File is wrong"
    fi
fi
if [ $DIFF_TYPE -ne 0 ]; then
    diff -u ../correct_output/p3_mult_no_lsq.wb ../output/mult_no_lsq.wb > ../output/wb_diff.wb.txt | true
    LINE_NUM=`cat ../output/wb_diff.wb.txt | wc -l`
    if [ $LINE_NUM -eq 0 ]; then
        echo "@@@Write back File is correct"
    else
        echo "@@@Write back File is wrong"
    fi
fi