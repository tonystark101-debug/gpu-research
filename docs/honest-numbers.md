# Honest numbers: our core on a Jetson core's share of memory (27 Nov 2026)

**Bottom line:** the yardstick's small-job result was flattered by the simulator's memory.
- With the memory a Jetson Orin Nano core really gets, our core's matrix jobs run **about 5× slower**: 74 → 16 multiply-adds per clock tick on the standard setting, 122 → 23 on the best one.
- The cause is one setting: our copy engine keeps only 8 memory reads in flight. Real memory takes about 400 ticks to answer, so 8 reads in flight can't use the bandwidth.
- With 64 in flight, the matrix jobs recover to **45 (standard) and 70 (best)**. That is an existing setting in Vortex's design (simulator and Verilog), and it adds about 1% to the core's storage cells.
- **The Verilog chip model agrees:**
  - 264,625 ticks with 8 in flight, against the simulator's 267,244 (within 1.0%);
  - 92,951 ticks with 64 in flight, against 93,365 (within 0.4%).
  - So the slowdown and the 2.85× recovery are real chip behaviour, not a simulator artefact.
- Attention changes little (1.3× slower), because its time goes to arithmetic, not to waiting for memory.
- Against a Jetson core, estimated from the A100 core we measured, we are now about **3–5× behind on small matrix jobs** (with the deeper copy engine) and about **15–40× behind on attention**.

**Chip size and power:** in progress. A full synthesis of this core with Vortex's open-source flow (Yosys + OpenSTA, the ASAP7 academic 7 nm-class library) is running. This report will be updated with square millimetres, watts and work per watt.

## 1. What "realistic memory" means here

| | the yardstick's simulator memory | a Jetson Orin Nano core's share (this report) |
|---|---|---|
| Data per clock tick | 128 bytes (2 channels × one 64-byte block per tick) | **12.5 bytes** (102.4 GB/s ÷ 8 cores, at 1,020 MHz) |
| Delay for a load that misses every cache | **90 ticks** (measured, cold pointer chase) | **400 ticks** (measured in the simulator, calibrated) |
| Delay for a load that hits the shared cache | no shared cache | **200 ticks** (calibrated) |
| Shared cache (L2) per core | none | 256 KB |
| Where the job's data starts | memory | memory (uploads skip the cache) |

So the yardstick's simulator gave our core about **10× the bandwidth per tick of a Jetson core, answering about 4–5× sooner**. The yardstick report put this at "20–115×" by comparing a nominal 460 GB/s label with NVIDIA's per-core bandwidth. That label is not what the simulator models; the per-tick figures above replace it. The earlier "36×" in our plan used the same label and is also replaced.

How the Jetson share was set up:
- One memory channel per core: an x16 channel at 6,400 MT/s, which is 12.8 GB/s, an eighth of the Orin Nano Super's 128-bit LPDDR5. Vortex has no LPDDR5 model, so the channel uses its GDDR6 model at the same data rate, as Vortex's own profiles do for other memory types.
- The clock is 1,020 MHz, the Orin Nano Super's top GPU clock, so 12.8 GB/s is 12.5 bytes per tick.
- The delays were calibrated with Vortex's own latency check (ci/profile_check.py): measured 12.55 bytes per tick, a 200-tick cache hit and a 400-tick memory load, all within 0.4%.
- The 200-tick cache delay matches Vortex's calibrated Ampere (A100, 200) and Turing (T4, 188) profiles. The 400-tick memory delay is our estimate for LPDDR5 at 1 GHz. No pointer-chase measurement on any Orin has been published (research, 27 Nov), and the two published A100 measurements disagree: 290 and 566 ticks. Section 3 runs 300 and 600 ticks, which covers both.

## 2. Results (SimX, Vortex master 2221ee2 + our copy-engine fix + our attention fix)

Multiply-adds per clock tick, one core (32 threads × 8 warps, issue width 4). Every run passes its own correctness check.

