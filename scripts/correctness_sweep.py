#!/usr/bin/env python3
"""Run Vortex's official simx test cases (dxa, tensor_wg, tensor) with our
hardware changes switched on, sharded across N copies of our tree.

Usage: correctness_sweep.py <shard_index> <num_shards> <tree> <out_dir> [extra_configs]
"""
import os
import subprocess
import sys
import time

shard, nshards, tree, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
extra = sys.argv[5] if len(sys.argv) > 5 else "-DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_TCU_TBUF_PREFETCH"

sys.path.insert(0, os.path.join(tree, "ci"))
import testcase as tc  # noqa: E402

cases = []
categories = os.environ.get("SWEEP_CATEGORIES", "dxa.yaml tensor_wg.yaml tensor.yaml").split()
for f in categories:
    for c in tc.load_category(os.path.join(tree, "ci", "testcases", f)):
        if c.driver == "simx" and c.via == "blackbox" and c.applies_to_xlen(32) and not c.check:
            cases.append(c)
mine = [c for i, c in enumerate(cases) if i % nshards == shard]

os.makedirs(out, exist_ok=True)
summary = os.path.join(out, "shard{}.tsv".format(shard))
with open(summary, "w") as fh:
    fh.write("id\tstatus\tseconds\n")
for c in mine:
    argv, env = c.run_command(32)
    env = dict(env)
    env["CONFIGS"] = (env.get("CONFIGS", "") + " " + extra).strip()
    full_env = dict(os.environ)
    full_env.update(env)
    safe = c.id.replace(":", "__").replace("/", "_")
    log = os.path.join(out, safe + ".log")
    t0 = time.time()
    with open(log, "w") as lf:
        lf.write("CONFIGS=" + env["CONFIGS"] + "\n" + " ".join(argv) + "\n")
        lf.flush()
        try:
            rc = subprocess.run(argv, env=full_env, cwd=os.path.join(tree, "build"),
                                stdout=lf, stderr=subprocess.STDOUT, timeout=5400).returncode
        except subprocess.TimeoutExpired:
            rc = 124
    status = "PASS" if rc == 0 else ("TIMEOUT" if rc == 124 else "FAIL")
    with open(summary, "a") as fh:
        fh.write("{}\t{}\t{}\n".format(c.id, status, int(time.time() - t0)))
with open(summary, "a") as fh:
    fh.write("SHARD DONE\n")
