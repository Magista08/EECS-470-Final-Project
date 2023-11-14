#!/bin/bash

set -eu

for i in `ls -r ../verilog/ | grep sv`; do
    sed -i "s/\"../sys_defs.svh\"/DP_PACKET/g" ../verilog/$i
    # sed -i "s/RS_DP_PACKET/RS_IF_PACKET/g" ../verilog/$i
done