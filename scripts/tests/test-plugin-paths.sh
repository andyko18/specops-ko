#!/usr/bin/env bash
# check-plugin-paths.sh — 프롬프트 속 plugin 상대 경로 실행 지시 적발 (20261008)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-plugin-paths.sh"

# P1: 실제 트리는 깨끗하다(회귀 잠금)
out=$(bash "$CHK" "$PLUGIN" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "P1 실 트리 깨끗" || nope "P1" "rc=$rc out=$out"

_fx() {  # $1=상대경로 $2=내용 → 샌드박스 루트 출력
  local d; d=$(mktemp -d); mkdir -p "$d/$(dirname "$1")" "$d/skills" "$d/agents" "$d/commands" "$d/templates"
  printf '%s\n' "$2" > "$d/$1"; printf '%s' "$d"
}
# P2: 맨몸 `bash hooks/…` → 위반
d=$(_fx skills/x-ko/SKILL.md 'run: `bash hooks/rotate.sh a`'); out=$(bash "$CHK" "$d" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'x-ko/SKILL.md' && ok "P2 bash hooks/ 맨몸 → FAIL" || nope "P2" "rc=$rc"
rm -rf "$d"
# P3: `source scripts/…` 맨몸 → 위반
d=$(_fx agents/a.md 'x
      source scripts/dag/parse-dag.sh'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "P3 source scripts/ 맨몸 → FAIL" || nope "P3" "rc=$rc"
rm -rf "$d"
# P4: CLAUDE_PLUGIN_ROOT 접두 → 통과
d=$(_fx skills/x-ko/SKILL.md 'run: `bash "${CLAUDE_PLUGIN_ROOT}"/hooks/rotate.sh a`'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P4 CLAUDE_PLUGIN_ROOT 접두 → OK" || nope "P4" "rc=$rc"
rm -rf "$d"
# P5: 설명용 언급(실행 지시 아님)은 대상 아님
d=$(_fx skills/x-ko/SKILL.md '판정 SoT = `scripts/_internal/check-x.sh` 가 한다'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P5 설명용 경로 언급은 통과" || nope "P5" "rc=$rc"
rm -rf "$d"
# P6: 허용 목록(release-ko·하류 테스트 명령 예시)은 통과
d=$(_fx skills/release-ko/SKILL.md 'bash scripts/release.sh'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P6a release-ko 허용" || nope "P6a" "rc=$rc"
rm -rf "$d"
d=$(_fx templates/CLAUDE.md '`bash scripts/tests/test-x.sh`'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P6b 하류 테스트 명령 예시 허용" || nope "P6b" "rc=$rc"
rm -rf "$d"

# ── 둘째 표면: 스크립트·훅이 출력하는 안내문 ──────────────────────────────
_sfx() {  # $1=상대경로 $2=내용 → 샌드박스 루트 출력 (프롬프트 디렉토리는 비워 둔다)
  local d; d=$(mktemp -d); mkdir -p "$d/$(dirname "$1")" "$d/skills" "$d/agents" "$d/commands" "$d/templates"
  printf '%s\n' "$2" > "$d/$1"; printf '%s' "$d"
}
# P7: 게이트의 해법 안내가 plugin 상대 경로 → 위반 (하류에는 그 파일이 없다)
d=$(_sfx scripts/_internal/check-x.sh 'echo "  해법: bash scripts/_internal/fix-x.sh <FID>"'); out=$(bash "$CHK" "$d" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'check-x.sh:1:' && ok "P7 스크립트 안내문 상대 경로 → FAIL" || nope "P7" "rc=$rc out=$out"
rm -rf "$d"
# P7b: heredoc 본문(echo 가 아닌 줄)도 같은 표면이다
d=$(_sfx hooks/h.sh 'cat <<EOF
  확인: bash scripts/_internal/list.sh --list
EOF'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "P7b heredoc 안내문 상대 경로 → FAIL" || nope "P7b" "rc=$rc"
rm -rf "$d"
# P8: 플러그인 루트 변수를 붙이면 통과
d=$(_sfx scripts/_internal/check-x.sh 'echo "  해법: bash \"$PLUGIN/scripts/_internal/fix-x.sh\" <FID>"'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P8 플러그인 루트 변수 접두 → OK" || nope "P8" "rc=$rc"
rm -rf "$d"
# P9: 주석 줄·하류 테스트 명령 예시는 대상 아님
d=$(_sfx scripts/a.sh '# 사용 예: bash scripts/a.sh <FID>
echo "test_command 를 bash scripts/tests/… 형태로 고치세요"'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P9 주석·테스트 명령 예시는 통과" || nope "P9" "rc=$rc"
rm -rf "$d"
# P10: plugin repo 에서만 도는 도구는 허용
d=$(_sfx scripts/release.sh 'echo "릴리즈 전 bash scripts/x.sh 권장"'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P10 release.sh 허용" || nope "P10" "rc=$rc"
rm -rf "$d"
# P10b: 하위 디렉토리의 스크립트도 본다 (init-project 계열이 안내문을 가장 많이 낸다)
d=$(_sfx scripts/_internal/init-project/lib.sh 'echo "해법: bash scripts/_internal/x.sh"'); out=$(bash "$CHK" "$d" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'init-project/lib.sh:1:' && ok "P10b 하위 디렉토리 스크립트 → FAIL" || nope "P10b" "rc=$rc out=$out"
rm -rf "$d"
# P10c: 테스트 트리는 대상 아님 (테스트는 plugin repo 에서만 돈다)
d=$(_sfx scripts/tests/test-x.sh 'echo "bash scripts/_internal/x.sh"'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "P10c scripts/tests/ 는 통과" || nope "P10c" "rc=$rc"
rm -rf "$d"
# P11: 들여쓴 주석이 아닌 줄의 `#` 뒤 문구는 주석이 아니다 — 출력 문자열 안의 `#` 를 주석으로 읽지 않는다
d=$(_sfx scripts/b.sh 'echo "# 해법: bash scripts/_internal/y.sh"'); bash "$CHK" "$d" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "P11 문자열 안의 # 는 주석 아님 → FAIL" || nope "P11" "rc=$rc"
rm -rf "$d"

finish
