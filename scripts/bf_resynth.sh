#!/bin/bash
# Restart the core synthesis without Yosys's SAT-based resource sharing (the "share" pass took
# ~15 h projected on this design). Reuses the generated sources in the same build dir.
if pgrep -x yosys >/dev/null; then echo "a yosys is still running:"; pgrep -xa yosys; exit 1; fi
export YOSYS_SHARE=0
nohup ~/bf_synth.sh bf_core 1000 > ~/runs/bf/synth_launch2.out 2>&1 &
sleep 20
grep -c "share" ~/vortex_bf/build_bf/hw/syn/yosys/bf_core_VX_core_top/out/synth.ys
pgrep -xa yosys | cut -c1-80
echo RESYNTH_STARTED
