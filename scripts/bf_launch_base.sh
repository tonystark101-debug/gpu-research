#!/bin/bash
# Launch: chip-size/power synthesis + same-tree baselines with the simulator's default memory.
cd ~/vortex_bf
for b in build_bf2 build_bf3; do
  if [ ! -f $b/config.mk ]; then
    mkdir -p $b && (cd $b && ../configure --xlen=32 --tooldir=$HOME/tools > ~/runs/bf/configure_$b.log 2>&1)
  fi
done
chmod +x ~/bf_run.sh ~/bf_suite.sh ~/bf_synth.sh
nohup ~/bf_synth.sh bf_core 1000 > ~/runs/bf/synth_launch.out 2>&1 &
nohup ~/bf_suite.sh base gemm ~/vortex_bf/build_bf > ~/runs/bf/base_gemm.out 2>&1 &
nohup ~/bf_suite.sh base att16 ~/vortex_bf/build_bf2 > ~/runs/bf/base_att16.out 2>&1 &
nohup ~/bf_suite.sh base att32 ~/vortex_bf/build_bf3 > ~/runs/bf/base_att32.out 2>&1 &
sleep 3
echo "running: $(pgrep -fc 'blackbox|make core')"
echo LAUNCHED
