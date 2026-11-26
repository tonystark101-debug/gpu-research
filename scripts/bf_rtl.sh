#!/bin/bash
# Check the copy-engine depth result in the Verilog model (rtlsim), on the Jetson memory share.
R=~/bf_run_rtl.sh
BD=~/vortex_bf/build_bf2
P=~/vortex_bf/profiles/jet400.json
T="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DITYPE=fp16 -DOTYPE=fp32"
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
K="-DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
cd $BD
for INF in 8 64; do
  L=rtl_jet400_inf${INF}_S1_gemm128; LOG=~/runs/bf/$L.log
  START=$(date +%s)
  CCACHE_DISABLE=1 CONFIGS="$T $G32 -DVX_CFG_DXA_MAX_INFLIGHT=$INF $K" timeout 10800 ./ci/blackbox.sh --driver=rtlsim --app=sgemm_tcu_wg_dxa --perf=1 --profile=$P --args="-m128 -n128 -k256" > $LOG 2>&1
  ST=FAIL; grep -aq "PASSED" $LOG && ST=PASS
  CYC=$(grep -aoP 'PERF: instrs=\d+, cycles=\K\d+' $LOG | tail -1); INS=$(grep -aoP 'PERF: instrs=\K\d+' $LOG | tail -1)
  echo -e "$L\t$ST\t$CYC\t$INS\t\t$(( $(date +%s) - START ))\t$P" >> ~/runs/bf/results.tsv
  echo "$L $ST cycles=$CYC"
done
echo RTL_DONE
