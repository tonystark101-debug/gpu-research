#!/bin/bash
# Measure the simulator's DEFAULT memory (what the yardstick used): load-to-use latency of a cold
# pointer chase (every load goes to memory) and streaming bandwidth (vecadd), on our core's shape.
cd ~/vortex_bf
[ -f build_bf5/config.mk ] || (mkdir -p build_bf5 && cd build_bf5 && ../configure --xlen=32 --tooldir=$HOME/tools > ~/runs/bf/configure_build_bf5.log 2>&1)
cd build_bf5
export CONFIGS="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
c() { ./ci/blackbox.sh --driver=simx --app=$1 --args="$2" --clusters=1 --cores=1 2>&1 | grep -aoP 'PERF: instrs=\d+, cycles=\K\d+' | tail -1; }
a=$(c chase "-b131072 -w0 -c -i256"); b=$(c chase "-b131072 -w0 -c -i512")
echo "default memory, cold chase: $a / $b cycles -> $(( (b - a) / 256 )) cycles per load"
for n in 262144 1048576; do
  v=$(c vecadd "-n$n")
  echo "vecadd n=$n: $v cycles -> $(( 3 * 4 * n / v )) bytes per cycle (2 reads + 1 write of fp32)"
done
echo DEFMEM_DONE
