#!/bin/bash

set -eu

for file in `find programs/ -name *.s`; do
		
	MODULE_NAME=$(basename "$file" ".s")

	# Show the beginning message
	echo -e "\e[1m================ Module: $MODULE_NAME ================\e[0m"

	# Compare the write back file
        echo -e "\e[1m================ Comparing for the WB files ================\e[0m"
	WB_INFO=`./func/compare.sh $MODULE_NAME 2`
	WB_ERROR=`echo $WB_INFO | grep wrong | wc -l`
	
	# Compare the mem file
	echo -e "\e[1m================ Comparing for the MEM files ================\e[0m"
	MEM_INFO=`./func/compare.sh $MODULE_NAME 4`
	MEM_ERROR=`echo $MEM_INFO | grep wrong | wc -l`

	if [ $WB_ERROR -eq 1 ]; then
		echo -e "\e[1m================ MODULE WB INCORRECT ================\e[0m"
	elif [ $MEM_ERROR -eq 1 ]; then
		echo -e "\e[1m================ MODULE MEM INCORREECT ================\e[0m"
	else
		echo -e "\e[1m================ MODULE PASSED WB AND MEM FILE ================\e[0m"
	fi

	echo ""	
done	

