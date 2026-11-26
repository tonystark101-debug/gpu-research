# The battlefield (27 Nov 2026)

**Bottom line:** we fight NVIDIA in **small AI computers**, the 7–25 W boards inside robots, drones, cameras and edge boxes.
- The NVIDIA product to beat is the **Jetson Orin Nano Super**: 8 GPU cores and 15 W, 25 W or uncapped power modes. The developer kit costs **$399**. NVIDIA raised it from $249 in July 2026; our 27 Nov plan said $249, which was out of date. Its successor, the Orin Nano 2, is due in the first half of 2027.
- The score is **AI work per watt and per dollar, on the same real models**. Work per core per clock tick is the engineering score we can measure today.
- Graphics stays working, but we don't compete on it yet.
- Two facts from the research shape the fight:
  - On vision, fixed-function AI chips already beat the Jetson on work per watt (by 4–20× on paper).
  - On chat models, memory bandwidth decides who wins.
  - So a GPU-style chip wins by **running any model** (programmability) and **moving data well**, not by raw TOPS.

Facts and sources: [battlefield-research.md](battlefield-research.md) (gathered 27 Nov 2026; every number has a source and a confidence label).

Decided 27 Nov 2026 (the user said "go" to the proposal).

## 1. Why this fight

1. **NVIDIA's strongest moats matter least here.** No racks of 72 GPUs, no NVLink, no HBM supply queue. One chip on one small board, judged on watts and price.
2. **Per clock tick, one of its cores is the same size as ours.** On paper, an Orin core does as much AI maths per tick as an A100 core: 1,024 fp16 multiply-adds, the same peak as our core. Our yardstick against the A100 core therefore carries over.
3. **The buyers already shop around.** NPU makers (Hailo, Qualcomm, DeepX, Axelera and others) sell into the same boxes, so a better chip has a door to knock on.
4. **It's the size a small team can eventually build.** It has a few cores, ordinary LPDDR memory and one chip per board.

## 2. The NVIDIA chip we compare against

| | Jetson Orin Nano Super (8 GB) | our core (one) |
|---|---|---|
| GPU cores | 8 Ampere cores (1,024 CUDA cores, 32 tensor cores) | 1 |
| AI maths per core per tick (fp16, dense) | **1,024 multiply-adds**, the same as an A100 core (checked four ways from NVIDIA's figures) | **1,024** |
| GPU clock | 1,020 MHz uncapped (MAXN SUPER), 918 MHz in the 25 W mode, 612 MHz in the 15 W mode | 840 MHz predicted (Beacon); see [honest-numbers.md](honest-numbers.md) |
| Peak AI maths | 17 TFLOPS fp16 dense; 33 TOPS int8 dense (67 sparse) | 2 TFLOPS fp16 at 1 GHz |
| Memory | 8 GB LPDDR5, 128-bit, 102 GB/s in the 25 W and uncapped modes (68 GB/s at 15 W), shared with the CPU | simulated with a Jetson core's share ([honest-numbers.md](honest-numbers.md)) |
| Shared cache (L2) | about 2 MB: NVIDIA doesn't publish it, and an 8-core Orin NX reports 2 MB | 256 KB per core in our setup |
| CPU | 6 × Arm Cortex-A78AE at 1.7 GHz | none (not our fight) |
| Price | developer kit $399; module $399 (8 GB) or $349 (4 GB), all since July 2026 | — |

**Next from NVIDIA: Jetson Orin Nano 2** (announced 25 Aug 2026).
- NVIDIA claims about 2× the inference speed, from improved tensor cores and more memory bandwidth.
- 78 TOPS (precision not stated); 15–40 W, with the 15 W mode matching today's 25 W results; 8 GB.
- Press reports LPDDR5X at 120 GB/s.
- Due in the first half of 2027; no price yet.
- So the target moves: whatever we build gets compared with the Orin Nano 2 class, not today's board.

## 3. The score and the rules

**Scores, in order of importance**
1. **AI work per watt** on the same model: tokens per second per watt for chat models, images per second per watt for vision models.
2. **AI work per dollar**: list price for NVIDIA; for us, an estimated chip cost once we have a full-chip layout.
3. **Work per core per clock tick**: the engineering score we can measure now in simulation, against the same jobs on NVIDIA cores.

**Rules, so the comparison stays fair**
- Same model, same number format (or both stated), same batch size. Edge use is mostly batch 1.
- Count the same work on both sides, the way the yardstick already does.
- Say what the power figure covers: the chip, the GPU part only, or the whole board.
- Use NVIDIA's best published software for its numbers, not a weak setup.
- Our side runs on realistic memory: a Jetson core's share of bandwidth and delay (see [honest-numbers.md](honest-numbers.md)).

## 4. The jobs we test

Real models that people run on this board, with NVIDIA's (or Ultralytics') published Orin Nano Super numbers. These are the targets for plan step 3 (run one real model end to end).

