#!/usr/bin/env bash
# redact.sh — 캡처 경로 단일 마스킹 관문 (stdin → stdout)
# Usage: redact.sh [--last-line] [--max N] < 입력 > 출력
# 처리 순서: oversize 대체 → private 구간·PEM 블록 제거(awk) → 패턴 치환(sed) → [--last-line 마지막 줄만] → [--max 절단(jq)]
# --last-line: 마스킹이 끝난 뒤 마지막 줄만 남긴다 — 줄 자르기가 마스킹보다 앞서면 여러 줄 private 구간의 여는 태그가 잘려 새어 나간다
# rc: 0 성공 · 2 인자 오류 · 3 마스킹 불가(stdout 비움 — 호출자는 원문을 저장하지 않는다)
# 한계: 정규식 마스킹은 일부만 잡는다 — 자유 서술형 비밀번호는 못 잡으므로 완전 보장이 아니다.
#       처리 중 원문이 $TMPDIR(0700 디렉토리)에 잠시 놓이고 trap 으로 지운다 — SIGKILL 이면 남을 수 있다(트랜스크립트 자체가 이미 원문을 디스크에 둔다).
# 성능: Stop 훅 hot path — 외부 프로세스 수를 줄이려 bash 내장을 쓴다(mktemp·cat·wc·tail·awk·sed·jq 만 띄운다).
set -u
umask 077   # 임시 파일은 소유자만 읽는다
case "${BASH_SOURCE[0]}" in */*) _src=${BASH_SOURCE[0]%/*} ;; *) _src=. ;; esac
DIR=$(cd "$_src" && pwd)
PATTERNS="$DIR/redact-patterns.sed"
OVERSIZE=1000000

MAX=""
LAST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="${2:-}"; shift 2 ;;
    --last-line) LAST=1; shift ;;
    *) echo "Usage: redact.sh [--last-line] [--max N]" >&2; exit 2 ;;
  esac
done
case "$MAX" in
  "") ;;
  *[!0-9]*) echo "redact: --max 는 숫자" >&2; exit 2 ;;
esac

[ -s "$PATTERNS" ] || { echo "redact: 패턴 파일 부재·빈 파일 — 마스킹 불가" >&2; exit 3; }
if [ -n "$MAX" ] && ! command -v jq >/dev/null 2>&1; then
  echo "redact: jq 부재 — --max 절단 불가" >&2; exit 3
fi

td=$(mktemp -d 2>/dev/null) || exit 3
trap 'rm -rf "$td"' EXIT
t1="$td/in"; t2="$td/mid"; t3="$td/out"
cat > "$t1" || exit 3

# oversize — 바이트가 상한 이하면 글자 수도 이하. 초과 시 jq 로 글자 수를 재고(부재 시 바이트로 보수 판정) 넘으면 스캔 없이 대체
bytes=$(wc -c < "$t1"); bytes=$((bytes))
if [ "$bytes" -gt "$OVERSIZE" ]; then
  chars=$bytes
  if [ "$bytes" -le 8000000 ] && command -v jq >/dev/null 2>&1; then
    chars=$(jq -Rs 'length' "$t1" 2>/dev/null) || chars=$bytes
  fi
  if [ "$chars" -gt "$OVERSIZE" ]; then printf '[REDACTED:oversize]'; exit 0; fi
fi

# 마지막 줄 개행 유무 보존용 — 끝 글자가 개행이면 $(tail -c1) 이 빈 문자열이 된다
nl=1; [ "$bytes" -gt 0 ] && [ -n "$(tail -c1 "$t1")" ] && nl=0

export LC_ALL=C
awk '
function emit(s) { out = out s }
BEGIN { inp = 0; pem = 0 }
{
  line = $0; out = ""; touched = 0
  while (length(line) > 0) {
    if (inp) {
      i = index(line, "</private>")
      if (i == 0) { line = ""; touched = 1 } else { line = substr(line, i + 10); inp = 0; touched = 1 }
    } else if (pem) {
      if (match(line, /-----END [A-Z ]*PRIVATE KEY-----/)) { line = substr(line, RSTART + RLENGTH); pem = 0 } else { line = "" }
      touched = 1
    } else {
      p = index(line, "<private>")
      k = 0; kl = 0
      if (match(line, /-----BEGIN [A-Z ]*PRIVATE KEY-----/)) { k = RSTART; kl = RLENGTH }
      if (p == 0 && k == 0) { emit(line); line = "" }
      else if (k == 0 || (p > 0 && p < k)) { emit(substr(line, 1, p - 1)); line = substr(line, p + 9); inp = 1; touched = 1 }
      else { emit(substr(line, 1, k - 1) "[REDACTED:pem]"); line = substr(line, k + kl); pem = 1; touched = 1 }
    }
  }
  if (out != "" || !touched) print out
}' "$t1" | sed -E -f "$PATTERNS" > "$t3"
# 파이프 전체의 실패를 잡는다 — awk 나 sed 가 실패하면 마스킹 불가(rc 3). PIPESTATUS 는 다음 명령에서 덮이므로 한 번에 복사한다
ps=("${PIPESTATUS[@]}")
[ "${ps[0]}" -eq 0 ] && [ "${ps[1]}" -eq 0 ] || { echo "redact: 구간 제거·패턴 치환 실패" >&2; exit 3; }
unset LC_ALL

res="$t3"
if [ "$LAST" -eq 1 ]; then tail -n 1 "$t3" > "$t2" || exit 3; res="$t2"; fi

# 입력 끝에 개행이 없었으면 출력 끝 개행도 없앤다($(…) 가 끝 개행을 지운다) — 평범한 입력의 바이트 보존
if [ "$nl" -eq 0 ]; then
  body=$(cat "$res") || exit 3
  if [ -n "$MAX" ]; then printf '%s' "$body" | jq -Rsj --argjson n "$MAX" 'if length > $n then .[0:$n] + "…[TRUNCATED]" else . end' || exit 3
  else printf '%s' "$body"; fi
elif [ -n "$MAX" ]; then
  jq -Rsj --argjson n "$MAX" 'if length > $n then .[0:$n] + "…[TRUNCATED]" else . end' "$res" || exit 3
else
  cat "$res"
fi
