#!/usr/bin/env bash
# Harden one Tiny Tapeout project locally (same steps as tt-gds-action), then
# run the gate-level test on the resulting netlist.
# Usage: harden_tt.sh <project_dir> <pdk: sky130A | gf180mcuD>
set -euo pipefail
proj="$1"
pdk="$2"
export PATH="$HOME/.local/bin:$PATH"
export PDK_ROOT="$HOME/pdk"
export PDK="$pdk"
# shellcheck disable=SC1091
. "$HOME/ttenv/bin/activate"
cd "$proj"
rm -rf tt runs tt_submission
# tt_tool reads the git remote; a local build only needs a placeholder one.
if [ ! -d .git ]; then
  git init -q
  git remote add origin https://github.com/placeholder/local-build
  git -c user.name=local -c user.email=local@localhost add -A
  git -c user.name=local -c user.email=local@localhost commit -q -m "local build"
fi
cp -r "$HOME/tt-support-tools" tt
./tt/tt_tool.py --create-user-config --pdk "$pdk"
./tt/tt_tool.py --harden --pdk "$pdk"
echo "=== STATS"
./tt/tt_tool.py --print-stats --pdk "$pdk" || true
echo "=== CELLS"
./tt/tt_tool.py --print-cell-category --pdk "$pdk" || true
echo "=== WARNINGS"
./tt/tt_tool.py --print-warnings --pdk "$pdk" || true
./tt/tt_tool.py --create-tt-submission --pdk "$pdk"
echo "=== GL TEST"
cp tt_submission/*.v test/gate_level_netlist.v
(cd test && rm -f results.xml && make clean >/dev/null && GATES=yes make 2>&1 | tail -16)
python -m cocotb_tools.check_results test/results.xml && echo "GL RESULTS OK"
echo "HARDEN DONE"
