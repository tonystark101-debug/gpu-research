#!/bin/bash
# Sensitivity: the same Jetson per-core memory, with main-memory delay 300 and 600 ticks instead of 400.
# (Calibration: delay = 280 + PLATFORM_MEMORY_LATENCY at an L2 link of 76, so 300 -> 20, 600 -> 320.)
R=~/bf_run.sh; BD=~/vortex_bf/build_bf4
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
A="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_NRC=8 -DVX_CFG_EXT_TFU_ENABLE"
for pair in "jet300 20" "jet600 320"; do
  set -- $pair; TAG=$1; ML=$2
  P=~/vortex_bf/profiles/${TAG}.json
  cp ~/jetson_orin_nano_core.json $P
  sed -i "s/\"name\": \"jetson_orin_nano_core\"/\"name\": \"$TAG\"/; s/\"VX_CFG_L2_LINK_LATENCY\": [0-9]*/\"VX_CFG_L2_LINK_LATENCY\": 76/; s/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": [0-9]*/\"VX_CFG_PLATFORM_MEMORY_LATENCY\": $ML/" $P
  $R $BD ${TAG}_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256" $P
  $R $BD ${TAG}_A32_n128 flash_attn_tcu_wg "$A -DVX_CFG_NUM_THREADS=32" "-N128 -D64" $P
done
echo "SENS_DONE"
