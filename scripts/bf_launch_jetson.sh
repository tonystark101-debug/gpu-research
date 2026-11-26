#!/bin/bash
# Launch the same runs with the calibrated Jetson per-core memory profile.
# Usage: bf_launch_jetson.sh <tag> <l2_link_latency> <platform_memory_latency>
TAG="$1"; L2L="$2"; ML="$3"
P=~/vortex_bf/profiles/${TAG}.json
cp ~/jetson_orin_nano_core.json $P
sed -i "s/\"name\": \"jetson_orin_nano_core\"/\"name\": \"$TAG\"/; s/\"VX_CFG_L2_LINK_LATENCY\": [0-9]*/\"VX_CFG_L2_LINK_LATENCY\": $L2L/; s/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": [0-9]*/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": $ML/" $P
grep -o '"VX_CFG_L2_LINK_LATENCY": [0-9]*\|"VX_CFG_PLATFORM_MEMORY_LATENCY": [0-9]*' $P
nohup ~/bf_suite.sh $TAG gemm ~/vortex_bf/build_bf $P > ~/runs/bf/${TAG}_gemm.out 2>&1 &
nohup ~/bf_suite.sh $TAG att16 ~/vortex_bf/build_bf2 $P > ~/runs/bf/${TAG}_att16.out 2>&1 &
nohup ~/bf_suite.sh $TAG att32 ~/vortex_bf/build_bf3 $P > ~/runs/bf/${TAG}_att32.out 2>&1 &
sleep 2; echo "LAUNCHED $TAG"