| job | simulator memory (yardstick) | Jetson share | Jetson share, copy engine 64 deep |
|---|---:|---:|---:|
| Small matrix job, 128 × 128 × 256, standard setting | 73.9 | **15.7** (4.7× slower) | **44.9** |
| Small matrix job, best setting (wider AI-unit steps) | 122.4 | **23.2** (5.3× slower) | **69.8** |
| Medium matrix job, 256³ | 74.8 | **16.3** (4.6× slower) | **46.5** |
| Attention, 128 tokens | 8.5 | **6.3** (1.35× slower) | (no copy engine in this test) |
| Attention, 256 tokens | 9.3 | **7.3** (1.27× slower) | |
| Attention, 128 tokens, 16-thread setup (the yardstick's 3.6) | 3.6 | 2.6 | |

Copy engine depth, small matrix job on the Jetson share:

| reads in flight | 8 (Vortex default) | 32 | 64 | 128 |
|---|---:|---:|---:|---:|
| standard setting | 15.7 | 39.4 | 44.9 | 44.9 |
| best setting | 23.2 | 63.0 | 69.8 | 69.8 |
| medium job (256³) | 16.3 | 40.6 | 46.5 | 46.5 |

- Above 64 nothing changes, and doubling the cache's miss slots or the copy engine's queue doesn't either. The next limit is somewhere else; finding it is a later step.
- On the simulator's fast memory the same change gives 73.9 → 75.0. That is why it didn't show up before (week 2 found "no gain" from a wider window, on the fast memory).
- Why 8 is too few (Little's law): 8 reads × 64 bytes ÷ 400 ticks = 1.3 bytes per tick, a tenth of the 12.5 available. Using all of it needs about 80 reads in flight.

The attention numbers also correct the yardstick's: the yardstick used a 16-thread setup for attention (3.6 per tick). On the same 32-thread core as the matrix jobs, attention runs at 8.5 per tick on the simulator's memory and 6.3 on the Jetson share.

## 3. Sensitivity to the memory delay

| memory delay (ticks) | 300 | 400 | 600 |
|---|---:|---:|---:|
| Small matrix job, standard setting, copy engine 8 deep | 17.4 | 15.7 | 13.1 |
| Attention, 128 tokens | 6.6 | 6.3 | 5.8 |

The conclusions don't depend on the exact delay.

## 4. Against a Jetson core

We have no Jetson measurement yet. The nearest measured NVIDIA core is the A100's: on paper it does the same AI maths per tick as an Orin core (1,024 fp16 multiply-adds), and in our yardstick its small-job number was set by its memory (9.1 bytes per tick, below the Jetson core's 12.5).

| per core, per tick | our core, Jetson share | our core, Jetson share, copy engine 64 deep | NVIDIA, measured on the yardstick |
|---|---:|---:|---|
| Small matrix job | 15.7–23.2 | 44.9–69.8 | A100 core 223, T4 core 141, L4 core 74 |
| Attention, 128 tokens | 6.3 | — | A100 core 245, T4 core 116, L4 core 101 |

- **Small matrix jobs:** a Jetson core should land around the A100 core's 223, so we are about **10–14× behind as shipped and about 3–5× behind with the deeper copy engine**.
- **Attention:** about **15–40× behind** (T4 to A100 cores), down from 28–78× in the yardstick's 16-thread comparison, though the memory is now realistic.
- These Jetson figures are estimates. A Jetson Orin Nano Super ($249) would let us measure them the way we measured the other four chips.

## 5. Caveats

- Simulation, not silicon. One core with one eighth of the memory, not 8 cores sharing it.
- Our matrix job is one product per core; NVIDIA's batched benchmark runs 16 per core and overlaps their memory traffic.
- The 400-tick memory delay is an estimate (section 3 shows it doesn't change the picture).
- The deeper copy engine was checked in the Verilog model on the standard setting only (section 2's best setting and medium job are simulator results).

## Files

- `../runs/battlefield/results.tsv`: every run (cycles, instructions, pass/fail, worst error).
- `../runs/battlefield/numbers.json`: multiply-adds per tick for every run.
- `../runs/battlefield/jetson_orin_nano_core.json`: the memory profile, with its sources.
- `../runs/battlefield/calib_*.out`, `defmem.out`: the latency calibration and the default-memory measurement.
- Scripts: `../scripts/bf_*.sh`.
