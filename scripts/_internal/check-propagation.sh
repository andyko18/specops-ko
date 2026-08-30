#!/usr/bin/env bash
# 계약 경계 전파 스캔 — propagation-matrix.jsonl 의 source→consumer must_match 검증
# Usage: bash scripts/_internal/check-propagation.sh
# exit 0 = 전 edge PASS · exit 1 = 누락
set -uo pipefail

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# MATRIX 경로는 env 로 덮을 수 있다 — 테스트가 픽스처를 물려 **실제 체커의 FAIL 경로**를
#   실행하기 위해서다. 기본값은 종전과 동일하다(.githooks/pre-commit 이 매 커밋 무인자 호출).
MATRIX="${SPECOPS_PROPAGATION_MATRIX:-$PLUGIN/scripts/_internal/propagation-matrix.jsonl}"
[ -f "$MATRIX" ] || { echo "PROPAGATION: FAIL matrix 부재 ($MATRIX)" >&2; exit 1; }

fail=0
n=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  id=$(printf '%s' "$line" | jq -r '.id // empty')
  [ -n "$id" ] || continue
  edge_n=$(printf '%s' "$line" | jq -r '.edges|length')
  i=0
  while [ "$i" -lt "$edge_n" ]; do
    path=$(printf '%s' "$line" | jq -r --argjson i "$i" '.edges[$i].path')
    pat=$(printf '%s' "$line" | jq -r --argjson i "$i" '.edges[$i].must_match')
    i=$((i+1))
    n=$((n+1))
    f="$PLUGIN/$path"
    if [ ! -f "$f" ]; then
      echo "PROPAGATION: FAIL [$id] missing file: $path"
      fail=$((fail+1))
      continue
    fi
    if grep -Eq "$pat" "$f"; then
      echo "PROPAGATION: OK [$id] $path ~ /$pat/"
    else
      echo "PROPAGATION: FAIL [$id] $path missing /$pat/"
      fail=$((fail+1))
    fi
  done
done < "$MATRIX"

if [ "$fail" -gt 0 ]; then
  echo "PROPAGATION: FAIL ($fail/$n edges)"
  exit 1
fi
echo "PROPAGATION: PASS ($n edges)"
exit 0
