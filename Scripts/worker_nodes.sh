#!/bin/bash
for((i=1; i<=${WORKER_NODES}; i++));
do
    export WORKER${i}_HOST="worker${i}.com"
    export WORKER${i}_IP="192.168.50.22${i}"
done
