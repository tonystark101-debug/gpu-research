#!/bin/bash
# Run the week-1 AI scorecard on one Vortex tree.
# Usage: run_suite.sh <vortex_root> <out_dir> [filter]
# Each line of the suite: id | app | configs | args
ROOT="$1"
OUT="$2"
FILTER="${3:-.}"
mkdir -p "$OUT"
cd "$ROOT/build" || exit 1

COMMON="-DVX_CFG_EXT_TCU_ENABLE -DVX_CFG_TCU_WGMMA_ENABLE"
GPU32="-DVX_CFG_NUM_THREADS=32 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
GPU16="-DVX_CFG_NUM_THREADS=16 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
GPU8="-DVX_CFG_NUM_THREADS=8 -DVX_CFG_NUM_WARPS=8 -DVX_CFG_ISSUE_WIDTH=4"
F16="-DITYPE=fp16 -DOTYPE=fp32"

SUITE=$(cat <<EOF
gemm_ss_nt8_nrc8|sgemm_tcu_wg|$COMMON $GPU8 $F16 -DWGMMA_NRC=8 -DWGMMA_SS|-m128 -n128 -k128
gemm_ss_nt16_nrc16|sgemm_tcu_wg|$COMMON $GPU16 $F16 -DWGMMA_NRC=16 -DWGMMA_SS|-m128 -n128 -k128
gemm_ss_nt32_nrc8|sgemm_tcu_wg|$COMMON $GPU32 $F16 -DWGMMA_NRC=8 -DWGMMA_SS|-m128 -n128 -k128
gemm_ss_nt32_nrc32|sgemm_tcu_wg|$COMMON $GPU32 $F16 -DWGMMA_NRC=32 -DWGMMA_SS|-m128 -n128 -k128
gemm_rs_nt32_nrc8|sgemm_tcu_wg|$COMMON $GPU32 $F16 -DWGMMA_NRC=8 -DWGMMA_RS|-m128 -n128 -k128
attn_nt16_fp16|flash_attn_tcu_wg|$COMMON $GPU16 $F16 -DWGMMA_NRC=8|-N 128 -D 64
attn_nt32_fp16|flash_attn_tcu_wg|$COMMON $GPU32 $F16 -DWGMMA_NRC=8|-N 256 -D 64
attn_ci_tf32|flash_attn_tcu_wg|-DVX_CFG_NUM_ALU_BLOCKS=1 -DVX_CFG_NUM_LSU_BLOCKS=1 -DVX_CFG_NUM_FPU_BLOCKS=1|-N 128 -D 32
EOF
)

echo -e "id\tstatus\tcycles\tinstrs\ttbuf_stalls\ttbuf_hits\tlmem_reads\tseconds" > "$OUT/summary.tsv"
while IFS='|' read -r id app configs args; do
  [ -z "$id" ] && continue
  echo "$id" | grep -qE "$FILTER" || continue
  log="$OUT/$id.log"
  start=$(date +%s)
  CONFIGS="$configs" timeout 3600 ./ci/blackbox.sh --driver=simx --app="$app" --perf=11 --args="$args" > "$log" 2>&1
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
  echo -e "$id\t$status\t$cyc\t$ins\t$st\t$hi\t$lr\t$secs" >> "$OUT/summary.tsv"
done <<< "$SUITE"
echo "SUITE DONE" >> "$OUT/summary.tsv"
