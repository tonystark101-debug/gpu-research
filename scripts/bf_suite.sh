#!/bin/bash
# One group of the battlefield runs, with or without a memory profile.
# Usage: bf_suite.sh <tag> <group: gemm|att16|att32> <build_dir> [profile_json]
TAG="$1"; GRP="$2"; BD="$3"; PROF="$4"
R=~/bf_run.sh
# Matrix jobs: our core (32 threads x 8 warps, issue width 4) with the AI unit, the copy engine and our coalescing fix.
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
# Attention (FA2 with our fix), hardware exp unit on.
A="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_NRC=8 -DVX_CFG_EXT_TFU_ENABLE"
case "$GRP" in
  gemm)
    $R $BD ${TAG}_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256" $PROF
    $R $BD ${TAG}_S3_gemm128_nrc32 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=32" "-m128 -n128 -k256" $PROF
    $R $BD ${TAG}_S4_gemm256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m256 -n256 -k256" $PROF
    ;;
  att16)
    $R $BD ${TAG}_A16_n128 flash_attn_tcu_wg "$A -DVX_CFG_NUM_THREADS=16" "-N128 -D64" $PROF
    ;;
  att32)
    $R $BD ${TAG}_A32_n128 flash_attn_tcu_wg "$A -DVX_CFG_NUM_THREADS=32" "-N128 -D64" $PROF
    $R $BD ${TAG}_A32_n256 flash_attn_tcu_wg "$A -DVX_CFG_NUM_THREADS=32" "-N256 -D64" $PROF
    ;;
esac
echo "SUITE_DONE $TAG $GRP"
