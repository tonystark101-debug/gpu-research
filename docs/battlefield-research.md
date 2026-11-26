# Battlefield research: Jetson Orin Nano Super and the 2-25 W edge-AI field

Facts as of 27 Nov 2026, gathered for the Vortex (RISC-V GPU) vs Jetson "AI work per watt and per dollar" comparison.

How to read the labels:
- **Official** means an NVIDIA page, document or NVIDIA staff forum answer.
- **Derived** means arithmetic on official numbers. The working is shown.
- **Reported** means trade press or a partner.
- **Unconfirmed** means no primary source was found.
- TOPS are INT8 unless stated. "Sparse" assumes 2:4 structured sparsity, which doubles the dense figure.
- `[Sx]` points to the Sources list at the end.

---

## 0. Headline numbers for the comparison

| Metric (Orin Nano Super 8GB developer kit) | Value | Label | Source |
|---|---|---|---|
| Peak INT8 tensor | 67 TOPS sparse / 33 TOPS dense | Official | [S1][S3] |
| Peak FP16 tensor | 33 TFLOPS sparse / 17 TFLOPS dense | Official | [S3] |
| FP32 on CUDA cores | 2.1 TFLOPS (FP16 non-tensor 4.2) | Official | [S3] |
| DRAM | 8 GB LPDDR5, 128-bit, 102 GB/s | Official | [S1] |
| Ridge point (compute ÷ bandwidth) | 326 INT8 ops/byte (dense); 163 FP16 FLOP/byte (dense) | Derived: 33.4e12/102.4e9; 16.7e12/102.4e9 | - |
| Highest power mode | 25 W budget; MAXN SUPER has no cap and throttles at the thermal limit | Official | [S2][S4] |
| Developer kit price | **$399 since July 2026** ($249 from Dec 2024; $499 before that) | Official | [S6][S7][S1] |
| Peak efficiency (nominal) | 2.7 sparse / 1.3 dense INT8 TOPS/W, assuming 25 W | Derived | - |
| Peak per dollar | 0.17 sparse / 0.084 dense INT8 TOPS per $ at $399 (0.27 / 0.13 at $249) | Derived | - |
| LLM decode example | Llama 3.2 3B INT4 (MLC): 43.1 tok/s; Llama 3.1 8B: 19.1 tok/s | Official | [S1][S2] |
| Measured power under AI load | See section 3 | - | - |

---

## 1. Official specs: Jetson Orin Nano 8GB (the module in the developer kit)

### 1a. Original vs Super

| Item | Original (JetPack 6.1 and earlier) | Super (JetPack 6.2 and later) | Source |
|---|---|---|---|
| GPU architecture | NVIDIA Ampere, compute capability 8.7 | same silicon | [S1][S9] |
| CUDA cores / Tensor Cores | 1,024 / 32 (3rd generation) | same | [S1] |
| SMs | 8. Working: 4 TPCs × 2 SMs per TPC; 128 CUDA cores and 4 Tensor Cores per SM | same | [S4] TPC count, [S8] SM layout; derived |
| GPU max clock | 625 MHz. The developer guide says 624.75; the Super launch blog table says 635. | 1,020 MHz | [S2][S4][S1] |
| Sparse INT8 | 40 TOPS | 67 TOPS | [S1] |
| Dense INT8 | 20 TOPS | 33 TOPS | [S1][S3] |
| FP16 tensor, dense / sparse | 10 / 20 TFLOPS (sparse derived) | 17 / 33 TFLOPS | [S1][S3] |
| FP32 on CUDA cores | 1.28 TFLOPS (derived: 1,024 × 2 × 0.625 GHz) | 2.1 TFLOPS | [S3] |
| L1 / shared memory | 192 KB L1 per SM (Orin family). Device reports a maximum of 164 KB shared memory per SM and 1,536 threads per SM. | same | [S8][S9] |
| GPU L2 | **Not in NVIDIA's public specs.** An 8-SM Orin NX 16GB (same GPU configuration) reports 2 MB (2,097,152 bytes). The 16-SM AGX Orin has 4 MB. Orin Nano 8GB is probably 2 MB: unconfirmed. | same | [S9][S8] |
| System-level cache | The Orin SoC diagrams show a 4 MB system cache. NVIDIA staff declined to say whether GPU traffic uses it: "we cannot disclose more details about cache handling". | same | [S8][S10] |
| Memory | 8 GB LPDDR5, 128-bit | same | [S1] |
| Data rate | 4,266 MT/s (EMC 2,133 MHz) | 6,400 MT/s (EMC 3,199 MHz) | [S4]; derived using the "3200 MHz = 6400 per pin" relation in [S8] |
| Bandwidth | 68 GB/s | 102 GB/s | [S1] |
| CPU | 6-core Arm Cortex-A78AE v8.2, 1.5 MB L2 + 4 MB L3, 1.5 GHz | same cores, 1.7 GHz | [S1][S5] |
| DLA / hardware video encoder | None (0 DLA cores) | None | [S4] |
| Module power modes | 7 W, 15 W | 15 W, 25 W and MAXN SUPER (uncapped) in the developer guide. NVIDIA's product pages say "7W-25W". | [S1][S4][S5] |
| Developer kit price | $499 at launch; $249 from Dec 2024 | **$399 since Jul 2026** | [S1][S6][S7] |
| Module price (1,000+ units) | 8GB: $299 | 8GB: **$399**; 4GB: **$349** (was $199) | [S6][S7] |
| Support life | Orin lifecycle extended to 2032 | | [S1] |

### 1b. Power modes, GPU clock and the peak throughput they allow (8GB)

The peak columns are derived. Working: SMs × 2,048 INT8 MAC (or 1,024 FP16 FMA) per SM per clock × 2 ops × clock.

| Config | Mode | Budget | CPU cores at max MHz | GPU TPCs (SMs) | GPU max MHz | EMC MHz → DRAM GB/s | INT8 dense / sparse TOPS | FP16 dense TFLOPS | Sparse TOPS per budget W |
|---|---|---|---|---|---|---|---|---|---|
| Original | 7W | 7 W | 4 at 960 | **2 (4 SMs)** | 408 | 2,133 → 68.3 | 6.7 / 13.4 | 3.3 | 1.9 |
| Original | 15W (default) | 15 W | 6 at 1,510 | 4 (8) | 624.75 | 2,133 → 68.3 | 20.5 / 40.9 | 10.2 | 2.7 |
| Super | 15W | 15 W | 6 at 1,498 | 4 (8) | 612 | 2,133 → 68.3 | 20.1 / 40.1 | 10.0 | 2.7 |
| Super | 25W | 25 W | 6 at 1,344 | 4 (8) | 918 | 3,199 → 102.4 | 30.1 / 60.2 | 15.0 | 2.4 |
| Super | MAXN SUPER | none (uncapped) | 6 at 1,728 | 4 (8) | 1,020 | 3,199 → 102.4 | 33.4 / 66.8 | 16.7 | n/a |

