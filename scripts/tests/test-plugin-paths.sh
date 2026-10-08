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

finish
