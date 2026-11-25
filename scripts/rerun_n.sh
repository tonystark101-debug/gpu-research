#!/bin/bash
# Re-run the two software-staged kernels with the tensor-unit counter class.
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
G16="-DVX_CFG_NUM_THREADS=16 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
X="-DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_TCU_TBUF_PREFETCH"
N1="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 $G32 -DWGMMA_SS -DWGMMA_NRC=16"
N2="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 $G16 -DWGMMA_NRC=8"
( ~/run_one.sh ~/vortex_perfA ~/runs/score_base N1b_gemm_swload_nt32_nrc16_ss sgemm_tcu_wg "$N1" "-m128 -n128 -k128" simx 11
  ~/run_one.sh ~/vortex_perfA ~/runs/score_base N2b_attn_nt16_fp16 flash_attn_tcu_wg "$N2" "-N 128 -D 64" simx 11
  echo "RERUN DONE" >> ~/runs/score_base/summary.tsv ) &
( ~/run_one.sh ~/vortex_perfB ~/runs/score_ours N1b_gemm_swload_nt32_nrc16_ss sgemm_tcu_wg "$N1 $X" "-m128 -n128 -k128" simx 11
  ~/run_one.sh ~/vortex_perfB ~/runs/score_ours N2b_attn_nt16_fp16 flash_attn_tcu_wg "$N2 $X" "-N 128 -D 64" simx 11
  echo "RERUN DONE" >> ~/runs/score_ours/summary.tsv ) &
wait
