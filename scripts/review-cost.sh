#!/usr/bin/env bash
# review-cost.sh — plan-reviewer 비용·재dispatch 집계 (읽기 전용 관측)
# Usage: bash scripts/review-cost.sh [--since YYYYMMDD] [--predispatch-date YYYYMMDD] [--top N] [--transcript-dir DIR]
# rc: 0 = 집계 성공(행 0건·wall 측정 불가여도 그 사실을 표시) · 2 = $SPECOPS 부재·잘못된 인자
#
# 읽는 것: $SPECOPS/*/dispatch-log.md 의 plan-reviewer 구조화 행(필드 2=번호 · 4=단계 · 6=판정 · 7번째 칸부터 마지막 칸까지를 | 로 이은 비고에서 Critical/Important 숫자만),
#   $SPECOPS/session-progress.md 의 FID 섹션 행(plan 창), scripts/_internal/agent-spans.sh 출력(서브에이전트 wall·역할 — 숫자와 역할 이름뿐).
#   리뷰어 보고서 파일·프롬프트·transcript 본문은 읽지 않는다. 임시 파일에는 FID 이름과 정수만 쓴다.
# 라운드 = PASS·FAIL 행. 그 밖(ABORT·PROCEED·—·DEFERRED 등)은 "기타" 로 세고 분모에서 뺀다.
# wall 귀속: 원장의 FID 별 plan 창 [/clarify(없으면 /specify) 가장 이른 시각, /plan 가장 늦은 시각] 의 [-60초, +120초] 안에서 시작한
#   plan-reviewer 에이전트 중 후보 FID 가 정확히 1개인 것만 귀속한다(dispatch-log 행 시각은 추정치가 섞여 조인 키로 쓰지 않는다).
# 공유후보: transcript 디렉토리 해석(아래 TDIR 블록)은 stage-timing.sh 와 같은 규칙의 복제다 — 3번째 사용처가 생기기 전에 _internal 로 승격한다.
set -u
export LC_ALL=C

SPECOPS="${SPECOPS_ROOT:-.specops}"
LEDGER="$SPECOPS/session-progress.md"
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SINCE=0; PDATE=20260809; TOP=10; TDIR=""

die() { echo "review-cost: $1" >&2; exit 2; }
need_val() { [ "$#" -ge 2 ] && [ -n "${2:-}" ] || die "$1 값 필요"; }
is_date() { printf '%s' "$1" | grep -qE '^[0-9]{8}$'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since) need_val "$@"; is_date "$2" || die "--since 는 YYYYMMDD 여야 합니다: $2"; SINCE="$2"; shift 2 ;;
    --predispatch-date) need_val "$@"; is_date "$2" || die "--predispatch-date 는 YYYYMMDD 여야 합니다: $2"; PDATE="$2"; shift 2 ;;
    --top) need_val "$@"; printf '%s' "$2" | grep -qE '^[1-9][0-9]*$' || die "--top 은 1 이상의 정수여야 합니다: $2"; TOP="$2"; shift 2 ;;
    --transcript-dir) need_val "$@"; TDIR="$2"; shift 2 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

[ -d "$SPECOPS" ] || die "SPECOPS 디렉토리 없음: $SPECOPS"
if [ -n "$TDIR" ]; then [ -d "$TDIR" ] || die "--transcript-dir 가 디렉토리가 아닙니다: $TDIR"; fi

ROWSTMP=""; WINTMP=""; SPANTMP=""; WALLTMP=""
trap 'rm -f "$ROWSTMP" "$WINTMP" "$SPANTMP" "$WALLTMP"' EXIT
ROWSTMP=$(mktemp "${TMPDIR:-/tmp}/review-cost.XXXXXX") || die "임시 파일을 만들 수 없음"
WALLTMP=$(mktemp "${TMPDIR:-/tmp}/review-cost.XXXXXX") || die "임시 파일을 만들 수 없음"

