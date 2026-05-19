#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

run() {
  local desc="$1"; shift
  if "$@" 2>/dev/null; then PASS=$((PASS+1)); echo "PASS: $desc"
  else FAIL=$((FAIL+1)); echo "FAIL: $desc"; fi
}

# T1.a: SKILL.md 존재
run "T1.a SKILL.md 존재" \
  test -f "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T1.b: frontmatter 6 필드
T1_b() {
  local count
  count=$(grep -c "^name:\|^description:\|^layer:\|^reference_upstream:\|^specops_version:\|^used_by:" \
    "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md" 2>/dev/null || echo 0)
  [ "$count" -ge 6 ]
}
run "T1.b frontmatter 6 필드" T1_b

# T2.a: 800줄 임계값 언급
run "T2.a 800줄 임계값" \
  grep -q "800" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T2.b: split/책임 과부하 언급
run "T2.b split 권고 언급" \
  grep -q "split\|책임 과부하" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T3.a: 50줄 임계값 언급
run "T3.a 50줄 임계값" \
  grep -q "50" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T3.b: merge/과잉 분해 언급
run "T3.b merge 권고 언급" \
  grep -q "merge\|과잉 분해" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T4.a: deep/shallow 판정 언급
run "T4.a deep/shallow 판정" \
  grep -q "deep\|shallow" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T5.a: 권고 테이블 언급
run "T5.a 권고 테이블" \
  grep -q "권고\|테이블" "$PLUGIN/skills/improve-codebase-architecture-ko/SKILL.md"

# T6.a: commands/improve-arch.md 존재
run "T6.a commands/improve-arch.md 존재" \
  test -f "$PLUGIN/commands/improve-arch.md"

# T6.b: improve-codebase-architecture-ko 호출 언급
run "T6.b skill 호출 언급" \
  grep -q "improve-codebase-architecture-ko" "$PLUGIN/commands/improve-arch.md"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
