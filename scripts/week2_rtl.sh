#!/bin/bash
# Week 2: coalesced DXA scatter in RTL + SimX. Build, then compare simx vs rtlsim.
#   perfA = Vortex master (flag off = baseline);  perfB = master + our change.
# Usage: week2_rtl.sh <out_dir>
set -u
O="$1"; mkdir -p "$O"
B=~/vortex_perfB
( cd $B/build && ../configure --xlen=32 --tooldir=$HOME/tools > "$O/perfB.configure.log" 2>&1 && make -s -j16 > "$O/perfB.build.log" 2>&1; echo "BUILD_RC=$?" >> "$O/perfB.build.log" )
tail -1 "$O/perfB.build.log"

FLAG="-DVX_CFG_DXA_SCATTER_COALESCE"
# CI case sgemm_tcu_wg_dxa-2 (rtlsim) configuration, plus the headline's fp16 / SS / double buffer.
CI="-DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DWGMMA_NRC=16 -DVX_CFG_TCU_TYPE=DPI -DVX_CFG_NUM_ALU_BLOCKS=1 -DVX_CFG_NUM_LSU_BLOCKS=1 -DVX_CFG_NUM_FPU_BLOCKS=1 -DVX_CFG_FETCH_WIDTH=2"
HL="$CI -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER"
ARGS="-m64 -n64 -k128"

run() {  # tree id driver configs args
  local T=$1 ID=$2 DRV=$3 CFG=$4 A=$5
  ( cd ~/vortex_$T/build && CONFIGS="$CFG" timeout 7200 ./ci/blackbox.sh --driver=$DRV --app=sgemm_tcu_wg_dxa \
      --threads=32 --warps=8 --perf=16 --args="$A" > "$O/$ID.log" 2>&1; echo "RC=$?" >> "$O/$ID.log" )
  local cyc=$(grep -o 'cycles=[0-9]*' "$O/$ID.log" | tail -1 | cut -d= -f2)
  local w=$(grep -o 'lmem_writes=[0-9]*' "$O/$ID.log" | tail -1 | cut -d= -f2)
  local ok=$(grep -c 'PASSED' "$O/$ID.log")
  echo -e "$ID\t$DRV\tpassed=$ok\tcycles=$cyc\tlmem_writes=$w" >> "$O/summary.tsv"
}
: > "$O/summary.tsv"
# simx first (fast), then rtlsim (slow) - baseline tree and our tree in parallel.
run perfA hl_off_simx simx "$HL" "$ARGS"
run perfB hl_on_simx  simx "$HL $FLAG" "$ARGS"
run perfA hl_off_rtl rtlsim "$HL" "$ARGS" &
run perfB hl_on_rtl  rtlsim "$HL $FLAG" "$ARGS" &
wait
echo "WEEK2 RTL DONE" >> "$O/summary.tsv"
