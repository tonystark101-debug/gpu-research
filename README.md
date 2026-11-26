# Open GPU research

We're a small team designing GPU and AI-accelerator hardware in the open. We start by beating the best open-source GPU, then climb from there.

## NVIDIA yardstick: our core vs one core of four NVIDIA chips (26 Nov 2026)

The same jobs, counted per clock tick for one core (on NVIDIA, one SM). We measured NVIDIA's T4, L4, A100 and H100 on rented cloud GPUs through PyTorch, which runs NVIDIA's own cuBLAS and attention kernels. Clock and power were sampled during every test. Our core is Vortex with our copy-engine fix, run in SimX.

| per core, per clock | Our core | T4 (2018) | L4 (2023) | A100 (2020) | H100 (2022) |
|---|---:|---:|---:|---:|---:|
| Maximum on paper (fp16) | 1,024 | 512 | 512 | 1,024 | 2,048 |
| Big matrix job, 8,192³ | not run | 452 (88%) | 482 (94%) | 968 (95%) | 1,889 (92%) |
| Small matrix job, 128×128×256 | **74** | 141 | 74 | 223 | 282 |
| Attention, 128 tokens | **0.12** | 116 | 101 | 245 | 278 |
| Small job, as a share of what memory can feed | — | 99% | 107% | 96% | 96% |

- **The yardstick is sound.** NVIDIA's chips reach 88–95% of their published maximum on big jobs.
- **Small jobs:** our core is level with an L4 core and 1.9× behind a T4 (Turing) core.
  - Every NVIDIA core runs this job at its memory's limit.
  - Our simulator gives one core 20–115× more memory speed per core than an NVIDIA SM gets, so this result flatters us.
- **Attention is our biggest gap: 800–2,300×.** Vortex's attention test runs 5.7 million ordinary instructions for 2.1 million multiply-adds.
- **Also measured:**
  - Number formats: fp8 does 1.8–1.9× the work of fp16.
  - Clocks under the power limit: the T4 drops to 43% of its top clock.
  - Work per watt: 0.36 TFLOPS/W on the T4 rising to 0.92 on the H100.
  - Our core's logic split: 57% general floating-point unit, 16% AI unit. This comes from Beacon on ASAP7, which predicts 840 MHz.

Write-up: [docs/nvidia-yardstick.md](docs/nvidia-yardstick.md). Script and data: [yardstick/](yardstick/). Results page: [results/nvidia-yardstick.html](results/nvidia-yardstick.html).

## Week 2 result: the fix is now in Vortex's chip design (Verilog), and the two models agree

- **Measured on the chip design itself.** In rtlsim, which runs Vortex's Verilog, the coalesced copy engine makes `sgemm_tcu_wg_dxa` **1.72× faster**: 13,877 → 8,054 cycles on 64×64×128, same answers.
- **Simulator and Verilog agree.** SimX and rtlsim agree within 1%, with identical write counts (2,048). Vortex's model-parity check passes.
- **Correctness, with the option on, on Vortex master:**
  - 38/38 dxa rtlsim cases pass;
  - 71/71 dxa + tensor_wg simx cases pass;
  - 7/7 new official test items pass;
  - 64-bit builds pass.
