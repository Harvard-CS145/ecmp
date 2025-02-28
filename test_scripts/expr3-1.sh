#!/bin/bash

set -e

echo "run ecmp controller for FatTree"
./controller/controller_fattree_l3.py 4
echo "generate trace (project 1)"
./apps/trace/generate_trace.py ./apps/trace/project1.json

for i in {1..5}
do
    echo "run traffic traces $i/5"
    sudo ./apps/send_traffic.py --trace ./apps/trace/project1.trace
done
echo "finish Expr 3-1"
