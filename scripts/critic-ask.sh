#!/usr/bin/env bash
# 외부 모델 critic 위탁 래퍼 — advisory only (판정 권한 없음, provider 오류·timeout 도 exit 0)
# 사용: bash scripts/critic-ask.sh <prompt-file> [--files <f1> [f2 ...]]
# 환경: CRITIC_BIN (강제 provider — stdin 합성 프롬프트 / stdout 의견 계약) · CRITIC_TIMEOUT (기본 120s)
# 출력: "CRITIC[<provider>]:" + 의견 / "CRITIC: SKIP (외부 CLI 부재)" / "CRITIC: FAIL (<사유>)"
# 종료: 항상 0 — prompt-file 부재만 1 (사용 오류)
set -uo pipefail

PROMPT_FILE="${1:?prompt-file required}"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt-file 부재: $PROMPT_FILE" >&2
  exit 1
fi
shift
FILES=()
if [ "${1:-}" = "--files" ]; then
  shift
  while [ $# -gt 0 ]; do FILES+=("$1"); shift; done
fi
TIMEOUT_S="${CRITIC_TIMEOUT:-120}"
MAX_BYTES=204800

# provider 감지: CRITIC_BIN > codex > gemini (A-1)
provider=""; bin=""
if [ -n "${CRITIC_BIN:-}" ]; then
  provider="custom"; bin="$CRITIC_BIN"
elif command -v codex >/dev/null 2>&1; then
  provider="codex"; bin="codex"
elif command -v gemini >/dev/null 2>&1; then
  provider="gemini"; bin="gemini"
else
  echo "CRITIC: SKIP (외부 CLI 부재)"
  exit 0
fi

syn=""; out_f=""; err_f=""; mark=""
cleanup() { rm -f "$syn" "$out_f" "$err_f" "$mark" 2>/dev/null; }
trap cleanup EXIT

# 프롬프트 합성: prompt-file + 구분자 + 대상 파일들 (NFR-3 200KB 절단)
syn=$(mktemp)
cat "$PROMPT_FILE" > "$syn"
for f in ${FILES+"${FILES[@]}"}; do
  [ -f "$f" ] || continue
  printf '\n--- 파일: %s ---\n' "$f" >> "$syn"
  cat "$f" >> "$syn"
done
size=$(wc -c < "$syn" | tr -d ' ')
if [ "$size" -gt "$MAX_BYTES" ]; then
  head -c "$MAX_BYTES" "$syn" > "$syn.cut" && mv "$syn.cut" "$syn"
  printf '\n[절단: 합성 %sB > %sB — 앞부분만 위탁]\n' "$size" "$MAX_BYTES" >> "$syn"
  echo "CRITIC: 절단 적용 (${size}B → ${MAX_BYTES}B)" >&2
fi

_invoke_provider() {
  # stdin=합성 프롬프트 → stdout=의견.
  # A-2 한계 고백: codex/gemini 플래그는 실측 미확인 (미설치 환경 작성) — 설치 후 본 함수만 보정
  case "$provider" in
    custom) "$bin" ;;
    codex)  codex exec - ;;
    gemini) gemini -p - ;;
  esac
}

out_f=$(mktemp); err_f=$(mktemp); mark=$(mktemp); rm -f "$mark"
_invoke_provider < "$syn" > "$out_f" 2>"$err_f" &
pid=$!
# 워치독 — llm-eval run_once 패턴 (출력 차단 + 마커 + 자식 정리, bash 3.2)
( sleep "$TIMEOUT_S" & wait $!; : > "$mark"; pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
watcher=$!
wait "$pid" 2>/dev/null; rc=$?
# watcher 정리 — compound stderr 억제 (job-control "Terminated" 메시지 누수 차단)
{ kill "$watcher" 2>/dev/null; pkill -P "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null; } 2>/dev/null || true

if [ -f "$mark" ]; then
  echo "CRITIC: FAIL (timeout ${TIMEOUT_S}s)"
  head -1 "$err_f" >&2 2>/dev/null || true
  exit 0
fi
if [ "$rc" -ne 0 ] || [ ! -s "$out_f" ]; then
  echo "CRITIC: FAIL (provider rc=$rc)"
  head -1 "$err_f" >&2 2>/dev/null || true
  exit 0
fi
echo "CRITIC[$provider]:"
cat "$out_f"
exit 0
