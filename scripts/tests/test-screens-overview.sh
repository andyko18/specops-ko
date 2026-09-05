#!/usr/bin/env bash
# test-screens-overview.sh — 화면 목록 마스터 대조·동기화 판정기 계약
# 실 screens/·마스터 미변경 — tmpdir 픽스처로 결정적 검증 (test-check-screen-quality.sh 선례)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN=$(cd "$PLUGIN/.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-screens-overview.sh"

_fixture() {  # $1=dir — 마스터(fence 안 2 + fence 밖 유령 1) + screens 2개
  mkdir -p "$1/.specops/memory" "$1/screens"
  cat > "$1/.specops/memory/screens-overview.md" <<'EOF'
# 화면 목록 마스터
| name | 제목 | 목적 | 상세 | 미리보기 |
|---|---|---|---|---|
<!-- screens-table:start -->
| dashboard | 대시보드 | 메인 | [x](y) | [x](y) |
| settings | 설정 | 환경 | [x](y) | [x](y) |
<!-- screens-table:end -->

작성 예시 (표 밖 — 실데이터 아님):
| ghost-example | 유령 | 세면 안 됨 | [x](y) | [x](y) |
EOF
  : > "$1/screens/dashboard.md"; : > "$1/screens/login.md"
}
_run() { SPECOPS_SCREENS_OVERVIEW="$2/.specops/memory/screens-overview.md" \
         SPECOPS_SCREENS_DIR="$2/screens" bash "$CHK" "$1" 2>&1; }

# S1: list 가 fence 안 2개만 (유령 행 제외 — 07ef42e 재발 방지)
d=$(mktemp -d); _fixture "$d"
out=$(_run list "$d")
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "2" ] && ! printf '%s' "$out" | grep -q 'ghost-example' \
  && ok "S1 list 가 fence 안 2개만 (유령 제외)" || nope "S1" "out=$out"

# S2: diff 가 양방향 차집합 + DIFF 요약, rc=0
out=$(_run diff "$d"); rc=$?
printf '%s' "$out" | grep -q 'MASTER-ONLY: settings' \
  && printf '%s' "$out" | grep -q 'SCREENS-ONLY: login' \
  && printf '%s' "$out" | grep -q 'SCREENS-OVERVIEW: DIFF' && [ "$rc" -eq 0 ] \
  && ok "S2 diff 양방향 + rc=0" || nope "S2" "rc=$rc out=$out"

# S3: sync 가 실제로 행을 추가한다 (added 보고만 하고 안 쓰는 결함 차단)
_run sync "$d" >/dev/null
after=$(_run list "$d")
printf '%s' "$after" | grep -qx 'login' \
  && ok "S3 sync 가 마스터에 실제 기록" || nope "S3" "after=$after"

# S4: sync 멱등 — 2회차 added=0, 행 수 불변
n1=$(_run list "$d" | wc -l | tr -d ' ')
out=$(_run sync "$d"); n2=$(_run list "$d" | wc -l | tr -d ' ')
printf '%s' "$out" | grep -q 'added=0' && [ "$n1" = "$n2" ] \
  && ok "S4 sync 멱등 (added=0 · 행수 $n1 유지)" || nope "S4" "out=$out n1=$n1 n2=$n2"

# S5: fence 밖 무접촉
grep -q 'ghost-example' "$d/.specops/memory/screens-overview.md" \
  && grep -q '^# 화면 목록 마스터' "$d/.specops/memory/screens-overview.md" \
  && ok "S5 fence 밖 무접촉" || nope "S5" "fence 밖 손상"
rm -rf "$d"

# S6: 마스터 부재 → 3모드 전부 SKIP·rc=0 (미부트스트랩 batch 차단 금지)
e=$(mktemp -d); mkdir -p "$e/screens"
r=0
for m in list diff sync; do
  SPECOPS_SCREENS_OVERVIEW="$e/none.md" SPECOPS_SCREENS_DIR="$e/screens" bash "$CHK" "$m" >/dev/null 2>&1 || r=1
done
[ "$r" -eq 0 ] && ok "S6 마스터 부재 3모드 rc=0" || nope "S6" "rc!=0"
rm -rf "$e"

# S7: ★ env 없이 cwd 기본 경로로 동작하는가 (C1 — 하류 repo 영구 no-op 차단)
#   S1~S6 은 전부 env 로 경로를 주입하므로 **기본 경로가 틀려도 통과한다**.
#   실측(되돌려-관찰): 기본 경로를 플러그인 설치 루트로 되돌리면
#     S7 = list 0줄 FAIL(격추 ✓) · S1 = list 2줄 PASS(못 잡음 ✗).
#   즉 이 축이 C1 을 잡는 **유일한** 어서션이다. 지우지 마라.
g=$(mktemp -d); _fixture "$g"
out=$( cd "$g" && env -u SPECOPS_SCREENS_OVERVIEW -u SPECOPS_SCREENS_DIR bash "$CHK" list 2>&1 )
[ "$(printf '%s\n' "$out" | grep -c .)" = "2" ] \
  && ok "S7 env 없이 cwd 기본 경로로 마스터를 찾는다" || nope "S7" "out=$out"
rm -rf "$g"

finish
