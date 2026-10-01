#!/usr/bin/env bash
# redact.sh — 캡처 경로 단일 마스킹 관문 (stdin → stdout)
# Usage: redact.sh [--last-line] [--max N] < 입력 > 출력
# 처리 순서: oversize 대체 → private 구간·PEM 블록 제거(awk) → 패턴 치환(sed) → [--last-line 마지막 줄만] → [--max 절단(jq)]
# --last-line: 마스킹이 끝난 뒤 마지막 줄만 남긴다 — 줄 자르기가 마스킹보다 앞서면 여러 줄 private 구간의 여는 태그가 잘려 새어 나간다
# rc: 0 성공 · 2 인자 오류 · 3 마스킹 불가(stdout 비움 — 호출자는 원문을 저장하지 않는다)
# 한계: 정규식 마스킹은 일부만 잡는다 — 자유 서술형 비밀번호는 못 잡으므로 완전 보장이 아니다.
#       처리 중 원문이 임시 디렉토리(mktemp -d — macOS 는 TMPDIR 과 무관하게 사용자별 0700 디렉토리, umask 077)에 잠시 놓이고 trap 으로 지운다 — SIGKILL 이면 남을 수 있다(트랜스크립트 자체가 이미 원문을 디스크에 둔다).
#       NUL 바이트: BSD awk 는 NUL 이후 줄 내용을 버린다(gawk 는 보존) — 제거 방향이라 누출은 아니나 조용한 손실.
# 성능: Stop 훅 hot path — 외부 프로세스 수를 줄이려 bash 내장을 쓴다(mktemp·cat·wc·tail·awk·sed·jq 만 띄운다).
set -u
umask 077   # 임시 파일은 소유자만 읽는다
_src=${BASH_SOURCE[0]%/*}; [ "$_src" != "${BASH_SOURCE[0]}" ] || _src=.   # 슬래시 없는 호출(bash redact.sh)이면 현재 디렉토리
DIR=$(cd "$_src" && pwd)
PATTERNS="$DIR/redact-patterns.sed"
OVERSIZE=1000000

MAX=""
LAST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --max) [ $# -ge 2 ] || { echo "redact: --max 값 필요" >&2; exit 2; }; MAX="$2"; shift 2 ;;
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
# 구간 제거는 split 기반 선형 스캔 — 줄을 매번 substr 로 되복사하면 한 줄에 태그가 많을 때 이차 시간이 된다(실측: 8,000개 5.3초 · 32,000개 60초 초과).
# 출력은 printf 로 바로 내보낸다(문자열 이어붙임도 이차). 1단계 private 구간 → 2단계 PEM 블록 → sed 패턴 치환.
awk '
BEGIN { inp = 0 }
{
  n = split($0, a, "<private>"); outlen = 0; touched = 0
  for (k = 1; k <= n; k++) {
    seg = a[k]
    if (k > 1) { inp = 1; touched = 1 }
    if (inp) {
      i = index(seg, "</private>")
      if (i == 0) { touched = 1; continue }
      seg = substr(seg, i + 10); inp = 0; touched = 1
    }
    printf "%s", seg; outlen += length(seg)
  }
  if (outlen > 0 || !touched) printf "\n"
}' "$t1" | awk '
BEGIN { pem = 0 }
{
  n = split($0, a, /-----BEGIN [A-Z ]*PRIVATE KEY-----/); outlen = 0; touched = 0
  for (k = 1; k <= n; k++) {
    seg = a[k]
    if (k > 1) { if (!pem) { printf "[REDACTED:pem]"; outlen += 14 } pem = 1; touched = 1 }
    if (pem) {
      if (match(seg, /-----END [A-Z ]*PRIVATE KEY-----/)) { seg = substr(seg, RSTART + RLENGTH); pem = 0 } else { touched = 1; continue }
      touched = 1
    }
    printf "%s", seg; outlen += length(seg)
  }
  if (outlen > 0 || !touched) printf "\n"
}' | sed -E -f "$PATTERNS" > "$t3"
# 파이프 전체의 실패를 잡는다 — awk·awk·sed 중 하나라도 실패하면 마스킹 불가(rc 3). PIPESTATUS 는 다음 명령에서 덮이므로 한 번에 복사한다
ps=("${PIPESTATUS[@]}")
[ "${ps[0]}" -eq 0 ] && [ "${ps[1]}" -eq 0 ] && [ "${ps[2]}" -eq 0 ] || { echo "redact: 구간 제거·패턴 치환 실패" >&2; exit 3; }
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
