#!/bin/bash
# Render 3D scenes on the simulated open-source GPU (fixed-function raster,
# texture and output-merger units), 128x128, checked against Vortex's
# reference images.
R=~/vortex
O=~/runs/renders
mkdir -p $O
cd $R/build || exit 1
# wait for the baseline suite to release this build tree
while ! grep -q "SUITE DONE" ~/runs/baseline/summary.tsv; do sleep 15; done
CFG="-DVX_CFG_EXT_TEX_ENABLE -DVX_CFG_EXT_RASTER_ENABLE -DVX_CFG_EXT_OM_ENABLE -DVX_CFG_NUM_RASTER_CORES=2 -DICACHE_DISABLE -DDCACHE_DISABLE -DLMEM_DISABLE"
echo -e "scene\tstatus\tcycles\tseconds" > $O/summary.tsv
for s in box polybump evilskull tekkaman skybox carnival; do
  start=$(date +%s)
  CONFIGS="$CFG" timeout 5400 ./ci/blackbox.sh --driver=simx --cores=4 --warps=1 --threads=4 --app=gfx_draw3d \
    --args="-w 128 -h 128 -t $s.cgltrace -r ${s}_ref_128.png -o $O/$s.png" > $O/$s.log 2>&1
  st=FAIL; grep -q PASSED $O/$s.log && st=PASS
  cyc=$(grep -oP 'PERF: instrs=\d+, cycles=\K\d+' $O/$s.log | tail -1)
  echo -e "$s\t$st\t$cyc\t$(( $(date +%s) - start ))" >> $O/summary.tsv
done
echo "RENDER DONE" >> $O/summary.tsv
