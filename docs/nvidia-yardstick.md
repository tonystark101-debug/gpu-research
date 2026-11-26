# The NVIDIA yardstick (26 Nov 2026)

**Bottom line:** we measured our core against one core of four real NVIDIA chips (T4, L4, A100, H100), on the same jobs, counted per clock tick.
- On small maths jobs we are **level with an L4 core** and **1.9× behind a T4 core** (Turing, the generation our plan targets).
- On **attention**, the heart of AI chat models, we are **800–2,300× behind**. That is the biggest hole, so it is the next thing to work on.
- A new finding: on small jobs, **every NVIDIA core runs right at its memory's speed limit** (96–107%). Small jobs are a memory race, which supports our data-movement bet.

Results page: [results/nvidia-yardstick.html](../results/nvidia-yardstick.html) (download and open in a browser). Data: [yardstick/summary.json](../yardstick/summary.json), built by [yardstick/build_summary.py](../yardstick/build_summary.py) from [yardstick/raw/](../yardstick/raw/).

## 1. How we measured

- **The unit:** multiply-adds per clock tick, for one core. A core is the repeated building block of a GPU; NVIDIA calls it an SM. Dividing by the clock and the core count makes a 2018 chip, a 2023 chip and our simulated core comparable.
- **NVIDIA side:** `yardstick/nv_bench.py`, run on rented cloud GPUs on 26 Nov 2026 (Amazon: T4; Google: L4, A100, H100).
  - It runs through PyTorch 2.9 to 2.12, which calls NVIDIA's own maths libraries (cuBLAS) and attention code. These are out-of-the-box kernels, not hand-tuned ones.
  - Every test runs for at least 1.5 seconds and is timed with GPU events.
  - The SM clock and board power are sampled every 50 ms during each test (NVML). The per-clock numbers use the measured clock, not the brochure clock.
