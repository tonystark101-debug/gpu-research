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

**Chip size and power** (full synthesis with Vortex's open-source flow: Yosys + OpenSTA on the ASAP7 academic 7 nm-class library; section 5):
- **Size: 1.65 mm²** before layout: 1.53 mm² of logic plus 0.11 mm² of memory blocks. About 2.3 mm² once placed.
- **Top speed: 875 MHz.** It misses 1 GHz by 0.14 ns, close to Beacon's 840 MHz prediction.
- **Power: about 2.1–2.9 W at 1 GHz** for realistic switching activity (2–10%), or 3.8 W at 20%. About 2 W of that is clocking **1.81 million flip-flops** every tick whether they're busy or not: this flow adds no clock gating.
  - Vortex's default power method gives 18 W. That method lets switching activity multiply through the arithmetic to about 2 toggles per wire per tick, which is unrealistic.
- **Work per watt on the small matrix job: roughly 5–20× behind a Jetson core** (about 10× in the middle). This is an estimate: our core's power is pre-layout, and the Jetson's per-core power is derived from measured board power.
- **Where the watts and area go points to the next design levers:**
  - clock gating;
  - register files in dense memory instead of flip-flops (34% of the logic area);
  - a smaller general maths unit (57% of the logic, nearly idle in AI jobs);
  - the deeper copy engine.

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

## 5. Size and power (synthesis, 27 Nov)

The same core (32 threads × 8 warps, issue width 4, AI unit with WGMMA, copy engine with our coalescing, hardware exp unit, fp16 conversions). It went through Vortex's own open-source flow, the one behind its `asic_gate` check: Yosys maps the design to ASAP7 RVT standard cells at the typical corner, and OpenSTA reports timing and power. The target was 1 GHz. It ran for 7.2 hours and peaked at 59 GB of memory. We switched off Yosys's SAT-based sharing pass; with it, synthesis was projected at about 15 hours. Without it the area may read a few percent high.

| | result |
|---|---|
| Standard cells | 14.75 million, **1.535 mm²** |
| of which flip-flops | **1.81 million**, 0.528 mm² (34%): the register files and pipeline buffers are built from flip-flops |
| Memory blocks (64 RAMs, estimated) | 0.111 mm² |
| **Total before layout** | **1.65 mm²** (about 2.3 mm² placed at 70% density) |
| Top speed | **875 MHz** (worst path misses 1 GHz by 0.143 ns) |
| Where the logic goes (Beacon, same design) | general maths (FPU) 57%, AI unit 16%, issue 10%, integer 8%, load/store 5%, other 4% |

**Power at 1 GHz**, with every wire switching at the given rate. This is pre-layout, so there is no clock tree and no wiring, and the memory blocks aren't counted.

| switching activity (toggles per wire per tick) | 2% | 5% | 10% | 20% |
|---|---:|---:|---:|---:|
| total | 2.13 W | 2.48 W | 2.85 W | 3.78 W |
| flip-flops (clocked every tick) | 2.01 W | 2.18 W | 2.26 W | 2.58 W |
| other logic (and the remainder) | 0.12 W | 0.30 W | 0.59 W | 1.20 W |

- **Vortex's default (vectorless) method gives 18.0 W**: 3.15 W in flip-flops and 14.9 W in logic.
  - It propagates switching probabilities through the logic. In the multiplier and adder trees, that compounds to about 2 toggles per wire per tick, far above what a real workload produces, so it isn't used here.
  - Vortex's own baseline core reports power the same way (1.0 W for its small 8 × 8 core), so the method is consistent; it just assumes a busy chip.
- **Leakage** is about 1 mW in this library model.
- **Most of the power is clocking idle storage.** At realistic activity, 80–94% of the power is the 1.81 million flip-flops being clocked every tick. Real GPUs switch off the clock to idle units (clock gating), which this open flow doesn't add. That is our biggest power lever.
- **A realistic band** for our core, adding a clock tree and the memory blocks: about **2.5–4 W at 875 MHz–1 GHz**.
- **Not done:** power from recorded switching activity. We ran the matrix job in the Verilog model with activity recording on. The run passed (93,007 ticks, within 0.4% of the other two models), but the activity file came out empty. Finding why is a follow-up.

**Work per watt on the small matrix job (Jetson memory, copy engine 64 deep):**

| | work per tick | clock | power | GFLOPS per watt |
|---|---:|---:|---:|---:|
| our core, standard setting | 44.9 | 875 MHz | 2.5–4 W | 20–31 |
| our core, best setting | 69.8 | 875 MHz | 2.5–4 W | 31–49 |
| a Jetson core (estimate) | about 223 | 1,020 MHz | about 1.1–1.9 W | 240–410 |

The Jetson core's power is derived:
- The Orin Nano Super's measured board power under AI load is 18–22 W in its uncapped mode (published llama.cpp measurements).
- We assume 50–70% of that goes to the GPU, split 8 ways.
- Its work per tick is the A100 core's on our yardstick.

So we are **roughly 5–20× behind on work per watt**, about 10× in the middle. That holds even though the comparison flatters us: our core sits on a newer-class process (7 nm-class vs Samsung 8 nm) and excludes the shared cache and memory controllers.

**What this says about our own core (plan step 4):**
1. **Clock gating** idle units: most of today's power.
2. **Register files in dense memory blocks** instead of flip-flops: a third of the logic area, and much of the clock load.
3. **A smaller general maths unit:** 57% of the logic, nearly idle in AI work.
4. **A deeper copy engine:** 2.9× on realistic memory, about 1% more storage cells.

## 6. Caveats

- Simulation, not silicon. One core with one eighth of the memory, not 8 cores sharing it.
- Our matrix job is one product per core; NVIDIA's batched benchmark runs 16 per core and overlaps their memory traffic.
- The 400-tick memory delay is an estimate (section 3 shows it doesn't change the picture).
- The deeper copy engine was checked in the Verilog model on the standard setting only (section 2's best setting and medium job are simulator results).

## Files

- `../runs/battlefield/results.tsv`: every run (cycles, instructions, pass/fail, worst error).
- `../runs/battlefield/numbers.json`: multiply-adds per tick for every run.
- `../runs/battlefield/jetson_orin_nano_core.json`: the memory profile, with its sources.
- `../runs/battlefield/calib_*.out`, `defmem.out`: the latency calibration and the default-memory measurement.
- `../runs/battlefield/synth/`: synthesis area (`stat_lib.rpt`), memory-block area (`sram_area.rpt`), timing (`setup.rpt`, `worst_slack.rpt`), vectorless power (`power.rpt`), power at 2–20% activity (`power_range.log`), the synthesis log, and the activity-recording run log.
- Scripts: `../scripts/bf_*.sh`.
