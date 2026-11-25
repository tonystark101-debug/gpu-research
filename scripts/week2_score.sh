#!/bin/bash
# Week 2: the 9-workload DXA scorecard with the RTL-matched coalescing rule.
# Tree vortex_ours -> Vortex master + week-2 change (flag off = baseline, flag on = fix).
# Usage: week2_score.sh <out_dir>
set -u
O="$1"; mkdir -p "$O"
T=~/vortex_ours
(
  cd $T || exit 1
  git checkout -q -- . 2>/dev/null
  git fetch -q origin master && git checkout -q --detach origin/master || exit 2
  cp ~/vortex_perfB/sim/simx/dxa/dxa_core.cpp sim/simx/dxa/dxa_core.cpp
  cp ~/vortex_perfB/hw/rtl/dxa/VX_dxa_smem_wr.sv hw/rtl/dxa/VX_dxa_smem_wr.sv
  cp ~/vortex_perfB/VX_config.toml VX_config.toml
  cp ~/vortex_perfB/ci/testcases/dxa.yaml ci/testcases/dxa.yaml
  git status --short | grep -v '^??' > "$O/tree.txt"
  cd build && ../configure --xlen=32 --tooldir=$HOME/tools > "$O/configure.log" 2>&1 && make -s -j8 > "$O/build.log" 2>&1
  echo "BUILD_RC=$?" >> "$O/build.log"
)
~/pr_scorecard.sh $T coalesce "$O/fix" > "$O/fix.out" 2>&1
echo "SCORE DONE" > "$O/done.txt"