Source for the mode table: Jetson Linux Developer Guide r36.4.3 and r36.5.2 [S4].

Notes:
- MAXN SUPER is only available when the board is flashed with the `jetson-orin-nano-devkit-super` configuration [S4].
- In the 7 W mode, half the GPU is switched off.
- In the Super 15 W mode, memory stays at 68 GB/s. Only the 25 W and MAXN SUPER modes reach 102 GB/s.

### 1c. Does an Orin SM do as much tensor work per clock as an A100 SM? Yes.

| Chip | Published figure | Arithmetic | Per SM per clock |
|---|---|---|---|
| Orin Nano Super | 33 dense INT8 TOPS, 8 SMs, 1.020 GHz [S1][S3] | 33e12 ÷ (8 × 1.02e9) = 4,044. NVIDIA rounds 33.4 down to 33. 67 sparse ÷ 2 gives 4,105. | **≈4,096 INT8 ops = 2,048 INT8 MAC** |
| Orin Nano Super | 17 dense FP16 TFLOPS [S3] | 17e12 ÷ (8 × 1.02e9) = 2,083 FLOP | **≈2,048 FLOP = 1,024 FP16 FMA** |
| Orin Nano Super, reverse check | - | 1,024 FMA × 2 × 8 SMs × 1.02 GHz = 16.7 TFLOPS. NVIDIA quotes 17. | consistent |
| Orin Nano, original | 40 sparse TOPS [S1] | 2,048 × 2 × 8 × 0.625 GHz × 2 = 41.0 | consistent |
| AGX Orin 64GB (cross-check) | 170 sparse INT8 TOPS, 16 SMs; 5.3 FP32 TFLOPS gives a 1.29 GHz clock [S8] | 170e12 ÷ 2 ÷ (16 × 1.3e9) = 4,087 | ≈4,096 INT8 ops |
| A100 | "four Tensor Cores per SM, which together deliver 1024 dense FP16/FP32 FMA operations per clock" [S11] | 624e12 dense INT8 ÷ (108 × 1.41e9) = 4,098 | 1,024 FP16 FMA; 2,048 INT8 MAC |

**Conclusion:** per SM per clock, Orin's tensor cores match the A100's: 1,024 dense FP16 FMA and 2,048 dense INT8 MAC. Orin Nano Super is about 8/108 of an A100's SMs running at 72% of its clock, or about 5.4% of A100 dense FP16 (16.7 ÷ 312).

Orin differs from A100 elsewhere:
- **Threads per SM:** Orin holds at most 1,536 resident threads per SM (device-reported on Orin [S9]); A100 holds 2,048 (compute capability 8.0 [S34]).
- **Same L1/shared:** both have 192 KB of unified L1/shared memory per SM with up to 164 KB as shared memory [S34][S8].
- **L2:** much smaller, about 2 MB here vs A100's 40 MB [S9][S11].
- **Memory:** LPDDR5 shared with the CPU.

### 1d. Orin Nano 4GB, briefly

| Item | Original | Super | Source |
|---|---|---|---|
| GPU | 512 CUDA / 16 Tensor Cores; 4 SMs (2 TPCs) | same | [S3][S4] |
| GPU max clock | 624.75 MHz | 1,020 MHz | [S4] |
| INT8 sparse / dense | 20 / 10 (dense derived) | 34 / 17 | [S2][S3] |
| FP16 tensor, dense / sparse | - | 8.5 / 17 TFLOPS | [S3] |
| FP32 | 0.64 TFLOPS (derived) | 1.04 TFLOPS | [S3] |
| Memory | 4 GB LPDDR5, 64-bit, 34 GB/s | 51 GB/s | [S2][S3] |
| Power modes | 7W_AI (GPU 408 MHz), 7W_CPU (GPU 306 MHz), 10W (GPU 625 MHz) | 10W (612 MHz), 25W (1,020 MHz), MAXN SUPER (1,020 MHz). The NVIDIA product page says 7/10/25 W. | [S4][S3] |
| Module price (1,000+ units) | $199 | $349 since Jul 2026 | [S6][S7] |

---

## 2. Published performance of real models

### 2a. LLM decode on Orin Nano 8GB: NVIDIA's numbers

These use MLC with INT4 weights.

| Model | Original (tok/s) | Super (tok/s) | Speed-up |
|---|---|---|---|
| Llama 3.1 8B | 14.0 | 19.14 | 1.37× |
| Llama 3.2 3B | 27.7 | 43.07 | 1.55× |
| Llama 3.2 1B | 54.8 (original only [S13]) | not published | - |
| Qwen2.5 7B | 14.2 | 21.75 | 1.53× |
| Gemma 2 2B | 21.5 | 34.97 | 1.63× |
| Gemma 2 9B | 7.2 | 9.21 | 1.28× |
| Phi-3.5 mini (3.8B) | 24.7 | 38.1 | 1.54× |
| SmolLM2 1.7B | 41 | 64.5 | 1.57× |
| *Orin Nano 4GB:* Gemma 2 2B | 11.4 | 18.6 | 1.64× |
| *Orin Nano 4GB:* SmolLM2 1.7B | 23.0 | 35.8 | 1.56× |

Sources: [S1][S2][S12][S13].

- **Backend and precision:** "INT4 quantization using MLC API" [S2].
- **Power mode:** NVIDIA staff said the Super numbers were "tested under the super mode": `nvpmodel -m 2` (MAXN SUPER) plus `jetson_clocks` [S14]. The power mode for the original numbers is not stated.
- **Not stated by NVIDIA:** batch size (presumably 1) and prompt/output lengths.
- **Reproducibility:** a user measured Qwen2.5 7B at 19.23 tok/s against NVIDIA's 21.75, about 12% lower, in the same mode [S14].
- **No official Super numbers** for Qwen2.5 0.5B / 1.5B / 3B or Llama 3.2 1B. See 2b for newer small Qwen models.

**Derived: decode is limited by memory bandwidth.**
- Llama 3.2 3B reads about 1.6-1.8 GB of weights per token, assuming 4.0-4.5 bits per weight and tied embeddings. At 43.07 tok/s that is about 69-78 GB/s.
- Llama 3.1 8B reads about 3.75-4.2 GB per token. At 19.14 tok/s that is about 72-81 GB/s.
- So MLC sustains roughly **70-80% of the 102 GB/s peak**.
- The 1.3-1.6× Super gains follow the 1.5× bandwidth increase more than the 1.63× GPU clock increase.

### 2b. Newer official numbers: NVIDIA TensorRT Edge-LLM on Orin Nano 8GB

All runs: batch 1, INT4 AWQ weights, prompts of about 61 tokens. The v0.10.0 runs used JetPack 7.2. The power mode is not stated.

