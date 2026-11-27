# Power of the synthesized core at several global switching activities (OpenSTA, ASAP7 RVT TT).
# Loads the netlist once, then reports total power for each activity (toggles per clock, all nets).
set B $::env(B)
read_liberty $::env(LIB)
read_verilog $B/out/VX_core_top_mapped.v
link_design VX_core_top
read_sdc $B/out/VX_core_top.resolved.sdc
set_cmd_units -time ns -capacitance fF -voltage V -current mA -resistance kOhm -power mW -distance um
foreach a {0.02 0.05 0.10 0.20} {
  set_power_activity -global -activity $a -duty 0.5
  puts "=== ACTIVITY $a"
  report_power
}
puts "POWER_RANGE_DONE"
