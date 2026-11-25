#!/bin/bash
# Day 1: install Vortex GPU (v3.0) and run its smoke test. Logs to ~/setup.log
set -x
cd ~
echo "START $(date -u)" > ~/setup.status
if [ ! -d vortex ]; then
  git clone --depth=1 --recursive https://github.com/vortexgpgpu/vortex.git || { echo "FAIL clone" >> ~/setup.status; exit 1; }
fi
cd vortex
git log -1 --format='%H %cd' >> ~/setup.status
sudo DEBIAN_FRONTEND=noninteractive ./ci/install_dependencies.sh || { echo "FAIL deps" >> ~/setup.status; exit 1; }
echo "deps ok $(date -u)" >> ~/setup.status
mkdir -p build && cd build
../configure --xlen=32 --tooldir=$HOME/tools || { echo "FAIL configure" >> ~/setup.status; exit 1; }
./ci/toolchain_install.sh --all || { echo "FAIL toolchain" >> ~/setup.status; exit 1; }
echo "toolchain ok $(date -u)" >> ~/setup.status
source ./ci/toolchain_env.sh 2>/dev/null || true
make -s -j16 || { echo "FAIL build" >> ~/setup.status; exit 1; }
echo "build ok $(date -u)" >> ~/setup.status
./ci/blackbox.sh --cores=2 --app=vecadd && echo "SMOKE simx ok" >> ~/setup.status || echo "FAIL smoke simx" >> ~/setup.status
echo "DONE $(date -u)" >> ~/setup.status