# 1) dispatch-log 의 plan-reviewer 구조화 행 → "FID 탭 번호 탭 판정 탭 Critical 탭 Important" (기타는 판정 O)
LOGS=("$SPECOPS"/*/dispatch-log.md)
if [ -f "${LOGS[0]}" ]; then
  awk -F '|' '
  function numafter(s, key,   p, rest, k, c, num, L) {   # key 뒤 6글자 안의 첫 정수(첫 매치) — 없으면 -1. awk 간격 표현식을 쓰지 않는다
    while ((p = index(s, key)) > 0) {
      rest = substr(s, p + length(key)); L = length(rest)
      for (k = 1; k <= 7 && k <= L; k++) {
        c = substr(rest, k, 1)
        if (c ~ /[0-9]/) { num = ""; while (k <= L && substr(rest, k, 1) ~ /[0-9]/) { num = num substr(rest, k, 1); k++ } return num + 0 }
      }
      s = rest
    }
    return -1
  }
  FNR == 1 { n = split(FILENAME, P, "/"); fid = P[n - 1]; ok = (fid ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9-]+$/); seq = 0 }
  ok && /^\|/ && NF >= 7 && $4 ~ /plan-reviewer/ {
    v = $6; gsub(/\*/, "", v); gsub(/^ +/, "", v)
    w = ""; if (match(v, /^[A-Za-z]+/)) w = substr(v, 1, RLENGTH)
    seq++
    num = $2; gsub(/ /, "", num); if (num !~ /^[0-9]+$/) num = 1000000 + seq
    if (w == "PASS" || w == "FAIL") {
      c = -1; i = -1
      if (w == "FAIL") { note = $7; for (j = 8; j <= NF; j++) note = note "|" $j; c = numafter(note, "Critical"); i = numafter(note, "Important") }
      printf "%s\t%d\t%s\t%d\t%d\n", fid, num + 0, w, c, i
    } else printf "%s\t%d\tO\t-1\t-1\n", fid, num + 0
  }' "${LOGS[@]}" > "$ROWSTMP" 2>/dev/null || die "dispatch-log 파싱 실패"
fi

# >>> wall
# 2) wall(선택) — 사유가 있으면 WALL_NA 에 담고 라운드 집계는 그대로 낸다
WALL_NA=""
if ! command -v jq >/dev/null 2>&1; then
  WALL_NA="jq 없음"
elif [ ! -f "$LEDGER" ] || [ ! -r "$LEDGER" ]; then
  WALL_NA="원장 없음"
else
  WINTMP=$(mktemp "${TMPDIR:-/tmp}/review-cost.XXXXXX") || WALL_NA="임시 파일을 만들 수 없음"
  SPANTMP=$(mktemp "${TMPDIR:-/tmp}/review-cost.XXXXXX") || WALL_NA="임시 파일을 만들 수 없음"
fi
AG_FILES=(); MINDATE=""
if [ -z "$WALL_NA" ]; then
  # 원장 FID 섹션 행으로 plan 창(로컬 벽시계 초)을 만든다
  awk '
  function dn(y, m, d,   yy, mm) { yy = y - (m <= 2); mm = m + (m <= 2 ? 12 : 0); return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * (mm - 3) + 2) / 5) + d }
  /^## / { fid = ($2 ~ /^[0-9]+-[a-z0-9-]+$/) ? $2 : ""; next }
  /^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] \/[a-z-]+/ {
    if (fid == "") next
    split($2, D, "-"); split($3, T, ":")
    t = (dn(D[1] + 0, D[2] + 0, D[3] + 0) - dn(1970, 1, 1)) * 86400 + (T[1] + 0) * 3600 + (T[2] + 0) * 60
    if (min == "" || $2 < min) min = $2
    if ($4 == "/specify" && (sp[fid] == "" || t < sp[fid])) sp[fid] = t
    if ($4 == "/clarify" && (cl[fid] == "" || t < cl[fid])) cl[fid] = t
    if ($4 == "/plan" && (pl[fid] == "" || t > pl[fid])) pl[fid] = t
  }
  END {
    for (f in pl) { s = (cl[f] != "") ? cl[f] : sp[f]; if (s != "" && pl[f] >= s) printf "%s\t%d\t%d\n", f, s, pl[f] }
    if (min != "") print "#min\t" min
  }' "$LEDGER" > "$WINTMP" 2>/dev/null || WALL_NA="원장 파싱 실패"
  MINDATE=$(awk -F '\t' '$1 == "#min" { print $2 }' "$WINTMP")
  NWIN=$(awk -F '\t' '$1 != "#min" { n++ } END { print n + 0 }' "$WINTMP")
  if [ -z "$WALL_NA" ] && { [ -z "$MINDATE" ] || [ "$NWIN" = 0 ]; }; then WALL_NA="원장 plan 창 없음"; fi