- **Our side:** Vortex in its cycle simulator (SimX).
  - Configuration: 32 threads × 8 warps, issue width 4, AI unit (TCU with WGMMA) and copy engine (DXA) on, plus our coalescing fix (PR #506, also in Verilog).
  - Numbers come from the week 1 and week 2 runs ([runs/week1](../runs/week1), [runs/week2](../runs/week2), [runs/upstream-pr](../runs/upstream-pr)).
  - Size and top speed come from Vortex's Beacon estimator on the ASAP7 academic 7 nm-class model: `logic_gate.py -b core --tool beacon_asic` with the configuration above. The reports are in [yardstick/raw/vortex/](../yardstick/raw/vortex/).
- **Maximums ("peak"):** NVIDIA's published dense figures, with no sparsity. Ours is 1,024 multiply-adds per clock for this configuration (week 1).

## 2. Results

### Matrix maths: big jobs near the maximum, small jobs far below (fp16)

| per core, per clock | Our core | T4 (2018) | L4 (2023) | A100 (2020) | H100 (2022) |
|---|---:|---:|---:|---:|---:|
| Maximum on paper | 1,024 | 512 | 512 | 1,024 | 2,048 |
| Big job, 8,192³ | not run | 452 (88%) | 482 (94%) | 968 (95%) | 1,889 (92%) |
| Medium job, 256³ (batched) | 75 (7%) | 271 (53%) | 148 (29%) | 329 (32%) | 542 (26%) |
| Small job, 128 × 128 × 256 (batched) | **74 (7%)** | 141 (28%) | 74 (14%) | 223 (22%) | 282 (14%) |

- Our core was at 39 before our fix. A further simulator-only buffer prefetch (week 1) gives 78.
- On NVIDIA, the "small job" runs one 128 × 128 × 256 product per thread block, with enough copies to fill every core (16 per core). That is the same job one Vortex core runs. A single unbatched small product leaves most of an NVIDIA chip idle (1.4–4.5 per core per clock).
- We can't simulate big jobs yet: 8,192³ would take billions of simulated cycles.

### Memory: small jobs run at the memory's limit

| | T4 | L4 | A100 | H100 |
|---|---:|---:|---:|---:|
| Copy speed, whole chip (GB/s, measured) | 231 | 231 | 1,379 | 3,013 |
| Per core (GB/s) | 5.8 | 4.0 | 12.8 | 22.8 |
| Bytes per core per clock, at the small job's clock | 5.6 | 2.7 | 9.1 | 11.5 |
| Most the memory can feed on the small job (multiply-adds per clock) | 143 | 68 | 232 | 295 |
| What the core actually did | 141 | 74 | 223 | 282 |
| Share of the memory limit | **99%** | **107%** | **96%** | **96%** |

How the limit is worked out: the small job moves 160 KB (A and B in, C out, all 16-bit) for 4.19 million multiply-adds, so 25.6 multiply-adds per byte. The limit is bytes per core per clock × 25.6. The batch is far bigger than each chip's cache, so the data really comes from memory. The L4 goes slightly past its limit because its 48 MB cache holds part of the data.

**What this means for us:** our simulator's memory is set to 460 GB/s (two 64-byte HBM2 channels) for one core. That is 20–115× more per core than an NVIDIA core gets. Our small-job number is therefore not memory-limited and is flattered. The fair next test is our core on a realistic per-core share of memory.

### Attention (fp16, head size 64 unless noted)

| per core, per clock | Our core | T4 | L4 | A100 | H100 |
|---|---:|---:|---:|---:|---:|
| Short text: 128 tokens, our test size | **0.12** | 116 | 101 | 245 | 278 |
| Medium: 1,024 tokens | not run | 146 | 381 | 512 | 883 |
| Long: 4,096 tokens | not run | 155 | 406 | 613 | 1,137 |
| Long: 4,096 tokens, head size 128 | not run | 145 | 405 | 658 | 1,460 |

- Our number comes from Vortex's `flash_attn_tcu_wg` test with the 16-thread setup: 17.1 million cycles for 2.1 million multiply-adds. The 32-thread setup was run on 256 tokens, not 128: 33.8 million cycles for 8.4 million multiply-adds, or 0.25 per clock. (An earlier version of this report wrongly listed it as 0.06 on 128 tokens.)
- The test runs 5.7 million ordinary instructions for its 2.1 million multiply-adds, so the AI unit sits idle almost all the time.
- Our copy-engine fix doesn't help here: this test stages its data in software, without the copy engine.
- **Update, 26 Nov:** we found and fixed the cause ([attention-report.md](attention-report.md)). 96% of the time was softmax: `expf` ran in software double precision. With the fix, the same 128-token run is 29× faster, at 3.6 multiply-adds per clock with the TFU. The gap to NVIDIA at this size becomes 28–78×. Vortex's own upcoming FA4 kernel (PR #495, unmerged) reaches 26–31.
- Counting: attention multiply-adds = 2 × batch × heads × tokens² × head size. Softmax isn't counted, the same way for both sides.

### Number formats (big job, 4,096³; share of each chip's maximum in brackets)

| format | T4 | L4 | A100 | H100 |
|---|---:|---:|---:|---:|
| fp32, general cores (no AI unit) | 62 (96%) | 93 (73%) | 62 (98%) | 99 (77%) |
| tf32, AI unit | — | 245 (96%) | 447 (87%) | 888 (87%) |
| fp16, AI unit | 449 (88%) | 476 (93%) | 894 (87%) | 1,851 (90%) |
| bf16, AI unit | — | 475 (93%) | 888 (87%) | 1,860 (91%) |
| fp8, AI unit | — | 893 (87%) | — | 3,321 (81%) |
| int8, AI unit | 215 (21%) | 245 (24%) | 236 (12%) | 248 (6%) |

- "—" means the chip has no hardware for that format.
- The AI unit is 5–19× faster than the general cores.
- fp8 gives 1.8–1.9× the work of fp16 per clock.
- **int8 is a software result, not a hardware one.** It comes out almost the same on all four chips (215–248), whatever their hardware can do. The PyTorch route we used (`torch._int_mm`) is the bottleneck, so don't quote these as chip speeds.

### Clock and power during the big job

| | T4 | L4 | A100 | H100 | Our core |
|---|---:|---:|---:|---:|---:|
| Top clock (MHz) | 1,590 | 2,040 | 1,410 | 1,980 | 840 (predicted) |
| Clock during the big job (MHz) | 689 (43%) | 979 (48%) | 1,251 (89%) | 1,294 (65%) | — |
| Board power during the big job (W) | 69 of 70 | 72 of 72 | 399 of 400 | 698 of 700 | — |
| TFLOPS per watt | 0.36 | 0.76 | 0.66 | 0.92 | not known |

- Every chip sat at its power limit and slowed its clock to stay there. Power, not top clock, sets the speed under heavy load.
- Work per watt rose 2.6× from the T4 (2018, 12 nm) to the H100 (2022, 5 nm class).
- Our 840 MHz is Beacon's advisory estimate on ASAP7, an academic model, not a real factory process. Its slowest path is in Vortex's own tensor-buffer address logic (`tcu_shared/wgmma/tbuf/bbuf`: a multiply feeding a 40-level chain), not in our change.

### Size

Our core (Beacon, ASAP7): 3,328,530 logic cells, 502,717 flip-flops and 16 memory blocks (the local scratchpad). Beacon's "cells" are its own abstract logic units, not real standard cells, so they can't be turned into square millimetres or transistors.

| part of our core | logic cells | share |
|---|---:|---:|
| General floating-point unit (FPU) | 1,891,766 | 57% |
| AI (tensor) unit, incl. shared WGMMA | 529,703 | 16% |
| Instruction issue (incl. register files, built from flip-flops) | 324,148 | 10% |
| Integer unit (ALU) | 282,830 | 8% |
| Load / store | 154,602 | 5% |
| Other (local memory control, special functions, scheduler, front end) | 145,481 | 4% |

NVIDIA, whole chip ÷ full core count (published die figures; includes caches, memory controllers and I/O):

| | T4 (TU104) | L4 (AD104) | A100 (GA100) | H100 (GH100) |
|---|---:|---:|---:|---:|
| Die area | 545 mm² | 294.5 mm² | 826 mm² | 814 mm² |
| Transistors | 13.6 B | 35.8 B | 54.2 B | 80 B |
| Cores on the full die | 48 | 60 | 128 | 144 |
| Area per core | 11.4 mm² | 4.9 mm² | 6.5 mm² | 5.7 mm² |
| Transistors per core | 283 M | 597 M | 423 M | 556 M |
| Process | TSMC 12 nm | TSMC 4N | TSMC 7 nm | TSMC 4N |

## 3. What this tells us

1. **The yardstick is sound.** NVIDIA's chips reach 88–95% of their published maximum on big jobs, so the measuring method works.
2. **Against a Turing core (our plan's step D target):** 1.9× behind on small jobs, 3.6× on medium ones, and about 940× on attention.
3. **Small jobs are a memory race for everyone.** Feeding data matters more than adding maths units. This fits our data-movement bet, but it also means our simulator's generous memory flatters us.
4. **Power is the real limit.** Work per watt is the number to design for, not top clock.
5. **Our core is mostly general-purpose maths.** 57% of the logic is the FPU and 16% is the AI unit. An AI-first core would shift that balance.

## 4. Next, in this order

1. **Attention** (about 1–2 days): profile where `flash_attn_tcu_wg`'s 17 million cycles go, then fix the biggest piece.
2. **Realistic memory** (about half a day): re-run our core's matrix jobs with a real chip's per-core share of memory (bandwidth and delay), so the small-job comparison is fair.
3. **Size and power** (about 1–2 days of cloud computing): a full layout run of the core on ASAP7 with open tools, for square millimetres and watts. It may need a bigger machine than our 16-core build machine.
4. After that, as planned: one graphics frame, then lock the battlefield.

## 5. Caveats

- Each NVIDIA test ran once, for at least 1.5 seconds, so run-to-run spread wasn't measured. The four chips agree well with their specifications, which suggests it's small.
- NVIDIA's numbers use out-of-the-box PyTorch kernels. Hand-tuned kernels could be faster, especially for the batched small jobs and for int8.
- The T4 and L4 are 70 W cards, and their clocks drop hard under load. Per-clock numbers already take this into account; per-second numbers would not.
- Our numbers are from a cycle simulator, not silicon. Its memory model is more generous than a real chip's, and big jobs are too slow to simulate.
- Beacon's 840 MHz and cell counts are early estimates on an academic process model.

## Files

- `yardstick/nv_bench.py`: the NVIDIA benchmark.
- To rerun on any NVIDIA GPU: `pip install torch nvidia-ml-py`, then `python yardstick/nv_bench.py out.json` (a few minutes per chip).
- `yardstick/raw/{t4,l4,a100,h100}_results.json`: raw NVIDIA results.
- `yardstick/raw/vortex/`: Beacon reports for our core (`area.txt`, `area_memories.csv`, `report.txt`, `beacon_asic_core.txt`). The 12 MB per-module `area.csv` is left out.
- `yardstick/build_summary.py` → `yardstick/summary.json`: every number on the results page.
- `results/nvidia-yardstick.html`: the results page.
