#!/bin/bash
# Calibrate the Jetson per-core memory profile: measure L2-hit and DRAM latency with Vortex's
# pointer-chase check, on our core's shape, in its own build dir.
# Usage: bf_calib.sh <l2_link_latency> <platform_memory_latency>
L2L="$1"; ML="$2"
P=~/vortex_bf/profiles/jetson_orin_nano_core.json
cp ~/jetson_orin_nano_core.json $P
sed -i "s/\"VX_CFG_L2_LINK_LATENCY\": [0-9]*/\"VX_CFG_L2_LINK_LATENCY\": $L2L/; s/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": [0-9]*/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": $ML/" $P
cd ~/vortex_bf
[ -f build_bf4/config.mk ] || (mkdir -p build_bf4 && cd build_bf4 && ../configure --xlen=32 --tooldir=$HOME/tools > ~/runs/bf/configure_build_bf4.log 2>&1)
cd build_bf4
export CONFIGS="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
python3 ../ci/profile_check.py --profile=jetson_orin_nano_core --metrics=peak,latency --tolerance=0.05 2>&1 | tail -12
echo "CALIB_DONE l2link=$L2L memlat=$ML"
