#!/bin/bash
# Week 2 item 2: does widening the DXA read window stack with coalescing?
# Tree ours1 = Vortex master + our week-2 SimX change. SimX only.
# Usage: week2_inflight.sh <out_dir>
set -u
O="$1"; mkdir -p "$O"
T=~/vortex_ours1
( cd $T/build && ../configure --xlen=32 --tooldir=$HOME/tools > "$O/configure.log" 2>&1 && make -s -j8 > "$O/build.log" 2>&1; echo "BUILD_RC=$?" >> "$O/build.log" )
G32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
HL="$G32 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
: > "$O/summary.tsv"
for co in 0 1; do
  for inf in 8 16 32 64; do
    X="-DVX_CFG_DXA_MAX_INFLIGHT=$inf"
    [ $co = 1 ] && X="$X -DVX_CFG_DXA_SCATTER_COALESCE"
    id="co${co}_inf${inf}"
    ( cd $T/build && CONFIGS="$HL $X" ./ci/blackbox.sh --driver=simx --app=sgemm_tcu_wg_dxa --perf=16 \
        --args="-m128 -n128 -k256" > "$O/$id.log" 2>&1 )
    cyc=$(grep -o 'cycles=[0-9]*' "$O/$id.log" | tail -1 | cut -d= -f2)
    st=$(grep -o 'noslot_stalls=[0-9]*' "$O/$id.log" | tail -1 | cut -d= -f2)
    w=$(grep -o 'lmem_writes=[0-9]*' "$O/$id.log" | tail -1 | cut -d= -f2)
    echo -e "$id\tpassed=$(grep -c PASSED "$O/$id.log")\tcycles=$cyc\tnoslot=$st\tlmem_writes=$w" >> "$O/summary.tsv"
  done
done
echo "INFLIGHT DONE" >> "$O/summary.tsv"