| Model | Decode tok/s | Prefill time | Orin NX 16GB decode, same release |
|---|---|---|---|
| Qwen3-0.6B | 72.8 | 28.7 ms | 117.4 |
| Qwen3-1.7B | 37.4 (36.5 in v0.10.0); 41.2 with EAGLE3 speculative decoding | 63.1 ms | 60.4 |
| Qwen3.5-0.8B (text only) | 55.4 (59.1 in v0.10.0) | 65.6 ms | 88.9 |
| Qwen3.5-2B (text only) | 30.0 (29.6 in v0.10.0) | 99.5 ms | 48.5 |
| Qwen3-VL-2B (VLM, 265 image tokens) | 36.9 | 190.9 ms prefill + 151 ms vision encoder | 60.1 |

Source: [S15].

Caution: these Orin Nano numbers are 35-40% below Orin NX 16GB, which has the same 102 GB/s memory. They are also well below MLC's 64.5 tok/s for SmolLM2-1.7B. The power mode was probably not MAXN SUPER (unconfirmed), so treat them as conservative.

### 2c. Vision-language models: NVIDIA

VILA and LLaVA ran at INT4 via MLC. The others ran at FP4 via Hugging Face Transformers.

| Model | Original | Super |
|---|---|---|
| VILA 1.5 3B | 0.7 | 1.06 |
| VILA 1.5 8B | 0.574 | 0.83 |
| LLaVA 1.6 7B | 0.412 | 0.57 |
| Qwen2-VL 2B | 2.8 | 4.4 |
| InternVL2.5 4B | 2.5 | 5.1 |
| PaliGemma2 3B | 13.7 | 21.6 |
| SmolVLM 2B | 8.1 | 12.9 |

Sources: [S1][S2].

NVIDIA's captions say "tokens/sec". But values around 1/s for VILA 3B are far below the LLM decode rates, so these probably measure end-to-end requests including image encoding. Treat the units as ambiguous.

### 2d. Vision models

**ViTs: NVIDIA, TensorRT FP16, frames per second** [S1][S2]

| Model | Original | Super |
|---|---|---|
| CLIP ViT-B/32 | 196 | 314 |
| CLIP ViT-B/16 | 95 | 161 |
| DINOv2-base/14 | 75 | 126 |
| ViT-base/16-224 | 98 | 158 |
| ViT-base/32-224 | 171 | 273 |
| SAM2 base | 4.42 | 6.34 |
| Grounding DINO | 4.11 | 6.23 |

**YOLO11: Ultralytics on the Orin Nano Super developer kit** [S16]

Conditions: Ultralytics 8.3.157, 640×640 input, the coco128 set, batch 1, JetPack 6.1. Times are milliseconds per image and exclude pre- and post-processing. FPS is derived as 1000 ÷ ms.
- The power mode is not stated.
- Ultralytics' own setup guide says `nvpmodel -m 0`, which is the **15 W** mode on Super, not MAXN SUPER.

| Model | TensorRT FP32 | TensorRT FP16 | TensorRT INT8 | mAP50-95, FP16 → INT8 |
|---|---|---|---|---|
| YOLO11n | 7.44 ms (134 FPS) | 4.53 ms (221 FPS) | 3.70 ms (270 FPS) | 0.506 → 0.483 |
| YOLO11s | 13.02 ms (77) | 6.93 ms (144) | 5.08 ms (197) | 0.578 → 0.574 |
| YOLO11m | 27.86 ms (36) | 13.50 ms (74) | 9.12 ms (110) | 0.631 → 0.629 |
| YOLO11l | 35.59 ms (28) | 17.48 ms (57) | 11.87 ms (84) | 0.636 → 0.621 |
| YOLO11x | 66.93 ms (15) | 32.58 ms (31) | 19.90 ms (50) | 0.689 → 0.661 |

**Other vision results**
- **YOLO26, Ultralytics' current docs** (Ultralytics 8.4.33) [S17]:
  - YOLO26n: TensorRT FP16 4.57 ms (219 FPS); INT8 3.80 ms (263 FPS).
  - YOLO26s FP16: 7.17 ms. YOLO26m FP16: 13.59 ms.
  - Comparison at YOLO26n FP16: Orin NX 16GB 4.13 ms; AGX Orin 2.62 ms; AGX Thor 1.39 ms.
- **YOLOv8n, independent and unreviewed** [S18]: MAXN SUPER with `jetson_clocks`, batch 1, timed with trtexec (GPU compute only):
  - FP16: 4.43 ms (225 FPS).
  - INT8: 3.49 ms (286 FPS).
- **ResNet-50:** NVIDIA staff said in March 2025: "We don't have official table of resent50 for the super mode" [S19]. NVIDIA's benchmarks page lists MLPerf results only for Orin NX and AGX Orin [S20]; see section 3.

**The software baseline keeps moving** [S33]:
- JetPack 7.2 (Jetson Linux 39.2, mid-2026) brought the Orin family onto JetPack 7: CUDA 13.2, Ubuntu 24.04, and standard Arm64 (SBSA) containers.
- JetPack 7.2.1 made the Super configuration the default when flashing the Orin Nano developer kit.
- When reproducing any number above, record the JetPack version and the power mode with `nvpmodel -q`.

---

## 3. Measured power and memory latency

*(pending: being filled from a parallel research pass)*

---

## 4. What NVIDIA is shipping next

### 4a. Jetson Orin Nano 2 (announced 25 Aug 2026)

| Item | What is known | Label | Source |
|---|---|---|---|
| AI compute | "78 trillion operations per second". NVIDIA does not state the precision or whether it is sparse. STH lists it as sparse INT8. | Official; precision reported | [S21][S22] |
| Headline claim | "2x the inference performance of Jetson Orin Nano Super through improved Tensor Cores and higher memory bandwidth". No footnote; no models named. | Official | [S21] |
| Power claim | "In 15-watt mode, it consumes 40% less power to deliver the same performance as its predecessor". JetsonHacks and STH read this as 15 W matching the Super's 25 W result. | Official, plus reading | [S21][S23][S22] |
| Power range | NVIDIA's Jetson page: "nearly twice the inference performance of its predecessor in the same form factor and 40W power envelope, consuming 40% less power". So the top mode is 40 W (official) and a 15 W mode exists (official). Press tables say 15-40 W. | Official, plus reported | [S32][S21][S22][S23] |
| Memory | 8 GB (official). LPDDR5X-7500, 120 GB/s (reported; STH calls it the first Orin product with LPDDR5X). | Mixed | [S21][S22] |
| CPU | "8-core Arm CPU" (official). Cortex-A78 class (reported). | Mixed | [S21][S22] |
| GPU | Ampere, with "architecture and microarchitecture" improvements. NVIDIA told STH the work extractable from the **32 Tensor Cores** has doubled. STH and JetsonHacks tables list **1,536 CUDA cores**, which contradicts 32 Tensor Cores. | Reported; core count unconfirmed | [S22][S23] |
| FP8 / FP4 | Not announced. STH notes Ampere has neither. | Unconfirmed | [S22] |
| Silicon | A new chip, per STH's briefing. NVIDIA staff on the forum (20 Nov 2026): "The design will be different than Orin Nano and documents will be released publicly upon the launched officially." | Reported, plus official forum | [S22][S24] |
| Video | A hardware H.264 encoder is listed (Orin Nano has none). | Unconfirmed (JetsonHacks table) | [S23] |
| Form factor | "same compact form factor". Pin compatibility is not confirmed. | Official | [S21][S24] |
| Availability | Module and developer kit "expected to be available in the first half of 2027". Shown as "In Development, 1H 2027, 8 GB RAM" on NVIDIA's roadmap. | Official | [S21][S25] |
| Price | Not announced | - | [S6] |

