#!/usr/bin/env bash
# Set up Tiny Tapeout tools on the build VM:
#   Icarus Verilog + cocotb for the tests,
#   tt-support-tools + LibreLane (run in Docker) for hardening.
set -euo pipefail
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  python3-pip python3-venv iverilog docker.io git librsvg2-bin pngquant
sudo usermod -aG docker "$USER" || true
# tt-support-tools needs Python >= 3.11; Ubuntu 22.04 ships 3.10, so use uv.
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
rm -rf "$HOME/ttenv"
uv venv -q --seed --python 3.11 "$HOME/ttenv"
# shellcheck disable=SC1091
. "$HOME/ttenv/bin/activate"
pip install -q --upgrade pip
pip install -q pytest==8.4.2 cocotb==2.1.0
if [ -d "$HOME/tt-support-tools/.git" ]; then
  git -C "$HOME/tt-support-tools" pull -q
else
  git clone -q https://github.com/TinyTapeout/tt-support-tools "$HOME/tt-support-tools"
fi
pip install -q -r "$HOME/tt-support-tools/requirements.txt"
pip install -q librelane==3.0.14
iverilog -V 2>&1 | head -1
python -c "import cocotb, librelane; print('cocotb', cocotb.__version__)"
echo "SETUP DONE"
