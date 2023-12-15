#!/bin/bash

set -eu

if [ $# -ne 2 ]; then
    echo "Usage: ./func/compare.sh <test_name> <compare_content = wb=1, syn_mem=2, mem=3,syn_wb=4>"
    exit 1
fi

TEST_NAME=$1
DIFF_TYPE=$2

FILE_TYPE="wb"
CORRECT_TYPE="wb"
if [ $DIFF_TYPE -ne 1 ]; then
    FILE_TYPE="out"
    CORRECT_TYPE="out"
fi

# Check if test file in final_project
P4_TEST_EXIST=`ls -l programs/ | grep $TEST_NAME | wc -l`
if [ $P4_TEST_EXIST -eq 0 ]; then
    echo "Test $TEST_NAME does not exist"
    exit 1
fi

mkdir -p correct_output

# Find if the correct output file exists
if [ ! -f ../correct_output/$TEST_NAME.$FILE_TYPE ]; then
    cd ../../p3

    # Check if the test file in project03
    TEST_EXTSTED=`ls -l programs/ | grep $TEST_NAME | wc -l`
    S_EXISTED=`ls -l ../git_final/p4/programs/ | grep $TEST_NAME.s | wc -l`
    C_EXISTED=`ls -l ../git_final/p4/programs/ | grep $TEST_NAME.c | wc -l`
    if [ $TEST_EXTSTED -eq 0 ]; then
        if [ $S_EXISTED -ne 0 ]; then
            cp ../git_final/p4/$TEST_NAME.s programs/$TEST_NAME.s
        else
            cp ../git_final/p4/programs/$TEST_NAME.c programs/$TEST_NAME.c
        fi
    fi

    # Get the correct output
    make $TEST_NAME.out

    # Move the correct output to final_project
    mv output/$TEST_NAME.out  ../git_final/p4/correct_output/$TEST_NAME.out
    mv output/$TEST_NAME.wb   ../git_final/p4/correct_output/$TEST_NAME.wb
    mv output/$TEST_NAME.ppln ../git_final/p4/correct_output/$TEST_NAME.ppln

    # Go Back
    cd ../git_final/p4/
fi

# Get the correct output
if [[ $DIFF_TYPE -eq 1 ]] || [[ $DIFF_TYPE -eq 3 ]]; then
    make $TEST_NAME.out
fi
if [[ $DIFF_TYPE -eq 2 ]] || [[ $DIFF_TYPE -eq 4 ]]; then
    make $TEST_NAME.syn.out
fi

if [ $DIFF_TYPE -eq 3 ]; then
    FILE_TYPE="mem"
    CORRECT_TYPE="mem"

    # Create the correct output file
    cat correct_output/$TEST_NAME.out | grep "@@@ mem" > correct_output/$TEST_NAME.$FILE_TYPE

    # Create the output file
    cat output/$TEST_NAME.out | grep "@@@ mem" > output/$TEST_NAME.$FILE_TYPE
elif [ $DIFF_TYPE -eq 2 ]; then
    FILE_TYPE="syn.mem"
    CORRECT_TYPE="mem"

    # Create correct mem file from sim
    cat correct_output/$TEST_NAME.out | grep "@@@ mem" > correct_output/$TEST_NAME.$CORRECT_TYPE 

    # Create mem file by synthesis
    cat output/$TEST_NAME.syn.out | grep "@@@ mem" > output/$TEST_NAME.$FILE_TYPE
elif [ $DIFF_TYPE -eq 4 ]; then
    FILE_TYPE="syn.wb"
    CORRECT_TYPE="wb"
fi

# Compare
diff -u output/$TEST_NAME.$FILE_TYPE correct_output/$TEST_NAME.$CORRECT_TYPE > output/$TEST_NAME.$FILE_TYPE.out.txt | true 

# Print the result
LINE_NUM=`cat output/$TEST_NAME.$FILE_TYPE.out.txt | wc -l`
if [ $LINE_NUM -eq 0 ]; then
    echo "@@@ $FILE_TYPE File is correct"
else
    echo "@@@ $FILE_TYPE File is wrong"
fi