**Derived sanity check**
- Peak TOPS rises only 16% (78 ÷ 67) and bandwidth about 18% (120 ÷ 102). So a 2× gain cannot come from peak specs at equal power.
- It presumably comes from the 40 W mode, efficiency changes, or more SMs. NVIDIA has not said which.
- If 78 is sparse INT8 on 8 A100-class SMs, the implied GPU clock is about 1.19 GHz: 78e12 ÷ (8 × 4,096 × 2). That is close to the Orin NX Super GPU (77 sparse tensor TOPS at 1,173 MHz [S3]). This is speculation.

### 4b. Jetson T3000 and T2000: Blackwell "Thor" for mainstream robots (announced 15 Jul 2026)

| Item | T3000 | T2000 | Source |
|---|---|---|---|
| AI compute | 865 FP4 TFLOPS. NVIDIA does not say sparse; by arithmetic it is sparse (see below). | 400 FP4 TFLOPS | [S26] |
| GPU | Blackwell. Developer guide: 6 TPCs (12 SMs), 2 FBPs, 1,107 MHz maximum. Connect Tech: 1,536 CUDA cores. | 1,024 CUDA cores (Connect Tech) | [S26][S27][S29] |
| CPU | 8-core Neoverse, 2,106 MHz maximum | 6-core Neoverse (Connect Tech) | [S26][S27][S29] |
| Memory | 32 GB LPDDR5X, 273 GB/s | 16 GB; 137 GB/s (Connect Tech) | [S26][S29] |
| Power | "roughly half the size and power of the T5000". Connect Tech lists 70 W. | 40 W (Connect Tech) | [S26][S29] |
| Claim | "similar inference performance to the T5000" on multimodal workloads; no figures | Entry point for visual AI agents, mobile robots, manipulators | [S26] |
| Availability | Q1 2027. T3000 emulation on AGX Thor arrived with JetPack 7.2.1 (Aug 2026). | Q1 2027; emulation in a later release | [S26][S28] |
| Price | Not announced | Not announced | [S6] |

Derived check:
- T5000: 2,070 sparse FP4 TFLOPS ÷ (20 SMs × 1.575 GHz) = 65.7k FP4 FLOP per SM per clock.
- T3000: 12 SMs × 1.107 GHz × 65.7k = 873 TFLOPS, close to 865. So 865 is a **sparse** FP4 figure (about 432 dense).

### 4c. Top end: Jetson Thor T5000 and T4000

| Item | T5000 (AGX Thor) | T4000 | Source |
|---|---|---|---|
| AI compute | 2,070 FP4 TFLOPS, sparse ("130 W measured performance") | 1,200 FP4 TFLOPS, sparse | [S30][S31] |
| GPU | 2,560-core Blackwell, 10 TPCs, 5th-gen Tensor Cores, 1,575 MHz maximum | 1,536-core, 6 TPCs, 1,530 MHz | [S30][S27] |
| CPU | 14-core Neoverse-V3AE, 2.6 GHz | 12-core Neoverse-V3AE | [S30] |
| Memory | 128 GB LPDDR5X, 256-bit, 273 GB/s | 64 GB, 273 GB/s | [S30] |
| Power | 40-130 W | 40-70 W | [S30] |
| Price (1,000+ units) | $2,999 → **$4,999** (Jul 2026). Developer kit $3,499 → **$5,499**. | $1,999 → **$2,999** | [S6][S7] |
| Availability | Shipping; supply to 2035 on the roadmap | Shipping since Jan 2026 (JetPack 7.1); supply to 2035 | [S25][S31] |

NVIDIA's T4000 vs T5000 decode examples (precision not stated) [S31]:
- Qwen3-30B-A3B: 218 vs 258 tok/s.
- Qwen3-32B: 68 vs 83 tok/s.
- Mistral 3 14B: 100 vs 109 tok/s.

### 4d. Price rise in July 2026: use these for any per-dollar maths

NVIDIA raised Jetson prices with no announcement; the new prices appear in its FAQ [S6].

| Product | Old | New |
|---|---|---|
| Orin Nano Super developer kit | $249 | **$399** |
| Orin Nano 8GB module | $299 | $399 |
| Orin Nano 4GB module | $199 | $349 |
| Orin NX 8GB module | $399 | $649 |
| Orin NX 16GB module | $599 | $999 |
| AGX Orin 64GB module | $1,599 | $2,999 |
| AGX Orin developer kit | $1,999 | $3,499 |
| T4000 / T5000 modules | $1,999 / $2,999 | $2,999 / $4,999 |
| AGX Thor developer kit | $3,499 | $5,499 |

Old prices, the 22 Jul 2026 date and the increases are from CNX Software [S7]. NVIDIA gave no official reason [S7].

---

## 5. Non-NVIDIA rivals in the 2-25 W segment

Vendors label TOPS differently, so these figures are not directly comparable:
- Jetson's 67 is sparse; Hailo-10H's 40 is INT4; NXP quotes "eTOPS"; Ambarella publishes no TOPS at all.
- Figures are as each vendor quotes them.
- Prices are list prices seen in Nov 2026 unless dated otherwise.
- "n/s" means not stated.

