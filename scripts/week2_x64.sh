#!/bin/bash
# XLEN=64 check of the coalesced scatter (wider LMEM word: 256 bytes).
# Usage: week2_x64.sh <out_dir>
set -u
O="$1"; mkdir -p "$O"
T=~/vortex_ours
cd $T || exit 1
for f in hw/rtl/dxa/VX_dxa_smem_wr.sv sim/simx/dxa/dxa_core.cpp VX_config.toml ci/testcases/dxa.yaml; do cp ~/vortex_perfB/$f $f; done
git status --short | grep -v '^??' > "$O/tree.txt"
mkdir -p build64 && cd build64
../configure --xlen=64 --tooldir=$HOME/tools > "$O/configure.log" 2>&1
make -s -j6 > "$O/build.log" 2>&1; echo "BUILD_RC=$?" >> "$O/build.log"
FLAG="-DVX_CFG_DXA_SCATTER_COALESCE"
run() { # id driver app configs args
  CONFIGS="$4" ./ci/blackbox.sh --driver=$2 --app=$3 ${5:+--args="$5"} > "$O/$1.log" 2>&1
  echo -e "$1\trc=$?\tpassed=$(grep -c PASSED "$O/$1.log")\t$(grep -o 'cycles=[0-9]*' "$O/$1.log" | tail -1)" >> "$O/summary.tsv"
}
: > "$O/summary.tsv"
run copy_rtl     rtlsim dxa_copy "-DVX_CFG_EXT_DXA_ENABLE $FLAG" "-d1"
run mcast_simx   simx   sgemm_tcu_wg_dxa_mcast "-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_EXT_DXA_ENABLE $FLAG" "-m 128 -n 64 -k 32"
run mcast_rtl    rtlsim sgemm_tcu_wg_dxa_mcast "-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_TCU_TYPE=DPI $FLAG" "-m 128 -n 64 -k 32"
echo "X64 DONE" >> "$O/summary.tsv"
