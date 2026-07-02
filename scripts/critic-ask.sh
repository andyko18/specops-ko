#!/usr/bin/env bash
# 외부 모델 critic 위탁 래퍼 — advisory only (판정 권한 없음, provider 오류·timeout 도 exit 0)
# 사용: bash scripts/critic-ask.sh <prompt-file> [--files <f1> [f2 ...]]
# 환경: CRITIC_BIN (강제 provider — stdin 합성 프롬프트 / stdout 의견 계약) · CRITIC_TIMEOUT (기본 120s)
#       CRITIC_CLAUDE_MODEL (기본 fable) · CRITIC_CLAUDE_FALLBACK (기본 opus) — claude provider 모델 선택
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

# provider 감지: CRITIC_BIN > claude > codex > gemini > ollama (A-1)
# claude: advisor 백엔드 최우선 — claude code 사용자는 항상 보유. 모델은 fable 우선·opus fallback
#   (CRITIC_CLAUDE_MODEL / CRITIC_CLAUDE_FALLBACK 로 override). fable 접근 불가·overload 시 claude 내장
#   --fallback-model 이 opus 로 자동 전환 = "fable 존재하면 fable, 없으면 opus" 요구의 런타임 구현.
provider=""; bin=""
CLAUDE_MODEL="${CRITIC_CLAUDE_MODEL:-fable}"
CLAUDE_FALLBACK="${CRITIC_CLAUDE_FALLBACK:-opus}"
if [ -n "${CRITIC_BIN:-}" ]; then
  provider="custom"; bin="$CRITIC_BIN"
elif command -v claude >/dev/null 2>&1; then
  provider="claude"; bin="claude"
elif command -v codex >/dev/null 2>&1; then
  provider="codex"; bin="codex"
elif command -v gemini >/dev/null 2>&1; then
  provider="gemini"; bin="gemini"
elif command -v ollama >/dev/null 2>&1 && curl -sf -m 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
  provider="ollama"; bin="ollama"   # 로컬 — 외부 송신 0
else
  echo "CRITIC: SKIP (외부 CLI 부재)"
  exit 0
fi

syn=""; out_f=""; err_f=""; mark=""
cleanup() { rm -f "$syn" "$syn.cut" "$out_f" "$err_f" "$mark" 2>/dev/null; }
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
  if command -v iconv >/dev/null 2>&1; then
    # UTF-8 불완전 꼬리 바이트 제거 (iconv 부재 시 기존 동작 graceful)
    head -c "$MAX_BYTES" "$syn" | iconv -c -f UTF-8 -t UTF-8 > "$syn.cut"
  else
    head -c "$MAX_BYTES" "$syn" > "$syn.cut"
  fi
  mv "$syn.cut" "$syn"
  printf '\n[절단: 합성 %sB > %sB — 앞부분만 위탁]\n' "$size" "$MAX_BYTES" >> "$syn"
  echo "CRITIC: 절단 적용 (${size}B → ${MAX_BYTES}B)" >&2
fi

_invoke_provider() {
  # stdin=합성 프롬프트 → stdout=의견.
  # A-2 한계 고백: codex/gemini 플래그는 실측 미확인 (미설치 환경 작성) — 설치 후 본 함수만 보정
  case "$provider" in
    custom) "$bin" ;;
    claude) claude -p --model "$CLAUDE_MODEL" --fallback-model "$CLAUDE_FALLBACK" ;;
    codex)  codex exec - ;;
    gemini) gemini -p - ;;
    ollama) jq -Rs --arg m "${CRITIC_MODEL:-qwen2.5:7b}" '{model:$m, prompt:., stream:false}' \
              | curl -sS -m "$TIMEOUT_S" http://localhost:11434/api/generate -d @- \
              | jq -r '.response // empty' ;;
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