fi
if [ -z "$WALL_NA" ]; then
  if [ -z "$TDIR" ]; then
    PROJ_ROOT="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/projects"
    ROOT_DIR=$(cd "$(dirname "$SPECOPS")" 2>/dev/null && pwd -P) || ROOT_DIR=""
    if [ -z "$ROOT_DIR" ]; then
      WALL_NA="원장 루트 경로를 해석할 수 없음 — --transcript-dir 로 지정하세요"
    else
      ENC_B=$(printf '%s' "$ROOT_DIR" | sed 's/[^A-Za-z0-9]/-/g'); ENC_C=""
      for LOC in C.UTF-8 en_US.UTF-8; do
        if [ "$(LC_ALL=$LOC locale charmap 2>/dev/null)" = "UTF-8" ]; then ENC_C=$(printf '%s' "$ROOT_DIR" | LC_ALL=$LOC sed 's/[^A-Za-z0-9]/-/g'); break; fi
      done
      if [ -d "$PROJ_ROOT/$ENC_B" ]; then TDIR="$PROJ_ROOT/$ENC_B"
      elif [ -n "$ENC_C" ] && [ -d "$PROJ_ROOT/$ENC_C" ]; then TDIR="$PROJ_ROOT/$ENC_C"
      else TDIR="$PROJ_ROOT/$ENC_B"; WALL_NA="transcript 디렉토리 없음: $TDIR — --transcript-dir 로 지정하세요"; fi
    fi
  fi
fi
if [ -z "$WALL_NA" ]; then
  # 서브에이전트 jsonl 중 meta 의 agentType 이 plan-reviewer-ko 인 것만 헬퍼로 읽는다(파싱량 1/10 — meta 는 작다)
  AG_RAW=$(find "$TDIR" -mindepth 3 -maxdepth 3 -type f -name 'agent-*.jsonl' -path '*/subagents/*' -newermt "$MINDATE" 2>/dev/null | sort)
  if [ -n "$AG_RAW" ]; then
    # 파일이 수천 개여도 인자 길이 한계에 걸리지 않게 xargs 로 나눠 grep 한다
    HIT_RAW=$(printf '%s\n' "$AG_RAW" | sed 's/\.jsonl$/.meta.json/' | tr '\n' '\0' | xargs -0 grep -lE '"agentType"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_.-]+:)?plan-reviewer-ko"' 2>/dev/null | sed 's/\.meta\.json$/.jsonl/' | sort)
    if [ -n "$HIT_RAW" ]; then
      OLD_IFS=$IFS; IFS='
'
      set -f
      # shellcheck disable=SC2206
      AG_FILES=($HIT_RAW)
      set +f; IFS=$OLD_IFS
    fi
  fi
  if [ "${#AG_FILES[@]}" -eq 0 ]; then
    WALL_NA="서브에이전트 파일 0개: $TDIR"
  elif ! bash "$SELF_DIR/_internal/agent-spans.sh" --local "${AG_FILES[@]}" > "$SPANTMP" 2>/dev/null; then
    WALL_NA="서브에이전트 transcript 를 읽을 수 없음"
  fi
fi
if [ -z "$WALL_NA" ]; then
  # 조인: 시작이 창 [-60, +120] 안인 후보 FID 가 정확히 1개면 귀속. --since 이전 FID 귀속은 제외하고 건수만 센다
  awk -F '\t' -v since="$SINCE" '
  FILENAME == ARGV[1] { if ($1 != "#min") { ws[$1] = $2 + 0; we[$1] = $3 + 0 } next }
  $8 !~ /(^|:)plan-reviewer-ko$/ { next }
  {
    st = $1 + 0; hit = 0; m = ""
    for (f in ws) if (st >= ws[f] - 60 && st <= we[f] + 120) { hit++; m = f }
    if (hit == 1) {
      if (since + 0 > 0 && substr(m, 1, 8) + 0 < since + 0) { skip++ }
      else { sec[m] += $3; cnt[m]++; uniq++; tot++ }
    } else if (hit > 1) { amb++; tot++ } else { unm++; tot++ }
  }
  END {
    for (f in cnt) printf "%s\t%d\t%d\n", f, sec[f], cnt[f]
    printf "#agents\t%d\t%d\t%d\t%d\t%d\n", tot + 0, uniq + 0, amb + 0, unm + 0, skip + 0
  }' "$WINTMP" "$SPANTMP" > "$WALLTMP" 2>/dev/null || WALL_NA="귀속 계산 실패"
fi
# <<< wall

