#!/usr/bin/env bash
# P0-2 태스크 receipt — 기록·게이트 판정
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
REC="$PLUGIN/scripts/_internal/record-task-receipt.sh"
CHK="$PLUGIN/scripts/_internal/check-task-receipt.sh"
source "$PLUGIN/hooks/governance-lib.sh"
rule_r1=$(jq -c 'select(.id == "R-1")' "$PLUGIN/hooks/rules.jsonl")
rule_r2=$(jq -c 'select(.id == "R-2")' "$PLUGIN/hooks/rules.jsonl")
FIX="$PLUGIN/scripts/tests/governance/fixtures/transcripts"

_setup_fid() {  # $1=dir $2=fid
  local d="$1" fid="$2"
  mkdir -p "$d/.specops/$fid" "$d/scripts/tests" "$d/src"
  printf 'echo ok\n' > "$d/scripts/tests/test-foo.sh"
  chmod +x "$d/scripts/tests/test-foo.sh"
  printf 'x\n' > "$d/src/foo.sh"
  cat > "$d/.specops/$fid/tasks.md" <<'EOF'
# tasks

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash scripts/tests/test-foo.sh"
    depends_on: []
    inputs: []
    outputs: [src/foo.sh, scripts/tests/test-foo.sh]
    ac: [AC-1]
```
EOF
  printf '<!-- active-fid: %s -->\n## %s\n- 2026-08-03 10:00 /implement DONE (T1)\n' "$fid" "$fid" \
    > "$d/.specops/session-progress.md"
  (cd "$d" && git init -q && git add src scripts && git -c user.name=t -c user.email=t@e.com commit -qm init)
}

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT
FID=20260803-receipt
_setup_fid "$TD" "$FID"

# 작업 트리에 커밋 가능한 변경을 만든 뒤 receipt를 찍는다 (clean tree면 staged 공집합).
printf 'updated\n' > "$TD/src/foo.sh"
printf 'echo ok\n' > "$TD/scripts/tests/test-foo.sh"

# TR-1: PASS 기록
(cd "$TD" && bash "$REC" "$FID" T1) >/dev/null
if [ -f "$TD/.specops/$FID/receipts/T1.json" ] \
   && jq -e '.verdict=="PASS" and .task=="T1" and (.outputs|length)==2' \
        "$TD/.specops/$FID/receipts/T1.json" >/dev/null; then
  ok "TR-1 PASS receipt 기록"
else
  nope "TR-1" "missing/invalid receipt"
fi

# TR-2: FAIL 테스트 → 기록 거부
printf 'exit 1\n' > "$TD/scripts/tests/test-foo.sh"
if (cd "$TD" && bash "$REC" "$FID" T1) >/dev/null 2>&1; then
  nope "TR-2" "FAIL 테스트가 receipt 기록됨"
else
  ok "TR-2 FAIL → 기록 거부"
fi
printf 'echo ok\n' > "$TD/scripts/tests/test-foo.sh"
(cd "$TD" && bash "$REC" "$FID" T1) >/dev/null

# TR-3: staged ⊆ outputs → check 0
(cd "$TD" && git add src/foo.sh scripts/tests/test-foo.sh)
if (cd "$TD" && bash "$CHK" "$FID" T1); then
  ok "TR-3 staged⊆outputs → 0"
else
  nope "TR-3" "rc=$?"
fi

# TR-4: staged 초과 → deny 1
printf 'extra\n' > "$TD/src/extra.sh"
(cd "$TD" && git add src/extra.sh)
if (cd "$TD" && bash "$CHK" "$FID" T1) >/dev/null 2>&1; then
  nope "TR-4" "초과 staged 허용"
else
  rc=$?; [ "$rc" -eq 1 ] && ok "TR-4 staged 초과 → 1" || nope "TR-4" "rc=$rc"
fi
(cd "$TD" && git reset -q HEAD -- src/extra.sh && rm -f src/extra.sh)
(cd "$TD" && bash "$REC" "$FID" T1) >/dev/null
(cd "$TD" && git add src/foo.sh scripts/tests/test-foo.sh)

# TR-5: tree stale → 1
printf 'dirty\n' >> "$TD/src/foo.sh"
if (cd "$TD" && bash "$CHK" "$FID" T1) >/dev/null 2>&1; then
  nope "TR-5" "stale tree 허용"
else
  rc=$?; [ "$rc" -eq 1 ] && ok "TR-5 tree stale → 1" || nope "TR-5" "rc=$rc"
fi
git -C "$TD" restore src/foo.sh
(cd "$TD" && bash "$REC" "$FID" T1) >/dev/null
(cd "$TD" && git add src/foo.sh scripts/tests/test-foo.sh)

# TR-6: test_command drift → 1
# tasks.md 의 test_command 변경
perl -pi -e 's/test-foo\.sh/test-foo.sh --x/' "$TD/.specops/$FID/tasks.md" 2>/dev/null \
  || sed -i '' 's/test-foo\.sh"/test-foo.sh --x"/' "$TD/.specops/$FID/tasks.md"
if (cd "$TD" && bash "$CHK" "$FID" T1) >/dev/null 2>&1; then
  nope "TR-6" "command drift 허용"
else
  rc=$?; [ "$rc" -eq 1 ] && ok "TR-6 command drift → 1" || nope "TR-6" "rc=$rc"
fi
# 복원
cat > "$TD/.specops/$FID/tasks.md" <<'EOF'
# tasks

## 의존 그래프

```yaml
tasks:
  - id: T1
    test_command: "bash scripts/tests/test-foo.sh"
    depends_on: []
    inputs: []
    outputs: [src/foo.sh, scripts/tests/test-foo.sh]
    ac: [AC-1]
```
EOF
(cd "$TD" && bash "$REC" "$FID" T1) >/dev/null
(cd "$TD" && git add src/foo.sh scripts/tests/test-foo.sh)

# TR-7: 부재 → 2
if (cd "$TD" && bash "$CHK" "$FID" T99) >/dev/null 2>&1; then
  nope "TR-7" "부재가 0"
else
  rc=$?; [ "$rc" -eq 2 ] && ok "TR-7 부재 → 2" || nope "TR-7" "rc=$rc"
fi

# TR-8: receipt 유효 → R-1 면제 (exec 증거 없어도)
out=$(cd "$TD" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-absent.jsonl" \
  "Bash" 'git commit -m "feat(T1): foo"')
[ -z "$out" ] && ok "TR-8 receipt → R-1 면제(exec 불요)" || nope "TR-8" "out=$out"

# TR-9: legacy implement 면제 회귀 (receipt 없는 다른 FID)
LGD=$(mktemp -d)
mkdir -p "$LGD/.specops/20260101-legacy"
printf '<!-- active-fid: 20260101-legacy -->\n## 20260101-legacy\n' > "$LGD/.specops/session-progress.md"
echo tasks > "$LGD/.specops/20260101-legacy/tasks.md"
out=$(cd "$LGD" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-pass.jsonl" \
  "Bash" 'git commit -m "feat: T1"')
[ -z "$out" ] && ok "TR-9 legacy implement 면제 유지" || nope "TR-9" "out=$out"
rm -rf "$LGD"

# TR-10: receipt 있어도 R-2는 열리지 않음
out=$(cd "$TD" && apply_lookback_rule "$rule_r2" "$FIX/exec-evidence-absent.jsonl" \
  "Bash" 'gh pr create --fill')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id=="R-2"' >/dev/null; then
  ok "TR-10 receipt로 R-2 미개방"
else
  nope "TR-10" "out=$out"
fi

# task 추론
hit=$(_infer_commit_task 'git commit -m "feat(T3): x"')
[ "$hit" = "T3" ] && ok "TR-11a infer T3" || nope "TR-11a" "hit=$hit"
hit=$(_infer_commit_task 'git commit -m "Task: T12 done"')
[ "$hit" = "T12" ] && ok "TR-11b infer Task: T12" || nope "TR-11b" "hit=$hit"

finish
