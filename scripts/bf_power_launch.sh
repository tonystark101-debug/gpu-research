#!/bin/bash
# Launch the power-at-several-activities run and the area breakdown, side by side.
export B=~/vortex_bf/build_bf/hw/syn/yosys/bf_core_VX_core_top
export LIB=~/vortex_bf/build_bf/hw/syn/libs/asap7/lib/asap7_rvt_tt.lib
nohup bash -c "/usr/bin/time -v ~/tools/sta/bin/sta -no_init -exit ~/bf_power_range.tcl" > ~/runs/bf/power_range.log 2>&1 &
nohup python3 ~/bf_area_by_unit.py $LIB $B/out/VX_core_top_mapped.v > ~/runs/bf/area_by_unit.txt 2>&1 &
sleep 2; echo launched
