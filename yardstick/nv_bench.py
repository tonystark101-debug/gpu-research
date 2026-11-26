#!/usr/bin/env python3
"""NVIDIA yardstick: per-SM, per-clock throughput on the same work we run on Vortex.

For every test it records: time per run, TFLOPS (or GB/s), the average SM clock
and board power while the test ran (NVML, sampled every 50 ms), and the work per
SM per clock (multiply-adds for maths, bytes for copies).

Usage: nv_bench.py <out.json>
"""
import json
import sys
import threading
import time

import torch

OUT = sys.argv[1] if len(sys.argv) > 1 else "results.json"
torch.backends.cuda.matmul.allow_tf32 = False
torch.backends.cudnn.allow_tf32 = False

prop = torch.cuda.get_device_properties(0)
SM = prop.multi_processor_count
CC = (prop.major, prop.minor)
res = {
    "gpu": prop.name, "sm_count": SM, "cc": "%d.%d" % CC,
    "torch": torch.__version__, "cuda": torch.version.cuda, "tests": [],
}

# ---------------------------------------------------------------- NVML sampler
samples = []  # (wall time, sm clock MHz, power W)
try:
    import pynvml
    pynvml.nvmlInit()
    H = pynvml.nvmlDeviceGetHandleByIndex(0)
    res["max_sm_clock_mhz"] = pynvml.nvmlDeviceGetMaxClockInfo(H, pynvml.NVML_CLOCK_SM)
    res["power_limit_w"] = pynvml.nvmlDeviceGetEnforcedPowerLimit(H) / 1000.0
    res["mem_bus_width_bits"] = getattr(prop, "memory_bus_width", None)

    def _sample(stop):
        while not stop.is_set():
            try:
                c = pynvml.nvmlDeviceGetClockInfo(H, pynvml.NVML_CLOCK_SM)
                p = pynvml.nvmlDeviceGetPowerUsage(H) / 1000.0
                samples.append((time.time(), c, p))
            except Exception:
                pass
            time.sleep(0.05)
    _stop = threading.Event()
    threading.Thread(target=_sample, args=(_stop,), daemon=True).start()
except Exception as e:  # keep going without clocks; per-clock numbers then use the max clock
    res["nvml_error"] = repr(e)
    _stop = None


def window(t0, t1):
    s = [x for x in samples if t0 <= x[0] <= t1]
    if not s:
        return None, None
    return sum(x[1] for x in s) / len(s), sum(x[2] for x in s) / len(s)


def timed(fn, min_seconds=1.5):
    """Run fn repeatedly for at least min_seconds; return (seconds per call, t0, t1)."""
    for _ in range(3):
        fn()
    torch.cuda.synchronize()
    n = 1
    while True:  # calibrate the repeat count
        s = time.time()
        for _ in range(n):
            fn()
        torch.cuda.synchronize()
        if time.time() - s > 0.2:
            break
        n *= 2
    reps = max(1, int(n * min_seconds / max(time.time() - s, 1e-6)))
    t0 = time.time()
    ev0, ev1 = torch.cuda.Event(enable_timing=True), torch.cuda.Event(enable_timing=True)
    ev0.record()
    for _ in range(reps):
        fn()
    ev1.record()
    torch.cuda.synchronize()
    t1 = time.time()
    return ev0.elapsed_time(ev1) / 1000.0 / reps, t0, t1


def record(name, kind, work, seconds, t0, t1, extra=None):
    clk, pw = window(t0, t1)
    clk_hz = (clk or res.get("max_sm_clock_mhz") or 1) * 1e6
    entry = {"name": name, "kind": kind, "seconds": seconds, "sm_clock_mhz": clk, "power_w": pw}
    if kind == "macs":
        entry["tflops"] = 2 * work / seconds / 1e12
        entry["macs_per_sm_per_clock"] = work / seconds / clk_hz / SM
        if pw:
            entry["tflops_per_w"] = entry["tflops"] / pw
    else:  # bytes moved
        entry["gb_per_s"] = work / seconds / 1e9
        entry["bytes_per_sm_per_clock"] = work / seconds / clk_hz / SM
    if extra:
        entry.update(extra)
    res["tests"].append(entry)
    print(json.dumps(entry), flush=True)


def safe(name, fn):
    try:
        fn()
    except Exception as e:
        res["tests"].append({"name": name, "error": repr(e)[:300]})
        print(name, "ERROR", repr(e)[:300], flush=True)
    torch.cuda.empty_cache()


dev = "cuda"

# ------------------------------------------------------------- matrix maths
def gemm(M, N, K, dtype, label):
    def run():
        a = torch.randn(M, K, device=dev).to(dtype)
        b = torch.randn(K, N, device=dev).to(dtype)
        sec, t0, t1 = timed(lambda: torch.matmul(a, b))
        record("gemm_%s_%dx%dx%d" % (label, M, N, K), "macs", M * N * K, sec, t0, t1,
               {"format": label, "shape": [M, N, K], "batch": 1})
    safe("gemm_%s_%dx%dx%d" % (label, M, N, K), run)


