#!/bin/bash
# Build the shard trees, then run the correctness sweep in 4 parallel shards.
~/setup_shards.sh
for i in 1 2 3; do
  tail -1 ~/shard$i.build.log
done
O=~/runs/correctness
mkdir -p $O
python3 ~/correctness_sweep.py 0 4 ~/vortex_ours  $O > $O/shard0.out 2>&1 &
python3 ~/correctness_sweep.py 1 4 ~/vortex_ours1 $O > $O/shard1.out 2>&1 &
python3 ~/correctness_sweep.py 2 4 ~/vortex_ours2 $O > $O/shard2.out 2>&1 &
python3 ~/correctness_sweep.py 3 4 ~/vortex_ours3 $O > $O/shard3.out 2>&1 &
wait
echo "SWEEP DONE" > $O/done.txt