# 3) 보고
WALL_NA_TEXT="$WALL_NA" awk -F '\t' -v since="$SINCE" -v pdate="$PDATE" -v top="$TOP" '
function pct(a, b) { return (b > 0) ? int(100 * a / b + 0.5) : 0 }
FILENAME == ARGV[1] {   # 라운드 행 (첫 파일이 비어 있어도 둘째 파일 줄이 섞이지 않게 FNR == NR 대신 파일 이름으로 가른다)
  if (since + 0 > 0 && substr($1, 1, 8) + 0 < since + 0) next
  fids[$1] = 1
  if ($3 == "O") { other++; next }
  nr[$1]++; k = nr[$1]; RN[$1, k] = $2 + 0; RW[$1, k] = $3; RC[$1, k] = $4 + 0; RI[$1, k] = $5 + 0
  next
}
{   # wall 행
  if ($1 == "#agents") { wt = $2; wu = $3; wa = $4; wm = $5; wsk = $6; haswall = 1; next }
  WS[$1] = $2 + 0; WN[$1] = $3 + 0; wmin += int($2 / 60 + 0.5)
}
END {
  for (f in nr) {
    n = nr[f]
    for (i = 2; i <= n; i++) { vn = RN[f, i]; vw = RW[f, i]; vc = RC[f, i]; vi = RI[f, i]; j = i - 1
      while (j >= 1 && RN[f, j] > vn) { RN[f, j + 1] = RN[f, j]; RW[f, j + 1] = RW[f, j]; RC[f, j + 1] = RC[f, j]; RI[f, j + 1] = RI[f, j]; j-- }
      RN[f, j + 1] = vn; RW[f, j + 1] = vw; RC[f, j + 1] = vc; RI[f, j + 1] = vi }
    nfid++; dist[n]++; tr += n
    if (n > maxn) maxn = n
    fw[f] = RW[f, 1]; lw[f] = RW[f, n]
    if (fw[f] == "FAIL") {
      ff++
      c = RC[f, 1]; ii = RI[f, 1]
      if (c >= 1) sev1++; else if (ii >= 1) sev2++; else if (c == 0 && ii == 0) sev3++; else sev4++
    }
    if (lw[f] == "PASS") lp++
    for (i = 1; i <= n; i++) if (RW[f, i] == "FAIL") {
      failrows++
      if (RC[f, i] >= 0) { csum += RC[f, i] }
      if (RI[f, i] >= 0) { isum += RI[f, i] }
      if (RC[f, i] >= 0 || RI[f, i] >= 0) readrows++
    }
    per = (substr(f, 1, 8) + 0 < pdate + 0) ? "pre" : "post"
    pn[per]++; pr[per] += n; if (fw[f] == "FAIL") pf[per]++
    mo = substr(f, 1, 6); mn[mo]++; if (fw[f] == "FAIL") mf[mo]++
  }
  printf "=== plan-reviewer 비용 (review-cost) ===\n"
  if (nfid == 0) { printf "plan-reviewer 행 없음 (PASS·FAIL 라운드 0건%s)\n", (other > 0 ? sprintf(" · 기타 행 %d건", other) : ""); exit }
  line = sprintf("FID %d개 · 라운드 분포", nfid)
  for (r = 1; r <= maxn; r++) if (dist[r] > 0) line = line sprintf(" %s%d회 %d", (r > 1 ? "· " : ""), r, dist[r])
  printf "%s — 평균 %.2f\n", line, tr / nfid
  printf "첫 라운드 FAIL %d/%d (%d%%)\n", ff + 0, nfid, pct(ff + 0, nfid)
  printf "마지막 판정 PASS %d/%d (%d%%)\n", lp + 0, nfid, pct(lp + 0, nfid)
  printf "FAIL 행 Critical 합 %d · Important 합 %d (숫자 읽힌 FAIL 행 %d/%d)\n", csum + 0, isum + 0, readrows + 0, failrows + 0
  if (ff == 0) printf "첫 라운드 FAIL 없음\n"
  else printf "첫 라운드 FAIL 심각도: Critical≥1 %d/%d (%d%%) · Important 만 %d/%d (%d%%) · 둘 다 0 %d/%d (%d%%) · 읽지 못함 %d/%d (%d%%)\n", sev1 + 0, ff, pct(sev1 + 0, ff), sev2 + 0, ff, pct(sev2 + 0, ff), sev3 + 0, ff, pct(sev3 + 0, ff), sev4 + 0, ff, pct(sev4 + 0, ff)
  split("pre post", PER, " ")
  for (q = 1; q <= 2; q++) { p = PER[q]; lab = (p == "pre") ? sprintf("도입 전(%s 미만)", pdate) : sprintf("도입 후(%s 이상)", pdate)
    if (pn[p] + 0 == 0) printf "도입 %s FID 0개 (%s %s)\n", (p == "pre") ? "전" : "후", pdate, (p == "pre") ? "미만" : "이상"
    else printf "%s: FID %d · 첫 라운드 FAIL %d (%d%%) · 평균 라운드 %.2f\n", lab, pn[p], pf[p] + 0, pct(pf[p] + 0, pn[p]), pr[p] / pn[p] }
  printf "월별 첫 라운드 FAIL (FID 이름 날짜 접두 기준 · 표본 n 병기)\n"
  nm = 0; for (m in mn) ml[++nm] = m
  for (i = 2; i <= nm; i++) { t = ml[i]; j = i - 1; while (j >= 1 && ml[j] > t) { ml[j + 1] = ml[j]; j-- } ml[j + 1] = t }
  for (i = 1; i <= nm; i++) printf "  %s  FID %d · 첫 라운드 FAIL %d (%d%%)\n", ml[i], mn[ml[i]], mf[ml[i]] + 0, pct(mf[ml[i]] + 0, mn[ml[i]])
  nu = 0
  if (ENVIRON["WALL_NA_TEXT"] != "") printf "wall 측정 불가(%s)\n", ENVIRON["WALL_NA_TEXT"]
  else if (haswall && wt + 0 == 0 && wsk + 0 == 0) printf "wall 측정 불가(시각 있는 서브에이전트 0개)\n"
  else if (haswall) {
    printf "wall: 에이전트 %d개 중 귀속 %d · 모호 %d · 미귀속 %d — FID 합 %d분 · 라운드당 평균 %.1f분%s\n", wt, wu, wa, wm, wmin + 0, (wu > 0 ? wmin / wu : 0), (wsk > 0 ? sprintf(" · since 이전 FID 귀속 %d개 제외", wsk) : "")
  }
  # 표: 라운드가 있는 FID ∪ wall 이 귀속된 FID
  for (f in nr) { rows[++nu] = f; seen[f] = 1 }
  for (f in WS) if (!(f in seen)) rows[++nu] = f
  for (i = 2; i <= nu; i++) { t = rows[i]; j = i - 1
    while (j >= 1) { a = rows[j]; ka = ((a in WS) ? WS[a] : 0); kb = ((t in WS) ? WS[t] : 0)   # wall 내림차순 → (wall 이 같거나 없으면) 라운드 내림차순 → FID 이름 내림차순
      if (ka < kb || (ka == kb && (nr[a] + 0 < nr[t] + 0 || (nr[a] + 0 == nr[t] + 0 && a < t)))) { rows[j + 1] = rows[j]; j-- } else break }
    rows[j + 1] = t }
  printf "\n비용 상위 %d개 FID (%s · 라운드 0 = dispatch-log 에 구조화 행 없음)\n", (top < nu ? top : nu), (haswall ? "wall 내림차순" : "wall 없음: 라운드 내림차순")
  printf "%-36s %6s %-5s %-5s %5s %5s %7s\n", "FID", "라운드", "첫", "끝", "Crit", "Imp", "wall분"
  for (i = 1; i <= nu && i <= top; i++) { f = rows[i]; n = nr[f] + 0
    c = 0; ii = 0; for (r = 1; r <= n; r++) if (RW[f, r] == "FAIL") { if (RC[f, r] >= 0) c += RC[f, r]; if (RI[f, r] >= 0) ii += RI[f, r] }
    printf "%-36s %6d %-5s %-5s %5d %5d %7s\n", f, n, (n > 0 ? fw[f] : "-"), (n > 0 ? lw[f] : "-"), c, ii, (f in WS ? sprintf("%d", int(WS[f] / 60 + 0.5)) : "-") }
  printf "\n기타 행 %d건 (PASS·FAIL 이 아닌 plan-reviewer 행 — 라운드·분모에서 제외)\n", other + 0
  printf "숫자 못 읽은 FAIL 행 %d건 (Critical·Important 둘 다 못 읽음)\n", failrows - readrows
  printf "표본 주의: 첫 라운드 FAIL 비율은 표본 n=%d 과 함께 읽을 것 · 도입 전후 비교는 FID 날짜 접두 기준의 관찰이며 인과가 아님(표본·플랜 복잡도 교란)\n", nfid
}' "$ROWSTMP" "$WALLTMP"