| Product | Quoted AI compute | Power | Price | Transformers / LLMs (vendor tok/s unless noted) | Programmability | Source |
|---|---|---|---|---|---|---|
| **Jetson Orin Nano Super (baseline)** | 67 sparse / 33 dense INT8 TOPS | 7-25 W module | $399 developer kit | Yes. Llama 3.1 8B 19.1 tok/s; Llama 3.2 3B 43.1 tok/s (INT4, MLC) | Full CUDA GPU + 6-core CPU | [S1][S6] |
| Hailo-8 (M.2; Pi AI HAT+ 26T) | 26 TOPS | 2.5 W typical | $110 as a Pi HAT (Oct 2024) | Vision CNNs and transformers. Raspberry Pi says it can't run GenAI. | Fixed dataflow NPU; Hailo Dataflow Compiler | [R1][R2] |
| Hailo-8L (Pi AI HAT+ 13T) | 13 TOPS | 1.5 W typical | $70 | Vision only | Same | [R3] |
| Hailo-10H (M.2; **Pi AI HAT+ 2**, Jan 2026) | 40 TOPS **INT4** (about 20 INT8) | 2.5 W typical (chip) | HAT+ 2: $130 at launch, **$200 now** | Yes, but slow. Llama 3.2 1B 9.82 tok/s (A8W4, 2k context). Qwen3-4B 2.07. CNX found the Pi's own CPU faster on all 5 LLMs it tested. | Fixed NPU; 4 or 8 GB LPDDR4 on the module | [R4][R5][R6] |
| Qualcomm QCS6490 (RUBIK Pi 3, Radxa Dragon Q6A) | 12 TOPS | SoC power not published | RUBIK Pi 3 $179 (Jan 2025); Dragon Q6A from $59.50 (Oct 2025) | No official LLM figures | Hexagon NPU (vector + matrix) + Adreno GPU; QAIRT / AI Hub | [R7][R8] |
| Qualcomm QCS8550 | 48 TOPS | n/s | Lantronix kit about $1,500 (unconfirmed) | No LLM figures found | Hexagon + Adreno 740 | [R9] |
| Qualcomm Dragonwing IQ-8275 (Arduino VENTUNO Q, Aug 2026) | 40 INT8 TOPS (CNX: dense) | n/s | $399 (from 19 Oct 2026; $299 at launch) | Llama-3-8B 9.0-9.5 tok/s (w4a16) | Hexagon + Adreno 623; QAIRT / GENIE | [R10][R11][R12] |
| Qualcomm Dragonwing IQ-9075 (Radxa AIRbox Q900) | 100 dense / 200 sparse INT8 TOPS | Box: under 20 W normally; a 25 W mode for about 100 TOPS (CNX) | Q900 with 36 GB: $599 (Sep 2025) | Llama-3-8B 8.1-8.5 tok/s (w4a16) | Two Hexagon NPUs + Adreno 663 | [R13][R14][R12] |
| Rockchip RK3588 | 6 TOPS NPU | n/s | Boards about $90-130 (e.g. ROCK 5B+ 8 GB) | Yes, via RKLLM (w8a8). Qwen2.5-1.5B 16.7 tok/s; Qwen3-0.6B 32.9 | Fixed NPU; RKNN / RKLLM | [R15][R16] |
| **Rockchip RK1820 / RK1828** (LLM co-processor, Dec 2025) | 20 TOPS INT8 | RK1828 M.2: **13.6 W average, 29.4 W peak** on a 7B model | RK1828 M.2 $249 | Built for LLMs. Qwen3-8B 61.3 tok/s and Qwen3-4B 88.5 (quantization n/s), thanks to 2.5 or 5 GB of DRAM stacked in the package (bandwidth claimed at about 1 TB/s) | NPU co-processor; needs a Rockchip host over PCIe 2.1 x1 | [R17][R18] |
| Axelera Metis M.2 (now "Embedded 110m") | 214 TOPS INT8 peak | 3.5-9 W typical, 10 W TDP | €265-278 | LLMs marked "experimental"; no official tok/s | Fixed NPU (digital in-memory compute); Voyager SDK | [R19][R20] |
| Axelera Metis PCIe (now "Edge 130p") | 214 TOPS | 8-15 W typical (unconfirmed) | €349-456 | Same as M.2 | Same | [R20] |
| DeepX DX-M1 (M.2) | 25 TOPS INT8 | 2-5 W | $139 (DFRobot) / $217 (DigiKey) | Claims over 10 tok/s on 8B-class models (models not named) | Fixed NPU; DXNN | [R21][R22] |
| MemryX MX3 (4-chip M.2) | 24 TFLOPS (BF16 activations, INT8 weights) | 8 W typical / 14 W max | $149 | No LLMs: weights must fit about 42 MB of on-chip memory | Dataflow, compute next to memory; MemryX SDK | [R23][R24] |
| Google Coral Edge TPU | 4 TOPS INT8 | about 2 W | M.2 $24.99 | No LLMs | Fixed-function; Edge TPU compiler handles a subset of INT8 TFLite ops | [R25] |
| **Google Coral NPU** (open RISC-V IP, Oct 2025) in Synaptics SL2610 / SR200 | About 512 GOPS base design (claim); SL2610 up to 1 TOPS | "A few milliwatts" (claim) | IP is free (Apache-2.0) | Small transformers (aims at Gemma 270M) | **RISC-V scalar + RVV 1.0 vector + matrix unit**; MLIR/IREE compiler | [R26] |
| SiMa.ai MLSoC Modalix | 50 TOPS (INT8 / BF16) | Under 10 W; about 7.5 W in its Qwen3.5-9B test | Developer kit $1,499 | Qwen3.5-9B 12.0 tok/s, or 41.8 with speculative decoding, at about 7.5 W (SiMa data via TNW, Nov 2026) | ML accelerator + 8× Cortex-A65 + DSP; Palette SDK. Module is **pin-compatible with Jetson Orin NX/Nano**. | [R27][R28] |
| Ambarella CV72S / CV75S / CV7 | No TOPS published | CV72S under 3 W | Not public | CV75S runs VLMs and vision transformers; no tok/s | CVflow NPU | [R29][R30] |
| Ambarella N1-655 (Jan 2025) | No TOPS published | Under 20 W | Not public | Phi, Gemma, LLaVA-OneVision, Llama; no tok/s | CVflow | [R31] |
| EdgeCortix SAKURA-II | 60 TOPS INT8 / 30 TFLOPS BF16 | 10 W typical (module) | M.2 8 GB $249 | 7-8B LLMs supported; no tok/s | Reconfigurable NPU; MERA compiler | [R32] |
| NXP Ara240 (formerly Kinara Ara-2) | 40 "eTOPS" | 6.5 W typical (chip) | 16 GB M.2 $699 | Llama2-7B 14 tok/s | Programmable NPU; Ara SDK / eIQ | [R33] |
| Axera AX8850 (M5Stack LLM-8850 card, Oct 2025) | 24 TOPS INT8 | Up to 7 W | $99 card | Qwen2.5-1.5B 15.1 tok/s (W4A16) | NPU + 8× Cortex-A55 on the card | [R34][R35] |

**Above 25 W or not shipping yet, for context**
- Axelera Europa: 629 TOPS at 45 W per chip; shipping since Sep 2026 [R36].
- DeepX DX-M2: 80 TOPS target at about 5 W; taped out Nov 2026; samples in 2027; all figures are targets [R37].
- Qualcomm IQ10: above 25 W; not researched in depth.

**Takeaways for the comparison**

All of these are derived. Card-only peak numbers flatter accelerators that still need a host computer.

1. **Per watt on paper, fixed NPUs beat Jetson by 4-20×.** Quoted TOPS divided by typical watts:

   | Device | TOPS/W |
   |---|---|
   | Metis M.2 | about 21-24 |
   | Hailo-8 | about 10 |
   | SAKURA-II | about 6 |
   | DX-M1 | about 5 |
   | AX8850 | about 3.4 |
   | Jetson (dense INT8, 25 W) | about 1.3 |

   These are peak, mostly vision numbers. Jetson's figure covers a whole computer with CPU and DRAM.
