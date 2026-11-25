#!/bin/bash
# Day-6 performance scorecard. Usage: perf_scorecard.sh <tree> <base|ours> <out_dir>
R="$1"; MODE="$2"; O="$3"
if [ "$MODE" = "ours" ]; then
  X="-DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_TCU_TBUF_PREFETCH"
else
  X=""
fi
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
G16="-DVX_CFG_NUM_THREADS=16 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
run() { ~/run_one.sh "$R" "$O" "$1" "$2" "$3 $X" "$4" simx 16; }
# DXA (bulk-copy) GEMMs: Vortex's best matrix path
run S1_nt32_nrc16_ss_db_128x128x256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256"
run S2_nt32_nrc8_ss_db_128x128x256  sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=8"  "-m128 -n128 -k256"
run S3_nt32_nrc32_ss_db_128x128x256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=32" "-m128 -n128 -k256"
run S4_nt32_nrc16_ss_db_256x256x256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m256 -n256 -k256"
run S5_nt16_nrc16_ss_db_128x128x256 sgemm_tcu_wg_dxa "$T $G16 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256"
run S6_nt32_nrc16_rs_db_128x128x256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_RS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16" "-m128 -n128 -k256"
run S7_nt32_nrc16_ss_single_128x128x256 sgemm_tcu_wg_dxa "$T $G32 -DWGMMA_SS -DWGMMA_NRC=16" "-m128 -n128 -k256"
run S8_mcast_default sgemm_tcu_wg_dxa_mcast "-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_EXT_DXA_ENABLE" "-m 128 -n 64 -k 32"
run S9_sparse_dxa_nt32_128x128x128 sgemm_tcu_wg_sp_dxa "$G32 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_TCU_SPARSE_ENABLE -DVX_CFG_EXT_DXA_ENABLE" "-m 128 -n 128 -k 128"
# Software-staged kernels (no bulk-copy engine): our copy fix cannot help these
run N1_gemm_swload_nt32_nrc16_ss sgemm_tcu_wg "-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 $G32 -DWGMMA_SS -DWGMMA_NRC=16" "-m128 -n128 -k128"
run N2_attn_nt16_fp16 flash_attn_tcu_wg "-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 $G16 -DWGMMA_NRC=8" "-N 128 -D 64"
echo "SCORECARD DONE" >> "$O/summary.tsv"
