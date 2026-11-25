#!/bin/bash
# Run one scorecard experiment and append a line to <out_dir>/summary.tsv
# Usage: run_one.sh <vortex_root> <out_dir> <id> <app> <configs> <args> [driver] [perf]
ROOT="$1"; OUT="$2"; ID="$3"; APP="$4"; CFG="$5"; ARGS="$6"; DRV="${7:-simx}"; PERF="${8:-11}"
mkdir -p "$OUT"
[ -f "$OUT/summary.tsv" ] || echo -e "id\tstatus\tcycles\tinstrs\ttbuf_stalls\ttbuf_hits\tlmem_reads\tseconds" > "$OUT/summary.tsv"
cd "$ROOT/build" || exit 1
log="$OUT/$ID.log"
start=$(date +%s)
if [ "$PERF" = "0" ]; then
  CONFIGS="$CFG" timeout 10800 ./ci/blackbox.sh --driver="$DRV" --app="$APP" --args="$ARGS" > "$log" 2>&1
else
  CONFIGS="$CFG" timeout 10800 ./ci/blackbox.sh --driver="$DRV" --app="$APP" --perf="$PERF" --args="$ARGS" > "$log" 2>&1
fi
rc=$?
secs=$(( $(date +%s) - start ))
status=FAIL
grep -q "PASSED" "$log" && status=PASS
[ $rc -eq 124 ] && status=TIMEOUT
cyc=$(grep -oP 'PERF: instrs=\d+, cycles=\K\d+' "$log" | tail -1)
ins=$(grep -oP 'PERF: instrs=\K\d+' "$log" | tail -1)
st=$(grep -oP 'total_tbuf_stalls=\K\d+' "$log" | tail -1)
hi=$(grep -oP 'total_tbuf_cache_hits=\K\d+' "$log" | tail -1)
lr=$(grep -oP 'total_lmem_reads=\K\d+' "$log" | tail -1)
echo -e "$ID\t$status\t$cyc\t$ins\t$st\t$hi\t$lr\t$secs" >> "$OUT/summary.tsv"