2. **For LLM decode, memory bandwidth decides, not TOPS.**
   - Jetson, 102 GB/s: Llama 3.1 8B at 19 tok/s.
   - Qualcomm IQ-8 / IQ-9 (about 51-78 GB/s): Llama-3-8B at 8-9.5 tok/s.
   - Hailo-10H (LPDDR4): Qwen3-4B at 2 tok/s.
   - RK1828, with DRAM stacked in the package: claims Qwen3-8B at 61 tok/s.
3. **Dollars per tok/s on 7-9B models** (mixed models and quantization):

   | Option | $ per tok/s |
   |---|---|
   | RK1828 card, plus a host | about $4 ($249 ÷ 61.3) |
   | Jetson today | about $21 ($399 ÷ 19.1) |
   | Jetson before July 2026 | about $13 ($249 ÷ 19.1) |
   | SiMa kit, with speculative decoding | about $36 |
   | VENTUNO Q | about $42 |
   | NXP Ara240 M.2, plus a host | about $50 |
   | Radxa Q900 | about $70 |

4. **Programmability is the opening for a GPU-style core.**
   - Almost every rival is a fixed-function NPU behind a vendor compiler that handles only a subset of operations: Hailo, RKNN, DXNN, Voyager, MERA, the Edge TPU compiler.
   - LLM support is often missing or "experimental".
   - The programmable exceptions are Qualcomm Hexagon, TI's C7x DSP and the open RISC-V Coral NPU.
   - Coral NPU (RISC-V with vector and matrix units) is the closest open-hardware relative of Vortex at the low-power end.

Sources R1-R37 are listed separately at the end of the Sources section.

---

## Sources

- [S1] NVIDIA Technical Blog, "NVIDIA Jetson Orin Nano Developer Kit Gets a 'Super' Boost", 17 Dec 2024 - https://developer.nvidia.com/blog/nvidia-jetson-orin-nano-developer-kit-gets-a-super-boost/
- [S2] NVIDIA Technical Blog, "NVIDIA JetPack 6.2 Brings Super Mode to NVIDIA Jetson Orin Nano and Jetson Orin NX Modules", 16 Jan 2025 - https://developer.nvidia.com/blog/nvidia-jetpack-6-2-brings-super-mode-to-nvidia-jetson-orin-nano-and-jetson-orin-nx-modules/
- [S3] NVIDIA Jetson Orin product page (specs and compute comparison table) - https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin/
- [S4] Jetson Linux Developer Guide, Power and Performance, Orin Nano/NX/AGX Orin (r36.4.3; r36.5.2 identical for these modes) - https://docs.nvidia.com/jetson/archives/r36.4.3/DeveloperGuide/SD/PlatformPowerAndPerformance/JetsonOrinNanoSeriesJetsonOrinNxSeriesAndJetsonAgxOrinSeries.html and https://docs.nvidia.com/jetson/archives/r36.5.2/DeveloperGuide/SD/PlatformPowerAndPerformance/JetsonOrinNanoSeriesJetsonOrinNxSeriesAndJetsonAgxOrinSeries.html
- [S5] NVIDIA Jetson Orin Nano Super Developer Kit page - https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin/nano-super-developer-kit/
- [S6] NVIDIA Jetson FAQ (current list prices) - https://developer.nvidia.com/embedded/faq
- [S7] CNX Software, "NVIDIA increases the price of Jetson modules and devkits by up to 101%", 22 Jul 2026 - https://www.cnx-software.com/2026/07/22/nvidia-increases-the-price-of-jetson-modules-and-devkits-by-up-to-101/
- [S8] NVIDIA Jetson AGX Orin Series Technical Brief v1.2 (Jul 2022) - https://www.nvidia.com/content/dam/en-zz/Solutions/gtcf21/jetson-orin/nvidia-jetson-agx-orin-technical-brief.pdf
- [S9] deviceQuery output, Jetson Orin NX 16GB (reComputer J4012) - https://gist.github.com/atinfinity/8cede915acda05d0ff427c09604735dd
- [S10] NVIDIA Developer Forums, "JetsonAGX Orin: System-level Cache" (NVIDIA staff reply 4 Dec 2024) - https://forums.developer.nvidia.com/t/jetsonagx-orin-system-level-cache/314129
- [S11] NVIDIA Technical Blog, "NVIDIA Ampere Architecture In-Depth" (A100) - https://developer.nvidia.com/blog/nvidia-ampere-architecture-in-depth/
- [S12] Jetson AI Lab benchmarks (archived) - https://www.jetson-ai-lab.com/archive/benchmarks.html
- [S13] Jetson AI Lab, Small Language Models tutorial (archived; Llama 3.2 1B on original Orin Nano) - https://www.jetson-ai-lab.com/archive/tutorial_slm.html
- [S14] NVIDIA Developer Forums, "Jetson Orin Nano Super performance test issue" (NVIDIA staff, 29 Apr 2025) - https://forums.developer.nvidia.com/t/jetson-orin-nano-super-performance-test-issue/331700
- [S15] NVIDIA TensorRT Edge-LLM, Performance Benchmarks - https://nvidia.github.io/TensorRT-Edge-LLM/0.11.1/user_guide/performance/performance-benchmarks.html
- [S16] Ultralytics NVIDIA Jetson guide (YOLO11 tables, docs at tag v8.3.200) - https://github.com/ultralytics/ultralytics/blob/v8.3.200/docs/en/guides/nvidia-jetson.md
- [S17] Ultralytics NVIDIA Jetson guide (current, YOLO26) - https://docs.ultralytics.com/guides/nvidia-jetson/
- [S18] hokwangchoi, jetson-orin-nano-benchmarks (independent) - https://github.com/hokwangchoi/jetson-orin-nano-benchmarks
- [S19] NVIDIA Developer Forums, "Orin Nano/NX ResNet-50 benchmark on R36.4.3" (NVIDIA staff, 5 Mar 2025) - https://forums.developer.nvidia.com/t/orin-nano-nx-resnet-50-benchmark-on-r36-4-3-jetpack6-2/325862
- [S20] NVIDIA Jetson Benchmarks page - https://developer.nvidia.com/embedded/jetson-benchmarks
- [S21] NVIDIA Newsroom, "NVIDIA Announces Jetson Orin Nano 2 Robotics Computer to Redefine Entry-Level Edge AI", 25 Aug 2026 - https://nvidianews.nvidia.com/news/nvidia-announces-jetson-orin-nano-2-robotics-computer-to-redefine-entry-level-edge-ai
- [S22] ServeTheHome, "NVIDIA Announces Jetson Orin Nano 2: Entry-Level Edge Board Gets New Ampere Silicon" - https://www.servethehome.com/nvidia-announces-jetson-orin-nano-2-entry-level-edge-board-gets-new-ampere-silicon/
- [S23] JetsonHacks, "Jetson Orin Nano 2", 4 Sep 2026 - https://jetsonhacks.com/2026/09/04/jetson-orin-nano-2/
- [S24] NVIDIA Developer Forums, "Jetson Orin Nano 2: Expected Hardware changes and Pinout Compatibility" (NVIDIA staff, 20 Nov 2026) - https://forums.developer.nvidia.com/t/jetson-orin-nano-2-expected-hardware-changes-and-pinout-compatibility/389579
- [S25] NVIDIA Jetson Roadmap (hardware roadmap image) - https://developer.nvidia.com/embedded/develop/roadmap (image: https://developer.download.nvidia.com/embedded/images/jetson_roadmap/robotics-diagram-roadmap-modules-aug-r2_jetson-modules.png)
- [S26] NVIDIA Blog, "NVIDIA Introduces New Jetson Thor Computers to Advance Mainstream Robotics and Edge AI", 15 Jul 2026 - https://blogs.nvidia.com/blog/jetson-thor-robotics-edge-ai-agent/
- [S27] Jetson Linux Developer Guide r39.2.1, Jetson Thor power modes and T3000 emulation - https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/SD/PlatformPowerAndPerformance/JetsonThor.html
- [S28] NVIDIA Technical Blog, "NVIDIA JetPack 7.2.1 Adds Agentic Video Skills and T3000 Emulation", 11 Aug 2026 - https://developer.nvidia.com/blog/nvidia-jetpack-7-2-1-adds-agentic-video-skills-and-t3000-emulation/
- [S29] Connect Tech, "NVIDIA's New Jetson T3000 ... T2000 launch" (partner; "Specifications are subject to change"), 15 Jul 2026 - https://connecttech.com/jetson-t3000-t2000-launch/
- [S30] NVIDIA Jetson Thor product page - https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-thor/
- [S31] NVIDIA Technical Blog, "Accelerate AI Inference for Edge and Robotics with NVIDIA Jetson T4000 and NVIDIA JetPack 7.1", 5 Jan 2026 - https://developer.nvidia.com/blog/accelerate-ai-inference-for-edge-and-robotics-with-nvidia-jetson-t4000-and-nvidia-jetpack-7-1/
- [S32] NVIDIA Jetson / embedded systems page (Orin Nano 2 teaser: "40W power envelope") - https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/
- [S33] NVIDIA Developer Forums, "JetPack 7.2: Jetson Software Goes Agentic with Jetson Linux 39.2" - https://forums.developer.nvidia.com/t/jetpack-7-2-jetson-software-goes-agentic-with-jetson-linux-39-2/372060 ; JetPack 7.2.1 archive notes (Jetson Linux 39.2.1, 11 Aug 2026; CUDA 13.2.2, TensorRT 10.16.2) - https://developer.nvidia.com/embedded/jetpack/downloads/archive-7.2.1
- [S34] CUDA Programming Guide, Compute Capabilities appendix - https://docs.nvidia.com/cuda/cuda-programming-guide/05-appendices/compute-capabilities.html

