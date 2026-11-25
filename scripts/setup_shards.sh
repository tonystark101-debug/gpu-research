#!/bin/bash
# Make 3 more copies of our tree (vortex_ours1..3) so the correctness sweep can
# run in 4 parallel shards. Keeps third_party/*/build; skips the top build dir.
for i in 1 2 3; do
  (
    rsync -a --exclude '/build' ~/vortex_ours/ ~/vortex_ours$i/
    mkdir -p ~/vortex_ours$i/build
    cd ~/vortex_ours$i/build && ../configure --xlen=32 --tooldir=$HOME/tools > ~/shard$i.configure.log 2>&1
    make -s -j4 > ~/shard$i.build.log 2>&1
    echo "BUILD_RC=$?" >> ~/shard$i.build.log
  ) &
done
wait
echo SHARDS READY > ~/shards.status
