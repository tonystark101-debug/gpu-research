"""Turn the four raw NVIDIA result files plus our Vortex numbers into one summary (summary.json)."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
CHIPS = [  # key, label, year, process, die mm2, transistors (billions), full-die SM count
    ("t4", "NVIDIA T4", "Turing, 2018", "TSMC 12 nm", 545, 13.6, 48),
    ("l4", "NVIDIA L4", "Ada, 2023", "TSMC 4N (5 nm class)", 294.5, 35.8, 60),
    ("a100", "NVIDIA A100", "Ampere, 2020", "TSMC 7 nm", 826, 54.2, 128),
    ("h100", "NVIDIA H100", "Hopper, 2022", "TSMC 4N (5 nm class)", 814, 80.0, 144),
]
# Published dense peaks, multiply-adds per SM per clock (NVIDIA whitepapers / datasheets).
PEAK = {
    "fp16": {"t4": 512, "l4": 512, "a100": 1024, "h100": 2048},
    "bf16": {"l4": 512, "a100": 1024, "h100": 2048},
    "tf32": {"l4": 256, "a100": 512, "h100": 1024},
    "fp32": {"t4": 64, "l4": 128, "a100": 64, "h100": 128},
    "fp8": {"l4": 1024, "h100": 4096},
    "int8": {"t4": 1024, "l4": 1024, "a100": 2048, "h100": 4096},
}
SMALL_JOB_BYTES = 128 * 256 * 2 + 256 * 128 * 2 + 128 * 128 * 2  # A + B in, C out (fp16)
SMALL_JOB_MACS = 128 * 128 * 256

out = {"nvidia": [], "formats": {}}
for key, label, gen, proc, mm2, btr, full_sm in CHIPS:
    r = json.load(open(os.path.join(HERE, "raw", key + "_results.json")))
    t = {x["name"]: x for x in r["tests"] if "error" not in x}
    pick = lambda prefix: next(x for n, x in t.items() if n.startswith(prefix))
    sm = r["sm_count"]
    big, small = t["gemm_fp16_8192x8192x8192"], t["bgemm_fp16_128x128x256"]
    att_s, att_l = pick("attn_vortex_size"), pick("attn_long_d128")
    cp = t["copy_1024MB"]
    # memory limit for the small job: DRAM bytes per SM per clock (at the small job's clock) x MACs per byte
    b_per_clk = cp["gb_per_s"] * 1e9 / (sm * small["sm_clock_mhz"] * 1e6)
    mem_limit = b_per_clk * SMALL_JOB_MACS / SMALL_JOB_BYTES
    c = {
        "key": key, "label": label, "gen": gen, "process": proc, "sm": sm,
        "peak": PEAK["fp16"][key],
        "small": round(small["macs_per_sm_per_clock"], 1),
        "big": round(big["macs_per_sm_per_clock"], 1),
        "attn_small": round(att_s["macs_per_sm_per_clock"], 1),
        "attn_long": round(att_l["macs_per_sm_per_clock"], 1),
        "mem_gbs": round(cp["gb_per_s"]), "mem_gbs_per_sm": round(cp["gb_per_s"] / sm, 1),
        "mem_limit_small": round(mem_limit, 1),
        "max_clock": r["max_sm_clock_mhz"], "big_clock": round(big["sm_clock_mhz"]),
        "big_power": round(big["power_w"]), "power_limit": r["power_limit_w"],
        "big_tflops": round(big["tflops"], 1), "tflops_per_w": round(big["tflops"] / big["power_w"], 2),
        "die_mm2": mm2, "mm2_per_sm": round(mm2 / full_sm, 1), "mtr_per_sm": round(btr * 1000 / full_sm),
        "gpu_name": r["gpu"], "torch": r["torch"], "cuda": r["cuda"],
    }
    out["nvidia"].append(c)
    for fmt in PEAK:
        name = "gemm_%s_4096x4096x4096" % fmt
        if name in t:
            v = t[name]["macs_per_sm_per_clock"]
            out["formats"].setdefault(fmt, {})[key] = {"v": round(v, 1), "peak": PEAK[fmt][key],
                                                        "pct": round(100 * v / PEAK[fmt][key])}

# Our core: Vortex, 32 threads x 8 warps, issue width 4, tensor unit + DXA copy engine, SimX.
out["ours"] = {
    "peak": 1024,
    "small_original": round(SMALL_JOB_MACS / 108524, 1),   # Vortex master, DXA as shipped
    "small": round(SMALL_JOB_MACS / 56743, 1),             # + our coalescing fix (PR #506, also in Verilog)
    "small_best_sim": round(SMALL_JOB_MACS / 54077, 1),    # + simulator-only buffer prefetch (week 1)
    "job_256": round(256 ** 3 / 224342, 1),                # 256x256x256, with the fix
    "attn_small_nt16": round(2 * 128 * 128 * 64 / 17078890, 3),
    "attn_256_nt32": round(2 * 256 * 256 * 64 / 33828828, 3),  # the 32-thread run used 256 tokens
    "attn_instructions_nt16": 5694007,
    "fmax_mhz": 840, "process": "ASAP7 (academic 7 nm-class model)",
    "cells": 3328530, "ffs": 502717, "macros": 16,
    "logic_by_unit": [  # LUT-equivalent cells from Beacon's area report
        ["General floating-point unit", 1891766], ["AI (tensor) unit", 432590 + 97113],
        ["Instruction issue", 324148], ["Integer unit", 282830], ["Load / store", 154602],
        ["Other", 3328530 - 1891766 - 432590 - 97113 - 324148 - 282830 - 154602],
    ],
    "sim_memory_gbs": 460,
}
json.dump(out, open(os.path.join(HERE, "summary.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
