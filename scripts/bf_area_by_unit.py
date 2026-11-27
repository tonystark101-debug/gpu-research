#!/usr/bin/env python3
"""Standard-cell area of the synthesized core, broken down by unit.

Streams the flat mapped netlist, takes each cell instance's hierarchical name prefix
(Yosys keeps it in the flattened name, e.g. core.g_crossbar....fpu_unit...), and sums
ASAP7 Liberty cell areas into a few named groups.
Usage: bf_area_by_unit.py <liberty.lib> <mapped.v>
"""
import re, sys, collections

lib, net = sys.argv[1], sys.argv[2]
area = {}
cur = None
for line in open(lib, errors="replace"):
    m = re.match(r'\s*cell\s*\(\s*"?([A-Za-z0-9_]+)"?\s*\)', line)
    if m:
        cur = m.group(1)
        continue
    m = re.match(r'\s*area\s*:\s*([0-9.eE+-]+)', line)
    if m and cur and cur not in area:
        area[cur] = float(m.group(1))

GROUPS = [
    ("tensor unit (TCU/WGMMA)", r"tcu|wgmma|tensor"),
    ("copy engine (DXA)", r"dxa"),
    ("special functions + exp unit (SFU/TFU)", r"sfu|tfu"),
    ("floating-point unit (FPU)", r"fpu"),
    ("integer unit (ALU)", r"alu"),
    ("load/store + local memory", r"lsu|lmem|mem_unit|dcache|icache|cache"),
    ("issue (register files, scoreboard, operands)", r"issue|operand|scoreboard|ibuffer|dispatch|opc"),
    ("front end (fetch, decode, schedule)", r"fetch|decode|schedul|warp"),
]
pat = [(g, re.compile(r)) for g, r in GROUPS]
tot = collections.Counter()
cnt = collections.Counter()
unknown = collections.Counter()
inst_re = re.compile(r'^\s*([A-Za-z0-9_]+)\s+(\\\S+|[A-Za-z_][A-Za-z0-9_$\[\].]*)\s*\(')
for line in open(net, errors="replace"):
    m = inst_re.match(line)
    if not m:
        continue
    cell, name = m.group(1), m.group(2)
    if cell in ("module", "input", "output", "wire", "assign", "reg"):
        continue
    a = area.get(cell)
    if a is None:
        unknown[cell] += 1
        continue
    low = name.lower()
    grp = "other"
    for g, r in pat:
        if r.search(low):
            grp = g
            break
    tot[grp] += a
    cnt[grp] += 1
total = sum(tot.values())
print(f"total standard-cell area: {total:,.0f} um^2 in {sum(cnt.values()):,} cells")
for g, a in tot.most_common():
    print(f"{g:48s} {a:12,.0f} um^2  {100*a/total:5.1f}%  {cnt[g]:>10,} cells")
if unknown:
    print("cells without a Liberty area:", dict(unknown.most_common(8)))
