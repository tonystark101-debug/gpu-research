#!/bin/bash
# Week 2 verification of the restructured coalesced scatter (flag on).
#   perfB: official harness on the new cases, then the 64x64x128 headline on rtlsim
#   ours1..3: every dxa rtlsim case, then every dxa + tensor_wg simx case
#   vortex_ours: the 9-workload SimX scorecard
# Usage: week2_verify2.sh <out_dir>
set -u
O="$1"; mkdir -p "$O"
FLAG="-DVX_CFG_DXA_SCATTER_COALESCE"
for t in perfB ours1 ours2 ours3; do
  ( cd ~/vortex_$t/build && make -s -j4 > "$O/$t.build.log" 2>&1; echo "BUILD_RC=$?" >> "$O/$t.build.log" ) &
done
wait
(
  cd ~/vortex_perfB/build
  VX_XLEN=32 ~/ttenv/bin/python -m pytest ci -k "coalesce" -v -p no:cacheprovider > "$O/harness.log" 2>&1
  echo "HARNESS_RC=$?" >> "$O/harness.log"
  HL="-DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DWGMMA_NRC=16 -DVX_CFG_TCU_TYPE=DPI -DVX_CFG_NUM_ALU_BLOCKS=1 -DVX_CFG_NUM_LSU_BLOCKS=1 -DVX_CFG_NUM_FPU_BLOCKS=1 -DVX_CFG_FETCH_WIDTH=2 -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER"
  CONFIGS="$HL $FLAG" ./ci/blackbox.sh --driver=rtlsim --app=sgemm_tcu_wg_dxa --threads=32 --warps=8 --perf=16 --args="-m64 -n64 -k128" > "$O/hl_on_rtl.log" 2>&1
  echo "RC=$?" >> "$O/hl_on_rtl.log"
) &
(
  export SWEEP_CATEGORIES="dxa.yaml"; export SWEEP_DRIVER=rtlsim
  python3 ~/correctness_sweep.py 0 3 ~/vortex_ours1 "$O/rtl" "$FLAG" > "$O/r0.out" 2>&1 &
  python3 ~/correctness_sweep.py 1 3 ~/vortex_ours2 "$O/rtl" "$FLAG" > "$O/r1.out" 2>&1 &
  python3 ~/correctness_sweep.py 2 3 ~/vortex_ours3 "$O/rtl" "$FLAG" > "$O/r2.out" 2>&1 &
  wait
  export SWEEP_CATEGORIES="dxa.yaml tensor_wg.yaml"; export SWEEP_DRIVER=simx
  python3 ~/correctness_sweep.py 0 3 ~/vortex_ours1 "$O/simx" "$FLAG" > "$O/s0.out" 2>&1 &
  python3 ~/correctness_sweep.py 1 3 ~/vortex_ours2 "$O/simx" "$FLAG" > "$O/s1.out" 2>&1 &
  python3 ~/correctness_sweep.py 2 3 ~/vortex_ours3 "$O/simx" "$FLAG" > "$O/s2.out" 2>&1 &
  wait
) &
( ~/week2_score.sh "$O/score" > "$O/score.out" 2>&1 ) &
wait
echo "VERIFY2 DONE" > "$O/done.txt"
