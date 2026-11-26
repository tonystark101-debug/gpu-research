# Attention: where the time went, and the fix (26 Nov 2026)

**Bottom line:** Vortex's attention test was slow because of software, not hardware.
- 96% of its time went to one step, the softmax, and most of that to the C library's `expf`. That function computes in double precision, and Vortex cores have no double-precision hardware at 32 bits, so every exp ran thousands of emulated integer instructions.
- With five software changes, the same test runs **19–38× faster** with identical results:
  - 29× on the 16-thread setup with the hardware exp unit (TFU); 19× without it;
  - 38× and 23× on the 32-thread setup.
- Vortex's own upcoming FlashAttention-4 kernel (in open PR #495, not merged) is another 3–8× ahead of our fixed version: 22–31 multiply-adds per clock.
- So the attention gap to NVIDIA is not ~1,000×. It is about **12–75×** with our fix, and about **4–10×** with FA4.

## 1. Where the time went (FA2 kernel, fp16, 16 threads, 128 tokens, head 64)

Phase timing from cycle counters at each step (warp 0 of each CTA, summed over 4 CTAs):

| step | before | after (TFU) | after (no TFU) |
|---|---:|---:|---:|
| Q staging and setup | 42,046 | 41,978 | 42,364 |
| K staging | 216,298 | 139,141 | 141,422 |
| S = Q·Kᵀ (tensor unit) | 44,338 | 45,199 | 43,796 |
| **softmax** | **16,458,879** | 152,763 | 418,801 |
| V staging | 196,636 | 82,767 | 86,350 |
| O += P·V (tensor unit) | 119,488 | 119,435 | 114,520 |
| final write | 34,624 | 33,740 | 34,282 |
| **total** | **17,112,349** | **615,063** | **881,575** |

The "after" columns are the instrumented development build. On the clean branch: 586,231 cycles (TFU) and 901,532 (no TFU), against 17,078,890 before. The clean no-TFU exp also flushes results below FLT_MIN to exactly 0, which costs a few instructions.

Inside the old softmax, three things were slow:
1. **`expf` in double precision.** The kernel's disassembly calls `expf`, which uses `__muldf3`, `__adddf3` and `__extendsfdf2`: software double-precision maths.
2. **Max via `(a > b) ? a : b`.** This compiled to a branch per lane, which Vortex wraps in a divergent split/join. Each row paid this in the column loop and in every step of the 4-step butterfly reduction.
3. **One row at a time.** Each row has only 16 columns, so each lane held one value and every row needed two full-warp reductions, one after another, for 8 rows.

## 2. The changes (test code only; no hardware or simulator change)

1. **`expf_fast`** (shared helper):
   - With the TFU, it uses the hardware 2^x (`vx_expf_fast`).
   - Without it, it is float-only: range reduction, a degree-6 polynomial (about 1 ulp), and the exponent set directly in the bits. Results below FLT_MIN flush to 0.
2. **`fmax.s` instead of selects** for the row max and the butterfly reduction (shared helper).
3. **All rows at once:** each softmax row gets NT/xtileM neighbouring lanes (2 here). A row's max and sum then take 1 shuffle instead of 4, for all 8 rows together. Configurations where the rows don't split evenly over the lanes keep the old loop.
4. **Exact fast P packing:** fp32 → fp16 or bf16 with round-to-nearest-even in a handful of operations. It matches the host reference bit for bit. tf32 keeps the generic routine.
5. **Word-wide K and V staging:** 16-bit operands move 32 bits at a time. K is read along its rows, so a warp's reads are contiguous. A per-element division is replaced by stepping.

The scalar `flash_attn` test shares items 1 and 2.

Tried and dropped: unrolling the softmax loops by 4 gave no gain.

## 3. Results (SimX, Vortex master; cycles)

| case | before | after, no TFU | after, TFU |
|---|---:|---:|---:|
| FA2 fp16, NT16, 128 tokens, head 64 | 17,078,890 | 901,532 (18.9×) | 586,231 (29.1×) |
| FA2 fp16, NT32, 256 tokens, head 64 | 33,828,828 | 1,451,215 (23.3×) | 898,673 (37.6×) |

Worst absolute error before and after: 6.8e-5 (128 tokens) and 4.9e-5 (256 tokens), with tolerance 1e-3. Every run passes.

Multiply-adds per clock for one core:

| | 128 tokens (NT16) | 256 tokens (NT32) |
|---|---:|---:|
| Vortex FA2, before | 0.12 | 0.25 |
| Vortex FA2, our fix, TFU | 3.6 | 9.3 |
| Vortex FA4, PR #495 (NT8, tensor memory, TFU, DXA) | 26 (64 queries × 128 keys) | 31 (512 keys) |
| NVIDIA T4 / L4 / A100 / H100 core, 128 tokens | 116 / 101 / 245 / 278 | |

## 4. What it means

- **The biggest piece of the attention gap was software.** A slow library function and branchy code cost 19–38×.
- **Vortex's FA4 design is the real frontier:** dedicated warps, tensor memory, the copy engine and a hardware exp. It lands within about 4–10× of an NVIDIA core per clock on attention.
- **A wider lesson:** any Vortex kernel at 32 bits that calls `expf`, `logf` or similar pays the same soft-double cost.

### Vortex's own test setups (CI configurations; clean branch vs master)

| test | master | this change | speed-up |
|---|---:|---:|---:|
| `flash_attn` (scalar), default size | 24,183,365 | 2,059,878 | 11.7× |
| `flash_attn`, 63 tokens (ragged) | 24,757,865 | 2,647,071 | 9.4× |
| `flash_attn`, 128 tokens, head 64 | 132,013,700 | 42,624,663 | 3.1× |
| `flash_attn_tcu_wg`, tf32 (CI) | 13,202,145 | 1,286,237 | 10.3× |
| `flash_attn_tcu_wg`, fp16 (CI) | 13,148,980 | 821,255 | 16.0× |

These use Vortex's default thread count and the CI's single ALU/LSU/FPU block, and no TFU. Every case passes, with errors within 2e-7 of master's.

**Official catalog cases** (`pytest ci -k flash_attn` on the clean branch, master 2221ee2):
- XLEN 32: **5/5 pass**: flash_attn-1, -ragged, -lmem16k, flash_attn_tcu_wg-tf32, -fp16 (simx).
- XLEN 64: **7/7 pass**: the same five, plus flash_attn-rtlsim and flash_attn_tcu_wg-rtlsim (Verilog).

## 5. Status and next steps

1. **Done:** the clean branch `perf/flash-attn-softmax` passes every official flash_attn case. The patch is [patches/attention-flash-attn-2221ee2.patch](../patches/attention-flash-attn-2221ee2.patch).
2. **Next:** offer it upstream to Vortex as a pull request.
3. **Next in the plan:** re-test our core on realistic memory (about half a day).

Logs: [runs/attention/](../runs/attention/) (profiles, phase timings, variants) and [runs/attention/compare/](../runs/attention/compare/) (before/after, catalog runs).
