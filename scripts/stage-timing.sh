#!/usr/bin/env bash
# stage-timing.sh — session-progress 원장을 FID 간 단계별 소요로 집계한다 (읽기 전용 관측)
# Usage: bash scripts/stage-timing.sh [--since YYYYMMDD] [--gap-cap-min N] [--min-n N]
# rc: 0 = 집계 성공(구간 0건이어도 그 사실을 표시) · 2 = 원장 부재·읽기 불가·잘못된 인자
#
# 원장 규약: "## FID" 섹션 아래 "- YYYY-MM-DD HH:MM /cmd 상태 (...)" 행 (시각 = 로컬 · 분 해상도 — session-progress-append.sh).
# FID 단위 단계 소요는 show-fid-status.sh(/status)가 이미 낸다 — 이 스크립트는 FID 간 분포만 더한다.
# 행 단위 루프에서 외부 프로세스를 띄우지 않는다 — sort 1회 + awk 2회(일수 산술)로 끝낸다.
set -u
# 프로토타입은 한글이 섞인 단계 키를 sort 하다 로케일(en_US.UTF-8)에 따라 그룹이 갈라져 표가 뒤섞였다(실측).
# 이 스크립트의 sort 키는 ASCII FID·숫자뿐이지만, awk 의 단계 이름 비교(동률 정렬)는 로케일을 따라 달라진다 —
# 비교 규칙을 바이트 순으로 고정한다(T1.g 가 잠근다).
export LC_ALL=C

SPECOPS="${SPECOPS_ROOT:-.specops}"
LEDGER="$SPECOPS/session-progress.md"
SINCE=0; CAP=720; MINN=1

die() { echo "stage-timing: $1" >&2; exit 2; }
need_val() { [ "$#" -ge 2 ] && [ -n "${2:-}" ] || die "$1 값 필요"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      need_val "$@"
      printf '%s' "$2" | grep -qE '^[0-9]{8}$' || die "--since 는 YYYYMMDD 여야 합니다: $2"
      SINCE="$2"; shift 2 ;;
    --gap-cap-min)
      need_val "$@"
      printf '%s' "$2" | grep -qE '^[1-9][0-9]*$' || die "--gap-cap-min 은 1 이상의 정수여야 합니다: $2"
      CAP="$2"; shift 2 ;;
    --min-n)
      need_val "$@"
      printf '%s' "$2" | grep -qE '^[1-9][0-9]*$' || die "--min-n 은 1 이상의 정수여야 합니다: $2"
      MINN="$2"; shift 2 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

{ [ -f "$LEDGER" ] && [ -r "$LEDGER" ]; } || die "원장 없음 또는 읽기 불가: $LEDGER"

TAB=$(printf '\t')

# 1단계: 원장 행 → "FID·분·줄번호·단계키·날짜"(탭 구분). 날짜는 일수 산술로 분으로 바꾼다.
#   (BSD awk 에는 mktime 이 없다.) 로컬 시각 그대로 쓴다 — 인접 차이는 오프셋이 상쇄된다.
# 2단계: FID·시각순 정렬. 동일 분은 줄번호 내림차순 — 섹션은 최신 우선이라 줄이 아래일수록 먼저 일어난 일이다.
# 3단계: 인접 차이를 도착 행의 단계에 귀속해 집계한다.
awk '
function dn(y, m, d,   yy, mm) {
  yy = y - (m <= 2); mm = m + (m <= 2 ? 12 : 0)
  return 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + int((153 * (mm - 3) + 2) / 5) + d
}
/^## / { fid = ($2 ~ /^[0-9]+-[a-z0-9-]+$/) ? $2 : ""; next }
/^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] \/[a-z-]+/ {
  if (fid == "") next
  split($2, D, "-"); split($3, T, ":")
  printf "%s\t%d\t%d\t%s\t%s%s%s\n", fid, dn(D[1] + 0, D[2] + 0, D[3] + 0) * 1440 + (T[1] + 0) * 60 + (T[2] + 0), NR, $4 " " $5, D[1], D[2], D[3]
}' "$LEDGER" \
| sort -t "$TAB" -k1,1 -k2,2n -k3,3nr \
| awk -v ledger="$LEDGER" -v since="$SINCE" -v cap="$CAP" -v minn="$MINN" '
function isort(a, n,   i, j, t) {
  for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t }
}
function qn(a, n, p,   i) {   # nearest-rank: ceil(p% * n)
  i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n
  return a[i]
}
BEGIN { FS = "\t" }
{
  rows[$1]++
  if ($1 == pf) {
    d = $2 - pm
    if ($5 + 0 >= since + 0) {
      if (d > cap) { gapn++; gaps += d }
      else { n[$4]++; v[$4, n[$4]] = d; sum[$4] += d; total += d; cnt++ }
    }
  }
  pf = $1; pm = $2
}
END {
  for (f in rows) { fidn++; if (rows[f] == 1) single++ }
  printf "=== 단계별 소요 집계 (stage-timing) ===\n"
  printf "측정: 완료시각 인접 차이 · 분 해상도(0 = 1분 미만) · 사람 대기 포함 경과 시간(작업량 아님)\n"
  printf "      FID 경계 미교차 · 도착 행의 단계에 귀속 · DST·타임존 변경 경계 ±60분 오차 가능\n"
  printf "원장: %s · FID %d개 · 구간 %d건(통계 %d · 방치 제외 %d) · 방치 상한 %d분 · since %s\n\n", ledger, fidn + 0, cnt + gapn, cnt + 0, gapn + 0, cap, (since + 0 > 0 ? since : "없음")
  if (cnt == 0) {
    printf "집계할 구간 없음 — 통계에 들어갈 인접 행 쌍이 한 건도 없습니다(원장 부재가 아니라 구간 부재).\n"
  } else {
    nk = 0; for (k in n) keys[++nk] = k
    for (i = 1; i < nk; i++) {   # 합계 내림차순, 같으면 단계 이름 오름차순
      b = i
      for (j = i + 1; j <= nk; j++)
        if (sum[keys[j]] > sum[keys[b]] || (sum[keys[j]] == sum[keys[b]] && keys[j] < keys[b])) b = j
      t = keys[i]; keys[i] = keys[b]; keys[b] = t
    }
    # 머리행은 한글 표시 폭(글자당 2칸)을 손으로 맞춘 고정 문자열이다 — printf 폭은 바이트 기준이라 한글 열이 어긋난다.
    printf "   합계    비중     n  중앙값    p90    max  단계\n"
    for (r = 1; r <= nk; r++) {
      k = keys[r]; m = n[k]
      if (m < minn) { hidden++; continue }
      for (i = 1; i <= m; i++) tmp[i] = v[k, i]
      isort(tmp, m)
      printf "%7d %6.1f%% %5d %7d %6d %6d  %s\n", sum[k], (total > 0 ? sum[k] * 100 / total : 0), m, qn(tmp, m, 50), qn(tmp, m, 90), tmp[m], k
    }
  }
  printf "\n방치 구간 제외 %d건 (합 %d분) — 위 통계에 불포함\n", gapn + 0, gaps + 0
  if (minn > 1) printf "표 가림(--min-n %d) %d단계\n", minn, hidden + 0
  printf "FID 첫 행 %d개는 기준 행이 없어 집계에 없음 (행 1개뿐인 FID %d개)\n", fidn + 0, single + 0
}'
