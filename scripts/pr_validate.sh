#!/bin/bash
# Validate the coalesced-scatter fix on Vortex's latest master before offering it upstream.
#   perfA  = master as shipped (flag off)      -> baseline scorecard
#   perfB  = master + patch, flag on          -> fix scorecard
#   ours1..3 = master + patch, flag on        -> official dxa + tensor_wg simx lists
# Usage: pr_validate.sh <patch_file>
set -u
P="$1"
O=~/runs/pr
mkdir -p "$O"
prep() {  # $1 = tree name, $2 = apply patch (1/0)
  local T=~/vortex_$1
  (
    cd "$T" || exit 1
    git checkout -q -- sim/simx/dxa/dxa_core.cpp sim/simx/tcu/tcu_tbuf.cpp sim/simx/tcu/tcu_tbuf.h sim/simx/tcu/tcu_unit.cpp
    git fetch -q origin master && git checkout -q --detach origin/master || exit 2
    if [ "$2" = 1 ]; then git apply "$P" || exit 3; fi
    git log -1 --format='%H %s' > "$O/$1.head"
    git status --short | grep -v '^??' >> "$O/$1.head"
    cd build && make -s -j4 > "$O/$1.build.log" 2>&1
    echo "BUILD_RC=$?" >> "$O/$1.build.log"
  )
  echo "$1 prep rc=$?" >> "$O/prep.txt"
}
: > "$O/prep.txt"
prep perfA 0 &
prep perfB 1 &
prep ours1 1 &
prep ours2 1 &
prep ours3 1 &
wait
cat "$O/prep.txt"

# Scorecard: the 9 copy-engine workloads, flag off vs on.
~/pr_scorecard.sh ~/vortex_perfA base "$O/score_base" > "$O/score_base.out" 2>&1 &
~/pr_scorecard.sh ~/vortex_perfB coalesce "$O/score_fix" > "$O/score_fix.out" 2>&1 &

# Official simx lists for the copy engine and warp-group tensor unit, flag on.
export SWEEP_CATEGORIES="dxa.yaml tensor_wg.yaml"
python3 ~/correctness_sweep.py 0 3 ~/vortex_ours1 "$O/correctness" "-DVX_CFG_DXA_SCATTER_COALESCE" > "$O/c0.out" 2>&1 &
python3 ~/correctness_sweep.py 1 3 ~/vortex_ours2 "$O/correctness" "-DVX_CFG_DXA_SCATTER_COALESCE" > "$O/c1.out" 2>&1 &
python3 ~/correctness_sweep.py 2 3 ~/vortex_ours3 "$O/correctness" "-DVX_CFG_DXA_SCATTER_COALESCE" > "$O/c2.out" 2>&1 &
wait
echo "PR VALIDATE DONE" > "$O/done.txt"
