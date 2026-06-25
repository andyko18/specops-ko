#!/usr/bin/env bash
# requirements.md FR 표에 신규 FR 행을 안전하게 append.
# 자유작업(design-change) 반자동 승인형 연결용 — 호출 전 사용자 승인 전제.
# Usage: requirements-append-fr.sh <req-path> <desc> [--milestone M] [--priority P] [--spec S]
# 출력: APPENDED: FR-<N>  |  SKIP: 중복 (FR-<N>)   /   에러 시 exit 1
set -u

[ "$#" -ge 2 ] || { echo "Usage: $0 <req-path> <desc> [--milestone M] [--priority P] [--spec S]" >&2; exit 1; }

req="$1"; shift
desc="$1"; shift
milestone="M1"; priority="should"; spec="(TBD)"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --milestone) milestone="${2:-M1}"; shift 2 || exit 1 ;;
    --priority)  priority="${2:-should}"; shift 2 || exit 1 ;;
    --spec)      spec="${2:-(TBD)}"; shift 2 || exit 1 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -f "$req" ] || { echo "error: requirements 파일 없음 — $req" >&2; exit 1; }

# markdown 표 셀 보호: 개행→공백(표 행 분리 방지·멱등 보장) + | → \|(셀 구분자 오염 방지)
esc_desc=$(printf '%s' "$desc" | tr '\n' ' ' | sed 's/|/\\|/g')

# 멱등: 동일 desc 인 FR 행이 이미 있으면 skip
if grep -qF "| $esc_desc |" "$req"; then
  existing=$(grep -F "| $esc_desc |" "$req" | grep -oE 'FR-[0-9]+' | head -1)
  echo "SKIP: 중복 (${existing:-FR-?})"
  exit 0
fi

# 채번: 기존 FR-N 최대값 + 1
maxn=$(grep -oE 'FR-[0-9]+' "$req" | grep -oE '[0-9]+' | sort -n | tail -1)
maxn=${maxn:-0}
next=$((maxn + 1))

newrow="| FR-$next | $esc_desc | $milestone | $priority | $spec |"

# §2 FR 표의 마지막 FR 행 뒤에 삽입 (ENVIRON 전달 — awk dynamic regex/escape 회피)
ROW="$newrow" awk '
  /^\| FR-[0-9]+ \|/ { last_fr = NR }
  { lines[NR] = $0 }
  END {
    if (last_fr == 0) { exit 3 }   # FR 행 없음 — 표 미발견
    for (i = 1; i <= NR; i++) {
      print lines[i]
      if (i == last_fr) print ENVIRON["ROW"]
    }
  }
' "$req" > "$req.tmp"
rc=$?
if [ "$rc" -ne 0 ]; then
  rm -f "$req.tmp"
  echo "error: FR 표(| FR-N | ...) 미발견 — append 위치 없음" >&2
  exit 1
fi
mv "$req.tmp" "$req"

echo "APPENDED: FR-$next"