- **Cost when enabled:** +18.5% LUTs in the DXA unit (Beacon), with logic depth unchanged at 15 levels and estimated Fmax −5.5%. It is off by default.
- **Status:** offered upstream as [vortexgpgpu/vortex#506](https://github.com/vortexgpgpu/vortex/pull/506), now ready for review.

Write-up: [docs/week2-report.md](docs/week2-report.md).

## Week 1 result: 2× faster than open-source Vortex on its best AI matrix program (in simulation)

[Vortex](https://github.com/vortexgpgpu/vortex) is the leading open-source GPU (Georgia Tech, Apache-2.0). We profiled its fastest matrix-multiply program and made two changes:

1. **Copy engine: coalesced writes (the main win).** Vortex's bulk-copy engine (its version of NVIDIA Hopper's TMA) rearranged matrix B into the AI unit's layout one 2-byte number per clock. Its write path into local memory is 128 bytes wide. Our version writes every number that lands in the same 64-byte block in one byte-masked write, and fills both halves of a row in the same clock: 8 numbers per clock instead of 1.
2. **AI unit: fetch-ahead tile buffers.** The tensor unit's operand buffers get a second slot. While one slice is in use, the next slice of the same instruction loads at the lowest priority. Each prefetched slice is tagged with its instruction and is never used by a later one.

| Workload (1 core, 8 warps, fp16 in / fp32 out) | Vortex cycles | Ours | Speed-up |
|---|---:|---:|---:|
| Large tiles (NRC 32), 128×128×256 | 89,269 | 32,801 | **2.72×** |
| 16-wide warps, 128×128×256 | 185,924 | 91,412 | **2.03×** |
| Bigger matrix, 256×256×256 | 429,694 | 211,588 | **2.03×** |
| **Medium tiles (NRC 16), 128×128×256: Vortex's shipped config** | **108,524** | **54,077** | **2.01×** |
| A operand from registers, 128×128×256 | 108,081 | 54,250 | **1.99×** |
| No double-buffering, 128×128×256 | 109,360 | 56,551 | **1.93×** |
| Small tiles (NRC 8), 128×128×256 | 148,543 | 101,502 | **1.46×** |
| Sparse (2:4), 128×128×128 | 87,912 | 65,015 | **1.35×** |
| Multicast copy, 128×64×32 | 88,945 | 72,379 | **1.23×** |
| Ordinary-copy matrix (no copy engine), 128³ | 122,810 | 121,651 | 1.01× |
| Attention (no copy engine), N=128, D=64 | 17,078,890 | 17,075,621 | 1.00× |

- **Geometric mean over the 9 copy-engine workloads: 1.81×.**
- **Correctness:** every run passes Vortex's built-in result check. With both changes on, all 83 cases of Vortex's official simulator test lists pass: copy engine 40, warp-group tensor 28, tensor 15.
- **Why it was slow:** on the shipped config, the AI unit was busy 3.8% of the time. The copy engine made 73,728 separate local-memory writes, and its 8 request slots were full for 59,229 of 108,524 cycles. With the change: 16,384 writes, 30,302 blocked cycles, and the AI unit busy 7.6% of the time.

Full write-up: [docs/week1-report.md](docs/week1-report.md). Results page: [results/week1-results.html](results/week1-results.html).

**Offered upstream:** we offered the copy-engine fix to Vortex as a draft pull request: [vortexgpgpu/vortex#506](https://github.com/vortexgpgpu/vortex/pull/506). We retested it on Vortex's latest code (master `d6e0c68`), on its own and with the flag on:
- 1.91× on Vortex's shipped config.
- 1.71× on average over the 9 copy-engine workloads.
- 68 of 68 official dxa and tensor_wg simx cases pass.

Logs: [runs/upstream-pr/](runs/upstream-pr/).

### Honest caveats

1. **Simulator only, so far.** Both changes are in Vortex's cycle-level C++ simulator (SimX), not yet in its Verilog. Vortex's CI holds SimX to the Verilog's timing within a tolerance, so this is a strong signal, not proof. The Verilog version is next.
2. **Small scale:** 1 core, matrices up to 256×256×256.
3. **The AI unit is still idle about 92% of the time** on the headline program, so there's a lot more to win.
4. **Attention is unchanged**, because Vortex's attention program doesn't use the copy engine.

## Reproduce

Base: Vortex commit `f53bc480d2fa06a6f728ae78ba4b83cdd20a289e` (24 Nov 2026). Both changes sit behind compile flags, so with the flags off the simulator matches upstream exactly.

| Flag | Files | Change |
|---|---|---|
| `VX_CFG_DXA_SCATTER_COALESCE` | `sim/simx/dxa/dxa_core.cpp` | Coalesced, byte-masked scatter writes into local memory |
| `VX_CFG_TCU_TBUF_PREFETCH` | `sim/simx/tcu/tcu_tbuf.{h,cpp}`, `sim/simx/tcu/tcu_unit.cpp` | Second A/B tile-buffer slot, filled ahead at the lowest port priority (needs WGMMA) |

On Ubuntu 22.04 (we used 16 vCPUs):

```bash
git clone --recursive https://github.com/vortexgpgpu/vortex.git && cd vortex
git checkout f53bc480d2fa06a6f728ae78ba4b83cdd20a289e
git apply /path/to/patches/week1-vortex-f53bc48.patch
sudo ./ci/install_dependencies.sh
mkdir build && cd build && ../configure --xlen=32 --tooldir=$HOME/tools
./ci/toolchain_install.sh --all && make -s -j16

# Vortex's best GEMM (DXA double-buffered, fp16 WGMMA), as shipped:
B="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4 -DVX_CFG_EXT_TCU_ENABLE \
   -DVX_CFG_TCU_WGMMA_ENABLE -DVX_CFG_EXT_DXA_ENABLE -DITYPE=fp16 -DOTYPE=fp32 -DWGMMA_SS \
   -DDXA_DOUBLE_BUFFER -DWGMMA_NRC=16"
CONFIGS="$B" ./ci/blackbox.sh --driver=simx --app=sgemm_tcu_wg_dxa --perf=16 --args="-m128 -n128 -k256"
# ours:
CONFIGS="$B -DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_TCU_TBUF_PREFETCH" \
  ./ci/blackbox.sh --driver=simx --app=sgemm_tcu_wg_dxa --perf=16 --args="-m128 -n128 -k256"
```

- [scripts/](scripts/): every script we ran, including the scorecard (`perf_scorecard.sh`) and the official-test sweep (`correctness_sweep.py`).
- [runs/week1/](runs/week1/): the raw logs and summary tables behind every number above.

## Our first chips (Tiny Tapeout)

Our first chip is a mini tensor core. It computes C += A × B on 4×4 int8 matrices with int32 totals, using four multipliers as one 4-wide dot-product unit.

- **Where:** the Tiny Tapeout SkyWater 130 nm shuttle (TTSKY26e, closes 30 Nov 2026).
- **Size and checks:** 6 tiles. Zero layout-rule (DRC) errors and zero layout-vs-netlist (LVS) errors. All 6 tests pass on the final gate-level netlist.
- **Speed:** meets 50 MHz at typical conditions, with 7.7 ns of slack. At the hot, low-voltage corner it reaches about 45 MHz.
- **180 nm version:** a GlobalFoundries 180 nm version also passes every check. The 7 Dec shuttle is full, so it waits for a free slot.

Each design lives in its own repository, as Tiny Tapeout requires: [tt-minitensor-sky130](https://github.com/tonystark101-debug/tt-minitensor-sky130).

## Next

1. **Attention:** profile Vortex's attention program and fix its biggest bottleneck.
2. **Realistic memory:** re-test our core with a real chip's per-core share of memory.
3. **Area and power:** a full layout run of the core.
4. **First FPGA run**, for real clock speed and power.

## License and credits

Apache License 2.0 (see [LICENSE](LICENSE)). Our patch modifies files of Vortex GPGPU, which is also Apache-2.0; see [NOTICE](NOTICE). Thanks to the Vortex team at Georgia Tech for an open GPU this good to build on.
