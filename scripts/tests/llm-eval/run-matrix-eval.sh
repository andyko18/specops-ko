#!/usr/bin/env bash
# specops-ko 매트릭스 eval 러너 (eval-lib 사용, declarative)
# 사용: bash scripts/tests/llm-eval/run-matrix-eval.sh [fixtures]
# 환경: CLAUDE_BIN(기본 미설정→stub provider, 토큰 0)
set -uo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$script_dir/eval-lib.sh"
FIXTURES="${1:-$script_dir/matrix-fixtures.jsonl}"
BIN="${CLAUDE_BIN:-}"

if [ -z "$BIN" ]; then
  echo "PROVIDER: stub (CLAUDE_BIN 미설정 — 토큰 0 시연)"
  EVAL_STUB_TEXT="Base64 인코딩 결과 4" EVAL_STUB_COST=0.01 eval::run_matrix "$FIXTURES" stub
  exit 0
fi
eval::skip_guard "$BIN" || exit 0
echo "PROVIDER: $BIN (실 모델 매트릭스는 점진 이관 FID — 본 러너는 stub 시연 + lib 제공)"
EVAL_STUB_TEXT="(실 모델 경로 미연결 — 별도 FID)" eval::run_matrix "$FIXTURES" "$BIN"
