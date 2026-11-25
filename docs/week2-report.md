# Week 2 report: the copy-engine fix, now in Vortex's chip design (Verilog)

*25 November 2026 · offered upstream as [vortexgpgpu/vortex#506](https://github.com/vortexgpgpu/vortex/pull/506)*

## The short version

1. **The fix now exists in the actual chip design, not just the simulator.** In Vortex's chip-design simulator (rtlsim, which runs the Verilog), our version of the copy engine makes the AI matrix program **1.72× faster**: 13,877 → 8,054 clock cycles on a 64×64×128 test, same answers.
2. **The simulator model and the chip design agree within about 1%**, and their write counts match exactly (2,048 = 2,048). Vortex requires this ("model parity"). Its official parity check passes.
3. **The cost when switched on:** the copy engine grows about 18% (10,686 → 12,668 logic blocks, from Vortex's "Beacon" estimator). Its longest logic path stays at 15 levels, the same as today. Estimated top speed drops about 5% (298.6 → 282.3 MHz against a 300 MHz target), so a tuning pass is still due. The switch is off by default, so Vortex's normal chip is untouched.
4. **Correctness:** with the switch on, every test in Vortex's official lists passes. That's 38 of 38 chip-design tests for the copy engine and 71 of 71 simulator tests for the copy engine and AI unit. It also covers the 7 new official test items (including the model-vs-chip-design match check) and 3 checks of the 64-bit version.
5. **Two week-2 items turned out not to be worth doing yet.** Both are backed by measurements:
   - **A bigger copy engine:** letting it keep more requests in flight gains nothing on its own (108,524 → 108,159 cycles), and only about 1.4% on top of our fix. The bottleneck has moved elsewhere.
   - **Our own attention program:** another contributor's open proposal (#502) adds one ("FlashAttention-4"). It moves data in plain rows, which already write a full row per clock, so our fix isn't needed there.
6. **FPGA:** not possible this week. It needs an AMD/Xilinx Alveo board or Amazon F2 cloud-FPGA access, and we don't have either yet.

## What we built

### Chip design (Verilog: `hw/rtl/dxa/VX_dxa_smem_wr.sv`)
The copy engine's last stage writes into the GPU's local memory, one 128-byte row ("word") per clock. When it rearranges matrix B into the AI unit's layout, it used to write **one 2-byte number per clock**. Now, with the switch on, each clock writes **every number that lands in the same row**.

How the circuit does it:
- **Spread:** the numbers sit side by side in the incoming 64-byte chunk. A small network spaces them out to the layout's fixed spacing, which is always a power of two (16 bytes for fp16 on a 32-thread core).
- **Shift:** a shifter then moves the group to where the first number belongs in the row.
- **Byte mask:** marks which bytes of the row are real data.

**The first version was too slow for a real chip.** It worked out "how many numbers fit in this row" from scratch every clock. That doubled the copy engine's longest logic path (15 → 30 levels), which would cap the clock about 9% below target.

**The fix: compute that count once per chunk.** The layout is regular:
- **BlockMajor:** after a chunk's first row, every row holds exactly row-size ÷ spacing numbers.
- **Flat (sparse):** each run is one "n-block" of tcN numbers.

So each step's size is just "the smaller of what's left and a stored limit". The longest path is back to 15 levels.

### Simulator (`sim/simx/dxa/dxa_core.cpp`)
The simulator now follows exactly the same rule as the hardware:
- BlockMajor runs end at the row.
- Flat runs end at the n-block.
- K-major (a third layout) keeps one number per clock, because its spacing isn't always a power of two.

### Switch and tests
- **`VX_config.toml`:** declares `VX_CFG_DXA_SCATTER_COALESCE = false` (off by default).
- **`ci/testcases/dxa.yaml`:** 3 new functional tests (dense, sparse, multicast), each on both simulator and chip design, plus 1 new parity test.

## Results

### Chip design vs simulator (32 threads, 8 warps, fp16, 64×64×128)

| | Simulator cycles | Chip-design cycles | Gap | Writes (both) |
|---|---:|---:|---:|---:|
| Vortex as shipped | 13,990 | 13,877 | 0.8% | 9,216 |
| With our fix | 8,137 | 8,054 | 1.0% | 2,048 |

### Copy-engine slots vs our fix (simulator, Vortex's best program, 128×128×256)

| Requests in flight | Without fix | With fix |
|---|---:|---:|
| 8 (shipped) | 108,524 | 56,743 |
| 16 | 108,129 | 56,164 |
| 32 | 108,159 | 55,950 |
| 64 | 108,159 | 55,950 |

**Reading:** the slots were full only because each write was slow. Extra slots don't help until the writes are fixed, and even then they add only about 1.4%.

### Cost (Vortex's Beacon estimator, copy-engine unit, 16 threads × 16 warps, switch on vs off)

| | Vortex master | With our fix |
|---|---:|---:|
| Longest logic path (levels) | 15 | 15 |
| Logic (LUTs) | 10,686 | 12,668 (+18.5%) |
| Flip-flops | 9,328 | 9,364 |
| Estimated top clock | 298.6 MHz | 282.3 MHz |

Our first version scored 30 levels and 274 MHz. The restructure brought it back to 15 levels.

## Verification

All runs use the switch on, on Vortex's latest code (master `d6e0c68`):

| What | Result |
|---|---|
| Every copy-engine test on the chip-design simulator (rtlsim, 32-bit) | 38 / 38 pass |
| Every copy-engine + AI-unit test on the simulator (simx) | 71 / 71 pass |
| New official tests: dense, sparse and multicast, on both simulators | 6 / 6 pass |
| New official model-vs-chip-design match check | pass (gap about 1%) |
| 64-bit build: plain copy (rtlsim), multicast (simx + rtlsim) | 3 / 3 pass |
| 9-workload simulator scorecard | all pass; identical to last week's numbers (1.71× average) |

**Two false alarms on the way, both from the build machine:**
- One test hit a compiler crash. It passes with the compiler cache off, which Vortex's own rulebook warns about.
- One scorecard run crashed on a copy with leftover week-1 builds. It passes on a clean copy.

## What's next (week 3)

1. **Tune the circuit back to full speed.** The write data now passes through about 14 logic levels where it used to pass through 6. Pipelining it, or splitting the shifter, should recover the 5% clock loss.
2. **Follow up on the Vortex review (#506).** Done this week: it now includes the chip-design change, these numbers, and is marked ready for review.
3. **Find the next bottleneck.** After this fix the copy engine is no longer the limit, and the AI unit is still mostly idle. Profile the tensor unit and the warp scheduling.
4. **FPGA**, once there's an Alveo board or AWS F2 access.

## Reproduce

Apply [patches/week2-vortex-d6e0c68.patch](../patches/week2-vortex-d6e0c68.patch) on Vortex master `d6e0c68`, then build as in the [README](../README.md). The scripts are in [scripts/](../scripts/) (`week2_rtl.sh`, `week2_inflight.sh`, `week2_verify2.sh`, `week2_x64.sh`), and the logs in [runs/week2/](../runs/week2/).
