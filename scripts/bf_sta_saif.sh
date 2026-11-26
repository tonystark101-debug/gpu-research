#!/bin/bash
# Re-run timing/power on the synthesized core with recorded switching activity (SAIF) from the
# Verilog simulation of the 128x128x256 matrix job. Writes reports to reports_saif/.
# Usage: bf_sta_saif.sh <saif_file> <saif_scope>
SAIF="$1"; SCOPE="$2"
B=~/vortex_bf/build_bf/hw/syn/yosys/bf_core_VX_core_top
cd $B || exit 1
NET=$(ls -t $B/out/*.v 2>/dev/null | head -1)
LIB=$(grep -o 'LIB_TGT=[^ ]*' ~/runs/bf/synth_bf_core.log | head -1 | cut -d= -f2)
[ -z "$LIB" ] && LIB=$(ls ~/vortex_bf/build_bf/hw/syn/libs/asap7/lib/asap7_rvt_tt.lib 2>/dev/null)
SDC=$(ls $B/*.sdc $B/out/*.sdc 2>/dev/null | head -1)
[ -z "$SDC" ] && SDC=~/vortex_bf/hw/syn/yosys/project.sdc
echo "netlist=$NET lib=$LIB sdc=$SDC saif=$SAIF scope=$SCOPE"
mkdir -p reports_saif
TOP=VX_core_top NETLIST=$NET LIB_TGT=$LIB SDC_FILE=$SDC RPT_DIR=$B/reports_saif SAIF_FILE=$SAIF SAIF_INST=$SCOPE \
  CLOCK_FREQ=1000 ~/tools/sta/bin/sta -no_init -exit ~/vortex_bf/hw/syn/yosys/run_sta.tcl > $B/reports_saif/sta.log 2>&1
echo "rc=$?"
head -30 $B/reports_saif/power.rpt 2>/dev/null
wc -l $B/reports_saif/saif_annotated.rpt $B/reports_saif/saif_unannotated.rpt 2>/dev/null
echo STA_SAIF_DONE