| job | Jetson Orin Nano Super, published | how NVIDIA ran it |
|---|---:|---|
| Chat: SmolLM2 1.7B | 64.5 tokens/s | MLC, 4-bit weights, uncapped mode |
| Chat: Llama 3.2 3B | 43.1 tokens/s | same |
| Chat: Llama 3.1 8B | 19.1 tokens/s | same |
| Vision: YOLO11n object detection, 640 × 640 | 221 images/s (fp16), 270 (int8) | TensorRT, batch 1 (Ultralytics; power mode not stated) |
| Vision: ViT-base/16 | 158 images/s | TensorRT, fp16 |
| Vision: CLIP ViT-B/32 | 314 images/s | TensorRT, fp16 |

- **Chat is a memory race.** Generating a token reads every weight once. Llama 3.2 3B at 43 tokens/s reads about 70–80 GB/s, 70–80% of the board's 102 GB/s. More arithmetic won't help it; more bandwidth per watt will.
- **Vision is an arithmetic race,** and fixed-function chips are good at it.
- **NVIDIA publishes no watts per workload** for this board, so the per-watt score needs our own measurement (a Jetson on the desk) or careful estimates.
- **The software baseline keeps moving:** JetPack 7.2 (mid-2026) moved the board onto CUDA 13.2. Record the version and power mode for any number we reproduce.

## 5. Who else is in this fight

The real competition in this box isn't only NVIDIA. Each vendor quotes TOPS differently, so these are as quoted.

| product | quoted AI maths | power | price | chat models? | programmable? |
|---|---|---|---|---|---|
| Hailo-8 | 26 TOPS | 2.5 W | about $110 (Pi HAT) | no (vision) | fixed NPU |
| Hailo-10H (Pi AI HAT+ 2) | 40 TOPS (4-bit) | 2.5 W | $200 | yes, slowly: Llama 3.2 1B at 9.8 tokens/s | fixed NPU |
| Qualcomm Dragonwing IQ-9075 (Radxa Q900) | 100 TOPS dense | under 20–25 W (box) | $599 | Llama 3 8B at about 8 tokens/s | NPU + GPU |
| Rockchip RK3588 | 6 TOPS | — | boards $90–130 | Qwen2.5 1.5B at 16.7 tokens/s | fixed NPU |
| Rockchip RK1828 (chat co-processor) | 20 TOPS | 13.6 W average | $249 (M.2) | **Qwen3 8B at 61 tokens/s (claimed)**, with memory stacked in the package | NPU, needs a host |
| Axelera Metis | 214 TOPS | 3.5–9 W | about €270 | "experimental" | fixed NPU |
| DeepX DX-M1 | 25 TOPS | 2–5 W | $139–217 | claimed | fixed NPU |
| SiMa.ai Modalix | 50 TOPS | under 10 W | $1,499 kit | Qwen3.5 9B at 12 tokens/s | NPU; module fits Jetson sockets |
| Google Coral NPU (open RISC-V design) | about 0.5–1 TOPS | milliwatts | free design | small transformers | RISC-V + vector + matrix |

What this means for us:
1. **On paper, fixed NPUs beat the Jetson per watt by 4–20×** (vision, quoted peaks; the Jetson's figure covers a whole computer). Beating the Jetson per watt on vision alone isn't new.
2. **For chat, memory bandwidth decides.** The RK1828 claims 3× the Jetson's speed on an 8B model by putting its memory in the package. That supports our data-movement bet.
3. **Programmability is the opening.** Almost every rival is a fixed NPU with a compiler that handles only some operations, and chat support is often missing or experimental. A GPU-style chip that runs any new model at NPU-like efficiency is the gap.
4. **Coral NPU (RISC-V, open) is our closest open relative** at the low-power end.

## 6. What our chip must have to win here

1. **Move data well.**
   - Hide slow memory. A Jetson core gets about 12.5 bytes per tick, and each answer takes hundreds of ticks. Our core must keep enough data in flight to use that. [honest-numbers.md](honest-numbers.md) shows it doesn't yet, and that a deeper copy engine fixes most of it.
   - For chat models, get more memory bandwidth per watt. Putting the memory in the package is how the RK1828 claims 3× the Jetson.
2. **Small number formats.** int8 and fp16 today; fp8 and 4-bit for chat models.
3. **Low power when idle and when waiting.** Edge boxes spend much of their life waiting.
4. **Run standard models without hand-porting.** Software is NVIDIA's biggest moat (step 3 of the plan).

## 7. What we don't fight (yet)

- Data-centre chips (H100 class), training and multi-GPU systems.
- Graphics performance. We keep one frame rendering per milestone, so it's still a GPU.
- Cars (NVIDIA Drive) and the big Jetson Thor class (40–130 W).
