#!/bin/bash
# A/B #2 on Vortex's best GEMM (DXA double-buffered), our tree:
#   base     = Vortex as shipped
#   coal     = + coalesced copy-engine scatter writes
#   coal_pf  = + coalesced scatter + tensor-unit tile-buffer prefetch
R=~/vortex_ours
O=~/runs/dxa_ab2
B="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
C="-DVX_CFG_DXA_SCATTER_COALESCE"
P="-DVX_CFG_TCU_TBUF_PREFETCH"
~/run_one.sh $R $O nrc16_coal      sgemm_tcu_wg_dxa "$B $C"    "-m128 -n128 -k256" simx 16
~/run_one.sh $R $O nrc16_coal_pf   sgemm_tcu_wg_dxa "$B $C $P" "-m128 -n128 -k256" simx 11
~/run_one.sh $R $O nrc16_coal_pf_p1 sgemm_tcu_wg_dxa "$B $C $P" "-m128 -n128 -k256" simx 1
echo "AB2 DONE" >> $O/summary.tsv
