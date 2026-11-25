#!/bin/bash
# Two perf trees (copies of ours): one runs Vortex as shipped, one runs ours.
for t in perfA perfB; do
  (
    rsync -a --exclude '/build' ~/vortex_ours/ ~/vortex_$t/
    mkdir -p ~/vortex_$t/build
    cd ~/vortex_$t/build && ../configure --xlen=32 --tooldir=$HOME/tools > ~/$t.configure.log 2>&1
    make -s -j4 > ~/$t.build.log 2>&1
    echo "BUILD_RC=$?" >> ~/$t.build.log
  ) &
done
wait
~/perf_scorecard.sh ~/vortex_perfA base ~/runs/score_base > ~/runs/score_base.out 2>&1 &
~/perf_scorecard.sh ~/vortex_perfB ours ~/runs/score_ours > ~/runs/score_ours.out 2>&1 &
wait