def bgemm(M, N, K, dtype, label, per_sm):
    """One small product per CTA: the same job a single Vortex core runs, done on every SM."""
    B = SM * per_sm
    def run():
        a = torch.randn(B, M, K, device=dev).to(dtype)
        b = torch.randn(B, K, N, device=dev).to(dtype)
        sec, t0, t1 = timed(lambda: torch.bmm(a, b))
        record("bgemm_%s_%dx%dx%d" % (label, M, N, K), "macs", B * M * N * K, sec, t0, t1,
               {"format": label, "shape": [M, N, K], "batch": B})
    safe("bgemm_%s_%dx%dx%d" % (label, M, N, K), run)


def igemm(M, N, K):
    def run():
        a = torch.randint(-64, 64, (M, K), device=dev, dtype=torch.int8)
        b = torch.randint(-64, 64, (K, N), device=dev, dtype=torch.int8)
        sec, t0, t1 = timed(lambda: torch._int_mm(a, b))
        record("gemm_int8_%dx%dx%d" % (M, N, K), "macs", M * N * K, sec, t0, t1,
               {"format": "int8", "shape": [M, N, K], "batch": 1})
    safe("gemm_int8_%dx%dx%d" % (M, N, K), run)


for (M, N, K) in [(128, 128, 256), (256, 256, 256), (1024, 1024, 1024), (4096, 4096, 4096), (8192, 8192, 8192)]:
    gemm(M, N, K, torch.float16, "fp16")
bgemm(128, 128, 256, torch.float16, "fp16", 16)
bgemm(256, 256, 256, torch.float16, "fp16", 4)
gemm(4096, 4096, 4096, torch.float32, "fp32")  # CUDA cores (TF32 off)
igemm(4096, 4096, 4096)
if CC >= (8, 0):
    gemm(4096, 4096, 4096, torch.bfloat16, "bf16")
    bgemm(128, 128, 256, torch.bfloat16, "bf16", 16)
    torch.backends.cuda.matmul.allow_tf32 = True
    gemm(4096, 4096, 4096, torch.float32, "tf32")
    torch.backends.cuda.matmul.allow_tf32 = False
if CC >= (8, 9) and hasattr(torch, "float8_e4m3fn"):
    def fp8():
        M = N = K = 4096
        a = torch.randn(M, K, device=dev).to(torch.float8_e4m3fn)
        b = torch.randn(N, K, device=dev).to(torch.float8_e4m3fn).t()
        one = torch.tensor(1.0, device=dev)
        sec, t0, t1 = timed(lambda: torch._scaled_mm(a, b, scale_a=one, scale_b=one, out_dtype=torch.float16))
        record("gemm_fp8_4096x4096x4096", "macs", M * N * K, sec, t0, t1,
               {"format": "fp8", "shape": [M, N, K], "batch": 1})
    safe("gemm_fp8_4096x4096x4096", fp8)

# ---------------------------------------------------------------- attention
def attn(B, H, N, D, label):
    def run():
        q = torch.randn(B, H, N, D, device=dev, dtype=torch.float16)
        k = torch.randn(B, H, N, D, device=dev, dtype=torch.float16)
        v = torch.randn(B, H, N, D, device=dev, dtype=torch.float16)
        f = torch.nn.functional.scaled_dot_product_attention
        sec, t0, t1 = timed(lambda: f(q, k, v))
        # QK^T and PV: 2 * B*H*N*N*D multiply-adds (softmax not counted)
        record("attn_%s_B%d_H%d_N%d_D%d" % (label, B, H, N, D), "macs", 2 * B * H * N * N * D, sec, t0, t1,
               {"format": "fp16", "shape": [B, H, N, D]})
    safe("attn_%s" % label, run)


attn(SM * 16, 1, 128, 64, "vortex_size_per_sm")
attn(4, 16, 1024, 64, "mid")
attn(4, 16, 4096, 64, "long")
attn(1, 16, 4096, 128, "long_d128")

# ------------------------------------------------------------- memory speed
def copy_bw(nbytes):
    def run():
        x = torch.empty(nbytes, dtype=torch.uint8, device=dev)
        y = torch.empty_like(x)
        sec, t0, t1 = timed(lambda: y.copy_(x))
        record("copy_%dMB" % (nbytes >> 20), "bytes", 2 * nbytes, sec, t0, t1)  # read + write
    safe("copy_%dMB" % (nbytes >> 20), run)


copy_bw(1 << 30)
copy_bw(64 << 20)

if _stop is not None:
    _stop.set()
with open(OUT, "w") as fh:
    json.dump(res, fh, indent=1)
print("NVBENCH DONE", flush=True)
