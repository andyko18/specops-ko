#!/usr/bin/env bash
# 키워드 중첩 스코어 기반 관련 인사이트 조회 — 토큰 0, 결정적
# 사용: bash scripts/gbrain-recall.sh "<질의 텍스트>" [--top N]   (기본 N=3)
# 환경: GBRAIN_FILE (기본 .specops/memory/learnings.jsonl)
# 출력: 스코어 ≥1 상위 N건 원본 jsonl (스코어 내림차순, 동점 시 후순 라인 = 최신 우선)
set -uo pipefail

# 한글 토큰 매칭용 UTF-8 로케일 보장 (Linux C 로케일 대비 — A-1, glibc C.utf8 표기 포함)
case "${LC_ALL:-${LANG:-}}" in
  *.UTF-8|*.utf8) ;;
  *) if locale -a 2>/dev/null | grep -qiE '^C\.(UTF-8|utf8)$'; then export LC_ALL=C.UTF-8; else export LC_ALL=en_US.UTF-8; fi ;;
esac

Q="${1:?질의 텍스트 required}"
TOP=3
if [ "${2:-}" = "--top" ]; then TOP="${3:?--top 값 required}"; fi
case "$TOP" in ''|*[!0-9]*) echo "--top 숫자 required" >&2; exit 1;; esac
FILE="${GBRAIN_FILE:-.specops/memory/learnings.jsonl}"
[ -f "$FILE" ] || exit 0

TAB=$(printf '\t')

# 단일 jq 패스: 라인별 검색 텍스트(tags+insight) 추출 — 깨진/비객체 라인은 빈 줄로 라인번호 보존 (FR-6)
# 단일 awk 패스: 토큰화(소문자·영숫자/한글 2자+) + 질의 교집합 스코어 → "score<TAB>lineno"
# 상위 N 선별은 awk NR<=n — head 조기 종료로 인한 sort SIGPIPE(rc=141) 방지
ranked=$(
  jq -Rr '(fromjson? | objects
    | ((((.tags // []) | join(" ")) + " " + (.insight // ""))) as $txt
    | (((.confidence // "") | if . == "high" then 3 elif . == "medium" then 2 elif . == "low" then 1 else 0 end)) as $cw
    | "\($cw)\t\($txt | gsub("\t";" "))") // "0\t"' "$FILE" |
  awk -F'\t' -v q="$Q" '
    function addtok(s, set,   i, n, p) {
      s = tolower(s)
      gsub(/[^a-z0-9가-힣]+/, " ", s)
      n = split(s, p, " ")
      for (i = 1; i <= n; i++) if (length(p[i]) >= 2) set[p[i]] = 1
    }
    BEGIN { addtok(q, qt) }
    { cw = $1 + 0; split("", lt); addtok($2, lt); score = 0; for (t in qt) if (t in lt) score++; if (score >= 1) print score "\t" cw "\t" NR }
  ' |
  sort -t"$TAB" -k1,1nr -k2,2nr -k3,3nr |
  awk -v n="$TOP" 'NR <= n { print $3 }'
)
[ -z "$ranked" ] && exit 0

# 선별 라인번호의 원본 jsonl 라인을 스코어 순서 그대로 출력 (AC-10: 원형 보존)
awk 'NR == FNR { ord[++k] = $1; want[$1] = 1; next }
     FNR in want { line[FNR] = $0 }
     END { for (i = 1; i <= k; i++) print line[ord[i]] }' \
  <(printf '%s\n' "$ranked") "$FILE"
