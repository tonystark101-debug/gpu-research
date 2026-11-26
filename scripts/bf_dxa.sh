#!/bin/bash
# What-if: let the copy engine (DXA) keep more memory reads in flight, under the Jetson memory.
# Usage: bf_dxa.sh <inflight> <build_dir> [profile_tag]
INF="$1"; BD="$2"; PT="${3:-jet400}"
P=~/vortex_bf/profiles/${PT}.json
R=~/bf_run.sh
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
X="-DVX_CFG_DXA_MAX_INFLIGHT=$INF"
$R $BD ${PT}_inf${INF}_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 $X -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256" $P
$R $BD ${PT}_inf${INF}_S3_gemm128_nrc32 sgemm_tcu_wg_dxa "$T $G32 $X -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=32" "-m128 -n128 -k256" $P
$R $BD ${PT}_inf${INF}_S4_gemm256 sgemm_tcu_wg_dxa "$T $G32 $X -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m256 -n256 -k256" $P
echo "DXA_DONE $INF"