### Rival sources (section 5)

- [R1] Hailo-8 product page - https://hailo.ai/products/ai-accelerators/hailo-8-ai-accelerator/
- [R2] Raspberry Pi AI HAT+ launch (Oct 2024) - https://www.raspberrypi.com/news/raspberry-pi-ai-hat/
- [R3] Hailo-8L product page - https://hailo.ai/products/ai-accelerators/hailo-8l-ai-accelerator-for-ai-light-applications/ ; Raspberry Pi AI Kit - https://www.raspberrypi.com/news/raspberry-pi-ai-kit-available-now-at-70/
- [R4] Hailo-10H product page - https://hailo.ai/products/ai-accelerators/hailo-10h-ai-accelerator/ ; Hailo Model Explorer, Llama 3.2 1B on Hailo-10H - https://hailo.ai/products/hailo-software/model-explorer/generative-ai/llama3-2-1b-instruct/
- [R5] Raspberry Pi AI HAT+ 2 product page ($200) - https://www.raspberrypi.com/products/ai-hat-plus-2/ ; launch post (Jan 2026) - https://www.raspberrypi.com/news/introducing-the-raspberry-pi-ai-hat-plus-2-generative-ai-on-raspberry-pi-5/
- [R6] CNX Software review of AI HAT+ 2 (20 Jan 2026) - https://www.cnx-software.com/2026/01/20/raspberry-pi-ai-hat-2-review-a-40-tops-ai-accelerator-tested-with-computer-vision-llm-and-vlm-workloads/
- [R7] Qualcomm QCS6490 - https://www.qualcomm.com/internet-of-things/products/q6-series/qcs6490
- [R8] RUBIK Pi 3 at $179 (Hackster) - https://www.hackster.io/news/thundercomm-s-rubik-pi-3-edge-ai-board-developed-with-qualcomm-goes-on-sale-for-179-529c9a8384c2 ; Radxa Dragon Q6A (CNX) - https://www.cnx-software.com/2025/10/27/radxa-dragon-q6a-a-qualcomm-qcs6490-edge-ai-sbc-with-gbe-wifi-6-three-camera-connectors/
- [R9] Qualcomm QCS8550 - https://www.qualcomm.com/internet-of-things/products/q8-series/qcs8550 ; Lantronix kit - https://estore.lantronix.com/products/open-q-8550-development-kit
- [R10] Qualcomm Dragonwing IQ-8275 - https://www.qualcomm.com/internet-of-things/products/iq8-series/iq-8275
- [R11] CNX Software, Arduino VENTUNO Q (25 Aug 2026) - https://www.cnx-software.com/2026/08/25/299-arduino-ventuno-q-sbc-combines-qualcomm-dragonwing-iq8-soc-and-stm32h5-mcu/
- [R12] Qualcomm model cards on Hugging Face - https://huggingface.co/qualcomm/Llama-v3-8B-Instruct and https://huggingface.co/qualcomm/Llama-v3.2-3B-Instruct-SSD
- [R13] Qualcomm Dragonwing IQ-9075 - https://www.qualcomm.com/internet-of-things/products/iq9-series/iq-9075
- [R14] CNX Software, Radxa Fogwise AIRbox Q900 (30 Sep 2025) - https://www.cnx-software.com/2025/09/30/fogwise-airbox-q900-599-qualcomm-iq-9075-ai-box-delivers-up-to-200-tops-of-ai-performance/
- [R15] Rockchip RK3588 - https://www.rock-chips.com/a/en/products/RK35_Series/2022/0926/1660.html ; SBC prices 2024 vs 2026 (CNX) - https://www.cnx-software.com/2026/04/28/what-a-difference-two-years-make-comparing-sbc-prices-in-2024-and-2026/
- [R16] Rockchip RKLLM benchmark - https://github.com/airockchip/rknn-llm/blob/main/benchmark.md
- [R17] DFRobot RK1828 M.2 module - https://www.dfrobot.com/product-3142.html
- [R18] CNX Software, RK1820/RK1828 modules and benchmarks (30 Dec 2025) - https://www.cnx-software.com/2025/12/30/rockchip-rk1820-rk1828-so-dimm-and-m-2-llm-vlm-ai-accelerator-modules-devkits-and-benchmarks/
- [R19] Axelera Metis M.2 datasheet - https://docs.axelera.ai/assets/files/axelera-ai-metis-m.2-ai-accelerator-card-datasheet-0f0d0d6c4d4c547b8400fccaa6831802.pdf
- [R20] Axelera store - https://store.axelera.ai/ (e.g. https://store.axelera.ai/products/axelera-edge-130p-16gb)
- [R21] DeepX DX-M1 - https://deepx.ai/products/dx-m1/
- [R22] DFRobot DX-M1 - https://www.dfrobot.com/product-3018.html
- [R23] MemryX MX3 - https://memryx.ai/mx3/
- [R24] Tom's Hardware, MemryX MX3 M.2 at $149 - https://www.tomshardware.com/tech-industry/artificial-intelligence/memryx-launches-usd149-mx3-m-2-ai-accelerator-module-capable-of-24-tops-compute-power
- [R25] Coral USB Accelerator datasheet - https://coral.ai/static/files/Coral-USB-Accelerator-datasheet.pdf ; Google blog on the M.2 accelerator - https://developers.googleblog.com/en/doubling-down-on-the-edge-with-corals-new-accelerator/
- [R26] Google, "Introducing Coral NPU" (Oct 2025) - https://developers.googleblog.com/en/introducing-coral-npu-a-full-stack-platform-for-edge-ai/ ; CNX on Synaptics SL2610 - https://www.cnx-software.com/2025/10/17/google-open-source-coral-npu-synaptics-sl2610-edge-ai-socs/
- [R27] SiMa.ai MLSoC / Modalix - https://sima.ai/mlsoc/ ; Modalix SoM brief - https://sima.ai/wp-content/uploads/2026/03/Modalix-SoM-Product-Brief_06.2.pdf
- [R28] The Next Web on SiMa.ai Palette 3.0 (Nov 2026) - https://thenextweb.com/news/sima-ai-palette-3-0-physical-ai-drones-robots
- [R29] Ambarella CV72S (EEJournal) - https://www.eejournal.com/industry_news/ambarella-launches-4k-5nm-edge-ai-soc-for-mainstream-security-cameras-with-new-highs-in-ai-performance-per-watt-image-quality-and-sensor-fusion/
- [R30] Ambarella CV75S - https://www.ambarella.com/news/ambarellas-latest-5nm-ai-soc-family-runs-vision-language-models-and-ai-based-image-processing-with-industrys-lowest-power-consumption/ ; CV7 (Jan 2026) - https://www.edge-ai-vision.com/2026/01/ambarella-launches-powerful-edge-ai-8k-vision-soc-with-industry-leading-ai-and-multi-sensor-perception-performance/
- [R31] Ambarella N1 (CNX) - https://www.cnx-software.com/2024/01/09/ambarella-n1-soc-generative-ai-to-the-edge-video-analytics-robotics-industrial-applications/ ; N1-655 (ElectronicsForU) - https://www.electronicsforu.com/special/ai-chip-for-robots-ai-boxes-and-city-security
- [R32] EdgeCortix SAKURA-II modules and cards - https://edgecortix.com/en/products/sakura-modules-and-cards
- [R33] NXP Ara240 fact sheet - https://www.nxp.com/docs/en/fact-sheet/ARA240DNPUFS.pdf ; Ara-2 M.2 module - https://www.nxp.com/design/design-center/development-boards-and-designs/ARA-2-2M-MODULE
- [R34] CNX Software, M5Stack LLM-8850 (AX8850) - https://www.cnx-software.com/2025/10/03/m5stack-llm-8850-card-an-m-2-m-key-ai-accelerator-module-based-on-axera-ax8850-24-tops-soc/
- [R35] M5Stack model benchmarks - https://docs.m5stack.com/en/stackflow/models/benchmark
- [R36] Axelera Europa launch - https://axelera.ai/news/axelera-launches-europa-aipu-setting-new-industry-benchmark-for-ai-accelerator-performance-power-efficiency-and-affordability ; StorageReview - https://www.storagereview.com/news/axelera-europa-ships-629-tops-at-45w-per-aipu-in-validated-dell-xe5-and-supermicro-servers
- [R37] DeepX DX-M2 - https://deepx.ai/products/dx-m2/ ; EE Times Japan - https://eetimes.itmedia.co.jp/ee/spv/2601/23/news067.html

