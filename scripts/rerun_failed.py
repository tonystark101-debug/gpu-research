#!/usr/bin/env python3
"""Re-run the correctness-sweep cases that did not pass, sharded over our trees.

Usage: rerun_failed.py <shard_index> <num_shards> <tree> <out_dir>
Reads <out_dir>/shard*.tsv, picks ids whose status != PASS, writes
<out_dir>/rerun<shard>.tsv.
"""
import glob
import os
import subprocess
import sys
import time

shard, nshards, tree, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
extra = "-DVX_CFG_DXA_SCATTER_COALESCE -DVX_CFG_TCU_TBUF_PREFETCH"

failed = []
for f in sorted(glob.glob(os.path.join(out, "shard*.tsv"))):
    for line in open(f):
        parts = line.rstrip("\n").split("\t")
        if len(parts) == 3 and parts[0] != "id" and parts[1] != "PASS":
            failed.append(parts[0])

sys.path.insert(0, os.path.join(tree, "ci"))
import testcase as tc  # noqa: E402

cases = {}
for f in ["dxa.yaml", "tensor_wg.yaml", "tensor.yaml"]:
    for c in tc.load_category(os.path.join(tree, "ci", "testcases", f)):
        cases[c.id] = c
mine = [cid for i, cid in enumerate(failed) if i % nshards == shard]

summary = os.path.join(out, "rerun{}.tsv".format(shard))
with open(summary, "w") as fh:
    fh.write("id\tstatus\tseconds\n")
for cid in mine:
    c = cases[cid]
    argv, env = c.run_command(32)
    env = dict(env)
    env["CONFIGS"] = (env.get("CONFIGS", "") + " " + extra).strip()
    full_env = dict(os.environ)
    full_env.update(env)
    log = os.path.join(out, "rerun__" + cid.replace(":", "__").replace("/", "_") + ".log")
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
        fh.write("{}\t{}\t{}\n".format(cid, status, int(time.time() - t0)))
with open(summary, "a") as fh:
    fh.write("RERUN SHARD DONE\n")
