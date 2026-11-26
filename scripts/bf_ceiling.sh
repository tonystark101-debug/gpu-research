#!/bin/bash
# What limits the matrix job once the copy engine keeps 64+ reads in flight?
# Try: more L2 miss slots (64 per bank), a longer copy-engine queue (32), and both.
R=~/bf_run.sh; BD=~/vortex_bf/build_bf4
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
K="-DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
P=~/vortex_bf/profiles/jet400m.json
cp ~/vortex_bf/profiles/jet400.json $P
sed -i 's/"name": "jet400"/"name": "jet400m"/; s/"VX_CFG_L2_MSHR_SIZE": [0-9]*/"VX_CFG_L2_MSHR_SIZE": 64/' $P
$R $BD jet400m_inf128_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DVX_CFG_DXA_MAX_INFLIGHT=128 $K" "-m128 -n128 -k256" $P
$R $BD jet400_inf128_q32_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DVX_CFG_DXA_MAX_INFLIGHT=128 -DVX_CFG_DXA_QUEUE_SIZE=32 $K" "-m128 -n128 -k256" ~/vortex_bf/profiles/jet400.json
$R $BD jet400m_inf128_q32_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DVX_CFG_DXA_MAX_INFLIGHT=128 -DVX_CFG_DXA_QUEUE_SIZE=32 $K" "-m128 -n128 -k256" $P
# the same deeper copy engine on the simulator's default (fast) memory, to see what it costs or gains there
$R $BD base_inf64_S1_gemm128 sgemm_tcu_wg_dxa "$T $G32 -DVX_CFG_DXA_MAX_INFLIGHT=64 $K" "-m128 -n128 -k256"
echo CEIL_DONE