---

## Confidence and gaps

**High confidence** (official NVIDIA documents, checked directly):
- Orin Nano core counts, TOPS/TFLOPS, clocks in every power mode, memory bandwidth and CPU.
- The A100-equal tensor rate per SM per clock. Four independent official numbers agree once rounding is allowed for.
- Current prices (NVIDIA FAQ).
- NVIDIA's own LLM, VLM and ViT tables.
- Orin Nano 2 headline claims; T3000/T2000 FP4, memory and dates; T3000 clocks (developer guide).

**Medium confidence**
- **GPU L2 = 2 MB:** device-reported on the 8-SM Orin NX, not the Nano; NVIDIA publishes no figure.
- **System cache:** whether the GPU uses the 4 MB system cache is undisclosed.
- **LPDDR5 data rates (4,266 / 6,400 MT/s):** derived from memory-controller clocks.
- **Effective LLM bandwidth of 70-80%:** derived, and depends on the assumed bits per weight.
- **Ultralytics YOLO numbers:** power mode not stated.
- **TensorRT Edge-LLM numbers:** power mode not stated, and they look low.

**Low confidence / unconfirmed**
- Orin Nano 2: CUDA core count (1,536 vs "32 Tensor Cores"), LPDDR5X-7500 / 120 GB/s, sparse-vs-dense basis of 78 TOPS, FP8/FP4 support, pinout, price.
- T2000 / T3000: CUDA cores and watts come only from Connect Tech, a partner.
- Rival figures marked unconfirmed in section 5, especially RK1828 power and bandwidth, and Hailo/Axelera LLM throughput.

**Gaps**
- **No official ResNet-50 for Orin Nano Super:** NVIDIA said so.
- **NVIDIA's LLM tables lack test conditions:** no batch size or prompt/output lengths, and no power mode for the "original" column.
- **No NVIDIA-published watts per workload for Orin Nano Super.**
- **VLM units are ambiguous:** NVIDIA's tables say "tokens/s".
- **Rival prices move fast:** memory costs pushed many 2026 prices up (Jetson, Raspberry Pi, Arduino).

*(Section 3 confidence notes follow below once that section is filled.)*
