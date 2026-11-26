#!/bin/bash
# Battlefield step, tree setup.
# One tree = Vortex master 2221ee2 + PR #506 (copy-engine coalescing, SimX + RTL)
#          + the attention fix (uncommitted test code, carried over from ~/vortex_att).
set -e
mkdir -p ~/runs/bf
if [ ! -d ~/vortex_bf ]; then cp -a ~/vortex_att ~/vortex_bf; fi
cd ~/vortex_bf
git fetch -q https://github.com/tonystark101-debug/vortex.git perf/dxa-scatter-coalesce
echo "== PR #506 head"; git log --oneline -3 FETCH_HEAD
git checkout -q -B bf 2221ee286
if ! git log --oneline -5 | grep -q "coalesce tiled scatter writes in the RTL"; then
  git -c user.name="tonystark101-debug" -c user.email="61789569+tonystark101-debug@users.noreply.github.com" \
      cherry-pick FETCH_HEAD~1 FETCH_HEAD
fi
echo "== tree"; git log --oneline -4; git status --short | head
rm -rf build_bf && mkdir build_bf && cd build_bf
../configure --xlen=32 --tooldir=$HOME/tools > ~/runs/bf/configure.log 2>&1
grep -n "VORTEX_HOME\|XLEN ?=" config.mk | head -3
echo BF_SETUP_DONE
