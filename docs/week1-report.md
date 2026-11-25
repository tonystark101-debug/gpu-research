# Week 1 report: beating open-source Vortex on AI matrix maths (in simulation)

*25 November 2026 · all numbers are simulated clock cycles*

## The short version

1. **2.0× faster than Vortex on Vortex's own best AI matrix program:** 108,524 → 54,077 clock cycles, with the same answers (Vortex's own result check passes).
2. **1.2× to 2.7× faster across 9 settings that use Vortex's bulk-copy engine, 1.8× on average** (geometric mean).
3. **Correctness:** all 83 official Vortex tests we ran (copy engine and AI unit) pass with our changes switched on.
4. **Where it doesn't help yet:** programs that copy data with ordinary instructions, including Vortex's attention test as written. Those run at the same speed (±1%).
5. **The big caveat:** both changes live in Vortex's cycle-level simulator, **not yet in its Verilog chip design.** Vortex's test suite holds the simulator to the Verilog's timing within a set tolerance ("model parity" tests), so this is a strong signal, not final proof. Building the changes into the Verilog is next.

## What we did, day by day

| Day | What | Result |
|---|---|---|
| 1 | Set up a Linux build machine (16 vCPUs) and installed Vortex v3.0 (commit `f53bc48`, 24 Nov 2026) | First test passed in about 11 minutes |
| 2 | Baseline scorecard: matrix maths (5 settings), attention (3 settings) | Vortex's AI unit is busy only **1–4%** of the time |
| 3 | Profiled Vortex's best matrix program to find where the time goes | Found the bottleneck: the bulk-copy engine (below) |
| 4–5 | Made two changes: copy-engine "coalesced writes" (main) and AI-unit "fetch-ahead" (secondary) | 2.0× on the headline program |
| 6 | Full scorecard (11 workloads), plus Vortex's official test lists (83 cases) with our changes on | 1.2–2.7× on all 9 copy-engine workloads; 83 of 83 tests pass |
| 7 | This report and the results page | Published |

## What we found: the AI unit is starved

The program: Vortex's best matrix multiply (bulk copies, double buffering, fp16 tensor cores, 32-wide warps, 1 core, 128×128×256).

- The AI unit was busy **3.8%** of the time. The cores sat idle **93%** of the time, waiting for data.
- The **bulk-copy engine** was the bottleneck. This is Vortex's "DXA", modelled on NVIDIA Hopper's TMA.
  - It made **73,728** separate writes into local memory to move the tiles.
  - For **59,229 of 108,524 cycles**, all 8 of its request slots were full, so it couldn't ask for more data.
  - Each memory fetch spent **416 cycles** inside the engine. The memory itself answers in about 26.
- **Why:** the engine rearranges matrix B into the layout the AI unit reads, which Vortex calls "BlockMajor".
  - It does that **one 2-byte number per cycle**, even though its write connection into local memory is a full 128-byte row wide.
  - So a 64-byte chunk from memory became 32 tiny writes.

## What we changed

### 1. Copy engine: coalesced writes (the main win)

When the engine rearranges a chunk, each write now carries **every number in that chunk that lands in the same 64-byte block of local memory**, selected with a byte mask. Both halves of a 128-byte row are written in the same cycle. For this layout, that's **8 numbers per cycle instead of 1**.

- **Hardware realism:** the 128-byte write path already exists, and Vortex uses it for plain copies. The change sits only in the final write stage. That stage has to compute up to 8 destinations, which follow a fixed stride, and route the bytes through a small crossbar.
- **Effect on the headline program:**
  - Writes: 73,728 → **16,384** (4.5× fewer).
  - Time per memory fetch: 416 → **196** cycles.
  - Blocked cycles: 59,229 → **30,302**.

### 2. AI unit: fetch-ahead tile buffers (secondary)

The AI unit's operand buffers get a second slot. While one slice of A or B is in use, the next slice for the same instruction loads in the background. It loads at the lowest priority, so it never delays a fetch the unit is waiting on. Each fetched-ahead slice is tagged with its instruction, and a later instruction can never use it, so it can't serve stale data.

- **On its own: +0.4%,** because the AI unit wasn't the bottleneck.
- **After fix 1: +5%.** Removing one bottleneck exposed the next.
- Vortex's own design notes list the same idea as "not implemented: latency hiding across k".

## Scorecard

1 core, 8 warps, 4 issue slots, fp16 inputs with fp32 results unless noted.

| Workload | Vortex cycles | Our cycles | Speed-up |
|---|---:|---:|---:|
| Large tiles (NRC 32), 128×128×256 | 89,269 | 32,801 | **2.72×** |
| 16-wide warps, 128×128×256 | 185,924 | 91,412 | **2.03×** |
| Bigger matrix, 256×256×256 | 429,694 | 211,588 | **2.03×** |
| **Medium tiles (NRC 16), 128×128×256: headline** | **108,524** | **54,077** | **2.01×** |
| A operand from registers, 128×128×256 | 108,081 | 54,250 | **1.99×** |
| No double-buffering, 128×128×256 | 109,360 | 56,551 | **1.93×** |
| Small tiles (NRC 8), 128×128×256 | 148,543 | 101,502 | **1.46×** |
| Sparse AI maths (2:4), 128×128×128 | 87,912 | 65,015 | **1.35×** |
| Multicast copy (one read, several receivers), 128×64×32 | 88,945 | 72,379 | **1.23×** |
| Ordinary-copy matrix (no copy engine), 128³ | 122,810 | 121,651 | 1.01× |
| Attention (no copy engine), N=128, D=64 | 17,078,890 | 17,075,621 | 1.00× |

- **Geometric mean over the 9 copy-engine workloads: 1.81×** (min 1.23×, max 2.72×).
- Small tiles and multicast gain less, because per-transfer overheads and multicast replay dominate there.
- Every Vortex number repeated exactly across separate runs (the simulator is deterministic).

## Correctness

- Every scorecard run passed Vortex's built-in result check, which compares the computed answers with a CPU reference.
- We reran Vortex's official simulator test lists with both changes switched on: copy engine (40 cases), warp-group AI unit (28) and AI unit (15). **All 83 pass.**
- We caught one bug of our own on the way: the fetch-ahead code didn't compile on configurations without warp-group AI instructions. We fixed it (the feature now switches itself off there) and reran the affected cases.

## Honest caveats

1. **Simulator only.** The changes are in Vortex's C++ cycle-level model, not the Verilog. Vortex keeps the two matched through its CI, but our change isn't in the Verilog yet.
2. **Small scale.** 1 core, matrices up to 256×256×256. Bigger chips or matrices may hit other limits, such as memory bandwidth.
3. **The AI unit is still mostly idle** (7.6% busy on the headline). That's a lot of headroom.
4. **Attention is unchanged**, because Vortex's attention program doesn't use the copy engine.

## Next

1. **Build fix 1 into the Verilog** (the copy engine's write stage), then run Vortex's Verilog simulator tests and its simulator-vs-Verilog parity checks.
2. **A bigger copy-engine fix:** a small reorder buffer that writes whole 64-byte blocks (up to 32× fewer writes), plus more request slots. These are the next two bottlenecks.
3. **An attention program that uses the bulk-copy engine**, so the fixes reach that workload.
4. **First FPGA run**, for real clock speed and power.

## How to reproduce

See the [README](../README.md) for the base commit, the patch and the exact commands. Every script we ran is in [scripts/](../scripts/), and every log is in [runs/week1/](../runs/week1/).
