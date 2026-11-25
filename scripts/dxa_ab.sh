#!/bin/bash
# A/B on Vortex's best GEMM (DXA double-buffered), in our tree:
# same tree, same kernel, with and without our tile-buffer prefetch.
R=~/vortex_ours
O=~/runs/dxa_ab
B="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER"
PF="-DVX_CFG_TCU_TBUF_PREFETCH"
for nrc in 16 8; do
  ~/run_one.sh $R $O dxa_db_nrc${nrc}_base sgemm_tcu_wg_dxa "$B -DWGMMA_NRC=$nrc" "-m128 -n128 -k256"
  ~/run_one.sh $R $O dxa_db_nrc${nrc}_ours sgemm_tcu_wg_dxa "$B -DWGMMA_NRC=$nrc $PF" "-m128 -n128 -k256"
done
echo "AB DONE" >> $O/summary.tsv
