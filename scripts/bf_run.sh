#!/bin/bash
# Run one app on SimX in a given build dir and append a result line to ~/runs/bf/results.tsv
# Usage: bf_run.sh <build_dir> <label> <app> "<configs>" "<args>" [profile_json]
BD="$1"; L="$2"; APP="$3"; CFG="$4"; ARGS="$5"; PROF="$6"
OUT=~/runs/bf; mkdir -p $OUT
LOG=$OUT/$L.log
cd "$BD" || exit 1
P=""; [ -n "$PROF" ] && P="--profile=$PROF"
START=$(date +%s)
CCACHE_DISABLE=1 CONFIGS="$CFG" timeout 14400 ./ci/blackbox.sh --driver=simx --app=$APP --perf=1 $P --args="$ARGS" > $LOG 2>&1
RC=$?
ST=FAIL; grep -aq "PASSED" $LOG && ST=PASS; [ $RC -eq 124 ] && ST=TIMEOUT
CYC=$(grep -aoP 'PERF: instrs=\d+, cycles=\K\d+' $LOG | tail -1)
INS=$(grep -aoP 'PERF: instrs=\K\d+' $LOG | tail -1)
ERR=$(grep -aoP 'worst absolute error: \K[0-9.e+-]+' $LOG | tail -1)
echo -e "$L\t$ST\t$CYC\t$INS\t$ERR\t$(( $(date +%s) - START ))\t$PROF" >> $OUT/results.tsv
echo "$L $ST cycles=$CYC instrs=$INS err=$ERR"
