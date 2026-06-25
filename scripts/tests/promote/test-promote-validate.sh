#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
H="$PLUGIN/scripts/promote-validate.sh"
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

# T0a: fid=".." → REJECT:bad-format (경로 traversal 방어)
out=$(bash "$H" ".." 2>/dev/null)
[ "$out" = "REJECT:bad-format" ] && { PASS=$((PASS+1)); echo "PASS T0a bad-format(..)"; } || { FAIL=$((FAIL+1)); echo "FAIL T0a ($out)"; }

# T0b: fid="../x" → REJECT:bad-format
out=$(bash "$H" "../x" 2>/dev/null)
[ "$out" = "REJECT:bad-format" ] && { PASS=$((PASS+1)); echo "PASS T0b bad-format(../x)"; } || { FAIL=$((FAIL+1)); echo "FAIL T0b ($out)"; }

# T1: 인자 없음 → REJECT:usage
out=$(bash "$H" 2>/dev/null)
[ "$out" = "REJECT:usage" ] && { PASS=$((PASS+1)); echo "PASS T1 usage"; } || { FAIL=$((FAIL+1)); echo "FAIL T1 ($out)"; }

# T2: 디렉토리 없음 → REJECT:no-dir
out=$(bash "$H" 20260625-nope 2>/dev/null)
[ "$out" = "REJECT:no-dir" ] && { PASS=$((PASS+1)); echo "PASS T2 no-dir"; } || { FAIL=$((FAIL+1)); echo "FAIL T2 ($out)"; }

# T3: freework.md 없음 → REJECT:not-mini-fid
mkdir -p "$TMP/.specops/20260625-plain"
out=$(bash "$H" 20260625-plain 2>/dev/null)
[ "$out" = "REJECT:not-mini-fid" ] && { PASS=$((PASS+1)); echo "PASS T3 not-mini-fid"; } || { FAIL=$((FAIL+1)); echo "FAIL T3 ($out)"; }

# T4: spec.md 이미 존재 → REJECT:already-promoted
mkdir -p "$TMP/.specops/20260625-done"
: > "$TMP/.specops/20260625-done/freework.md"
: > "$TMP/.specops/20260625-done/spec.md"
out=$(bash "$H" 20260625-done 2>/dev/null)
[ "$out" = "REJECT:already-promoted" ] && { PASS=$((PASS+1)); echo "PASS T4 already-promoted"; } || { FAIL=$((FAIL+1)); echo "FAIL T4 ($out)"; }

# T5: freework.md 있고 spec.md 없음 → OK
mkdir -p "$TMP/.specops/20260625-mini"
: > "$TMP/.specops/20260625-mini/freework.md"
out=$(bash "$H" 20260625-mini 2>/dev/null)
[ "$out" = "OK" ] && { PASS=$((PASS+1)); echo "PASS T5 OK"; } || { FAIL=$((FAIL+1)); echo "FAIL T5 ($out)"; }

# T6: promote.md frontmatter + 헬퍼 호출 + 거부 문구 (AC-1,4,12)
CMD="$PLUGIN/commands/promote.md"
if [ -f "$CMD" ] && grep -q 'name: promote' "$CMD" \
   && grep -q 'promote-validate.sh' "$CMD" \
   && grep -q 'promote-fid' "$CMD" \
   && grep -q 'entry: maintain' "$CMD"; then
  PASS=$((PASS+1)); echo "PASS T6 promote.md 규약"
else
  FAIL=$((FAIL+1)); echo "FAIL T6 promote.md"
fi

# T7: analyzing-ko Step 0 promote-fid 분기 지시 존재 (AC-5,6,11)
ANA="$PLUGIN/skills/analyzing-ko/SKILL.md"
if grep -q 'promote-fid' "$ANA" && grep -q 'freework.md' "$ANA" \
   && grep -q 'git diff HEAD' "$ANA"; then
  PASS=$((PASS+1)); echo "PASS T7 analyzing promote-fid 분기"
else
  FAIL=$((FAIL+1)); echo "FAIL T7 analyzing 분기"
fi

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
