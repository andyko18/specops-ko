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

# TR-9: Wave A — legacy 실행증거 implement 면제 폐지 (receipt 없으면 deny)
LGD=$(mktemp -d)
mkdir -p "$LGD/.specops/20260101-legacy"
printf '<!-- active-fid: 20260101-legacy -->\n## 20260101-legacy\n' > "$LGD/.specops/session-progress.md"
echo tasks > "$LGD/.specops/20260101-legacy/tasks.md"
out=$(cd "$LGD" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-pass.jsonl" \
  "Bash" 'git commit -m "feat: T1"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id=="R-1"' >/dev/null; then
  ok "TR-9 legacy exec 면제 폐지 → deny"
else
  nope "TR-9" "out=$out"
fi
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


# === AC-2 / AC-R-1: evidence.md 를 쓴 태스크가 다른 태스크의 receipt 경로를 닫지 않는다 ===
# 사고 재현(20260910-commit-scope-prelude): T4 가 14:39 evidence.md 작성 → T5(15:46)·T6(16:45)
#   커밋이 /verify(16:56) 이전이라 자기보고 앵커도 없어 전 경로 폐쇄 → BYPASS 2건.
# ★ 픽스처는 반드시 _setup_fid(이 파일 L15-33)를 쓴다. 손으로 만들면 세 곳이 조용히 깨진다
#   (plan-reviewer 실측): ① session-progress 부재 → detect_fid 빈값 → R-1 창 분기 **미진입**
#   ② tasks.md 에 test_command 부재 → record-task-receipt.sh:34 exit 1 → receipt 미기록
#   ③ `git add -A` 가 .specops/* 를 staged → check-task-receipt.sh staged⊄outputs → rc=1
_RWC=$(mktemp -d) || exit 1
_rwc_fid=20260910-rwc
_setup_fid "$_RWC" "$_rwc_fid"
printf 'updated\n' > "$_RWC/src/foo.sh"          # 커밋 가능한 변경 (clean tree 면 staged 공집합)
# ★ 사고 조건: evidence.md 는 있고 verify 는 아직 안 돌았다
#   (verification-state.json 부재 + RUN-VERIFICATION-RESULT 스탬프 없음 → vs::current = NOT_RUN)
printf '# 실험 관찰 기록\n변이 M1 격추\n' > "$_RWC/.specops/$_rwc_fid/evidence.md"
(cd "$_RWC" && git add src && bash "$REC" "$_rwc_fid" T1) >/dev/null 2>&1
out=$(cd "$_RWC" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-pass.jsonl" "Bash" 'git commit -m "fix: x (Task: T1)"')
if [ -z "$out" ]; then ok "T-rwc.a evidence.md 존재 + verify 미실행 → receipt 면제"
else nope "T-rwc.a" "창이 닫혔다: $out"; fi

# === AC-R-2: STALE 대조군 — verify PASS 후 코드 수정이면 유효 receipt 가 있어도 차단 ===
# 17f8617(20260828) 계약 보존 실증. 이 케이스가 면제되면 축 A 가 계약을 약화시킨 것이다.
# ★ verification-state.json 을 손으로 쓰지 않는다 — SoT 스크립트로 기록해야 tree_hash 가 실물이다
#   (손으로 쓴 빈/가짜 해시는 vs::current 가 STALE 검사를 skip 해 픽스처가 항상 통과한다 — 리뷰어 실측).
(cd "$_RWC" && SPECOPS_ROOT=.specops bash "$PLUGIN/scripts/_internal/verification-state.sh" \
   record "$_rwc_fid" PASS --executed 1 --failed 0) >/dev/null 2>&1
printf 'stale-inducing edit\n' >> "$_RWC/src/foo.sh"      # ← 기록 이후 코드 변경 → STALE
_rwc_v=$(cd "$_RWC" && SPECOPS_ROOT=.specops bash "$PLUGIN/scripts/_internal/verification-state.sh" current "$_rwc_fid")
[ "$_rwc_v" = "STALE" ] || nope "T-rwc.b-pre" "픽스처가 STALE 이 아니다: $_rwc_v"
(cd "$_RWC" && git add src && bash "$REC" "$_rwc_fid" T1) >/dev/null 2>&1   # receipt 는 유효하게 갱신
out=$(cd "$_RWC" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-pass.jsonl" "Bash" 'git commit -m "fix: x (Task: T1)"')
if [ -n "$out" ]; then ok "T-rwc.b STALE → 유효 receipt 여도 차단(17f8617 계약 보존)"
else nope "T-rwc.b" "STALE 인데 면제됨 — 계약 약화"; fi

# === PASS(신선) 대조군 — 창이 닫히고 자기보고 경로로 넘어간다 ===
# 위 STALE 편집 이후 다시 record 하면 현재 트리 지문이 기록돼 신선 PASS 가 된다.
(cd "$_RWC" && SPECOPS_ROOT=.specops bash "$PLUGIN/scripts/_internal/verification-state.sh" \
   record "$_rwc_fid" PASS --executed 1 --failed 0) >/dev/null 2>&1
_rwc_v=$(cd "$_RWC" && SPECOPS_ROOT=.specops bash "$PLUGIN/scripts/_internal/verification-state.sh" current "$_rwc_fid")
[ "$_rwc_v" = "PASS" ] || nope "T-rwc.c-pre" "픽스처가 신선 PASS 가 아니다: $_rwc_v"
out=$(cd "$_RWC" && apply_lookback_rule "$rule_r1" "$FIX/exec-evidence-pass.jsonl" "Bash" 'git commit -m "fix: x (Task: T1)"')
if [ -z "$out" ]; then ok "T-rwc.c verify PASS 신선 → 자기보고 경로로 면제(창 닫힘)"
else nope "T-rwc.c" "PASS 신선인데 차단: $out"; fi
rm -rf "$_RWC"

# ── 파일 클래스 구분 (20260912-verify-stale-docs-scope) ──────────────────────
# receipt 는 verify 창이 닫혔을 때의 유일한 통로다 — 지문과 같은 맹점을 함께 푼다.
# ★ 양성 대조군 **쌍** 필수: 문서=유효 ∧ 코드=거부. 한쪽만 두면 분류기를 비워도 통과한다.
_RD=$(mktemp -d) || exit 1
_rd_fid=20260912-rcpt
_setup_fid "$_RD" "$_rd_fid"
mkdir -p "$_RD/.claude-plugin"
printf '{"name":"x"}\n' > "$_RD/.claude-plugin/plugin.json"
printf 'doc\n' > "$_RD/CHANGELOG.md"
(cd "$_RD" && git add -A && git -c user.name=t -c user.email=t@e.com commit -qm doc) >/dev/null 2>&1
printf 'updated\n' > "$_RD/src/foo.sh"
(cd "$_RD" && bash "$REC" "$_rd_fid" T1) >/dev/null 2>&1

# TR-D1 문서 전용 변경 후에도 receipt 유효 (AC-7)
printf 'doc changed\n' > "$_RD/CHANGELOG.md"
(cd "$_RD" && git add src scripts) >/dev/null 2>&1
if (cd "$_RD" && bash "$CHK" "$_rd_fid" T1) >/dev/null 2>&1; then
  ok "TR-D1 문서 변경 후 receipt 유효"
else
  nope "TR-D1 문서 변경 후 receipt 유효" "tree stale 로 거부됨"
fi

# TR-D2 코드 변경 후에는 거부 (양성 대조)
printf 'code changed\n' > "$_RD/src/foo.sh"
if (cd "$_RD" && bash "$CHK" "$_rd_fid" T1) >/dev/null 2>&1; then
  nope "TR-D2 코드 변경 후 receipt 거부" "통과해버림"
else
  ok "TR-D2 코드 변경 후 receipt 거부"
fi

# TR-D3 구버전 receipt(nondoc_hash 부재) → 종전 전체 지문 비교로 떨어진다 (AC-7 검증방법 3항)
# ★ 부재 시 방향이 **더 엄격한 쪽**이어야 한다 — 문서 변경만으로도 거부되는 것이 정상이다.
#   이 케이스가 없으면 "하위 호환" 주장이 무잠금이고, 필드를 안 읽는 구현으로 퇴행해도 통과한다.
jq 'del(.nondoc_hash)' "$_RD/.specops/$_rd_fid/receipts/T1.json" > "$_RD/rc.tmp" \
  && mv "$_RD/rc.tmp" "$_RD/.specops/$_rd_fid/receipts/T1.json"
printf 'code\n' > "$_RD/src/foo.sh"          # 코드 원복 — 문서 변경만 남긴다
printf 'doc changed twice\n' > "$_RD/CHANGELOG.md"
if (cd "$_RD" && bash "$CHK" "$_rd_fid" T1) >/dev/null 2>&1; then
  nope "TR-D3 구버전 receipt → 종전 동작(더 엄격)" "문서 변경인데 통과 — 하위 호환이 느슨한 쪽"
else
  ok "TR-D3 구버전 receipt → 종전 동작(더 엄격)"
fi
rm -rf "$_RD"

finish
