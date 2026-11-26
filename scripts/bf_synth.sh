#!/bin/bash
# Our core through Vortex's open-source chip flow: Yosys maps the design to ASAP7 cells
# (an academic 7 nm-class library) and OpenSTA reports area, timing and power.
# Power here is vectorless (default switching activity); a workload-based run comes later.
# Usage: bf_synth.sh <prefix> <clock_mhz> "<extra configs>"
PFX="${1:-bf_core}"; CLK="${2:-1000}"; EXTRA="$3"
cd ~/vortex_bf/build_bf/hw/syn/yosys/dut || exit 1
CFG="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_EXT_TFU_ENABLE -DVX_CFG_EXT_ZFHMIN_ENABLE $EXTRA"
LOG=~/runs/bf/synth_$PFX.log
START=$(date +%s)
/usr/bin/time -v make core PREFIX=$PFX CONFIGS="$CFG" CLOCK_FREQ=$CLK > $LOG 2>&1
echo "rc=$? wall=$(( $(date +%s) - START ))s" >> $LOG
echo SYNTH_DONE >> $LOG
