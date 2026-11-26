#!/bin/bash
# Record real switching activity of our core while it runs the 128x128x256 matrix job in the
# chip-level (Verilog) simulator, for an activity-based power estimate of the synthesized core.
# The design settings match the synthesis run (same extensions, same maths-unit versions).
cd ~/vortex_bf
[ -f build_bf5/config.mk ] || (mkdir -p build_bf5 && cd build_bf5 && ../configure --xlen=32 --tooldir=$HOME/tools > ~/runs/bf/configure_build_bf5.log 2>&1)
cd build_bf5
CFG="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_EXT_TFU_ENABLE -DVX_CFG_EXT_ZFHMIN_ENABLE -DVX_CFG_EXT_A_ENABLE -DVX_CFG_EXT_C_ENABLE -DVX_CFG_FPU_TYPE=STD -DVX_CFG_TCU_TYPE=TFR -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16 -DVX_CFG_DXA_MAX_INFLIGHT=64"
START=$(date +%s)
CCACHE_DISABLE=1 CONFIGS="$CFG" /usr/bin/time -v ./ci/blackbox.sh --driver=rtlsim --app=sgemm_tcu_wg_dxa --saif --saif_file=$HOME/runs/bf/gemm128_jet400_inf64.saif --profile=$HOME/vortex_bf/profiles/jet400.json --perf=1 --args="-m128 -n128 -k256" > ~/runs/bf/saif_gemm.log 2>&1
echo "rc=$? wall=$(( $(date +%s) - START ))s" >> ~/runs/bf/saif_gemm.log
grep -a -o 'PASSED!\|FAILED!\|PERF: instrs=[0-9]*, cycles=[0-9]*' ~/runs/bf/saif_gemm.log | tail -2
ls -la ~/runs/bf/gemm128_jet400_inf64.saif 2>&1
echo SAIF_DONE
