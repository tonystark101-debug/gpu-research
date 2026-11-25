#!/bin/bash
# Profile Vortex's best GEMM (DXA double-buffered) with the core, memory and
# DXA counter classes, to find where the cycles go.
R=~/vortex_ours
O=~/runs/profile
B="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
for p in 1 16 7 4; do
  ~/run_one.sh $R $O dxa_nrc16_perf$p sgemm_tcu_wg_dxa "$B" "-m128 -n128 -k256" simx $p
done
echo "PROFILE DONE" >> $O/summary.tsv
