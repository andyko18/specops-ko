#!/usr/bin/env bash
# P0-3 RELEASE_READY 합성 판정 — 0=READY · 1=NOT_READY · 2=UNKNOWN
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
RR="$PLUGIN/scripts/_internal/release-ready.sh"
STATE="$PLUGIN/scripts/_internal/verification-state.sh"

_mk_base() {  # $1=dir $2=fid → git + session-progress + tasks
  local d="$1" fid="$2"
  mkdir -p "$d/.specops/$fid/reviews" "$d/src"
  printf 'x\n' > "$d/src/a.sh"
  (cd "$d" && git init -q && git add src && git -c user.name=t -c user.email=t@e.com commit -qm init)
  printf '<!-- active-fid: %s -->\n## %s\n- 2026-08-03 10:00 /verify PASS\n- 2026-08-03 10:05 /receive-review DONE\n' \
    "$fid" "$fid" > "$d/.specops/session-progress.md"
  printf '# tasks\n' > "$d/.specops/$fid/tasks.md"
  # Wave A 구조화 audit 행 (경로 + B:T1/C:T1)
  cat > "$d/.specops/$fid/dispatch-log.md" <<'EOF'
| # | 시각 | Phase | agent | 결과 | feedback |
|---|---|---|---|---|---|
| 1 | ts | B:T1 | spec-reviewer-ko | PASS | reviews/T1-B-report.md |
| 2 | ts | C:T1 | code-reviewer-ko | PASS | reviews/T1-C-report.md |
EOF
  printf '# B report\nREADY_TO_MERGE\n' > "$d/.specops/$fid/reviews/T1-B-report.md"
  printf '# C report\nREADY_TO_MERGE\n' > "$d/.specops/$fid/reviews/T1-C-report.md"
}

_ev_gates() {  # $1=evidence path — 3게이트 PASS
  cat > "$1" <<'EOF'
RUN-VERIFICATION-RESULT: PASS

## /security-review PASS
**결과**: PASS

## /integration-test PASS
**결과**: PASS

## /performance-test SKIP
**결과**: SKIP
**근거**: NFR 없음 §spec L1
EOF
}

# RR-1: 전축 PASS
TD=$(mktemp -d); FID=20260803-rr-ok
_mk_base "$TD" "$FID"
_ev_gates "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -q 'RELEASE_READY: OK' \
  && ok "RR-1 전축 PASS → 0" || nope "RR-1" "rc=$rc out=$out"
rm -rf "$TD"

# RR-2: verify STALE
TD=$(mktemp -d); FID=20260803-rr-stale
_mk_base "$TD" "$FID"
_ev_gates "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf 'changed\n' >> "$TD/src/a.sh"
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'verify=STALE' \
  && ok "RR-2 STALE → 1" || nope "RR-2" "rc=$rc out=$out"
rm -rf "$TD"

# RR-3: security 섹션 부재
TD=$(mktemp -d); FID=20260803-rr-nosec
_mk_base "$TD" "$FID"
printf 'RUN-VERIFICATION-RESULT: PASS\n\n## /integration-test PASS\n**결과**: PASS\n\n## /performance-test SKIP\n**결과**: SKIP\n' \
  > "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'security=MISSING' \
  && ok "RR-3 security 부재 → 1" || nope "RR-3" "rc=$rc out=$out"
rm -rf "$TD"

# RR-4: performance SKIP 허용 (전축 그 외 PASS)
TD=$(mktemp -d); FID=20260803-rr-perfskip
_mk_base "$TD" "$FID"
_ev_gates "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -q 'performance=SKIP' \
  && ok "RR-4 performance SKIP 허용" || nope "RR-4" "rc=$rc out=$out"
rm -rf "$TD"

# RR-5: integration FAIL
TD=$(mktemp -d); FID=20260803-rr-intfail
_mk_base "$TD" "$FID"
cat > "$TD/.specops/$FID/evidence.md" <<'EOF'
RUN-VERIFICATION-RESULT: PASS
## /security-review PASS
**결과**: PASS
## /integration-test FAIL
**결과**: FAIL
## /performance-test SKIP
**결과**: SKIP
EOF
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'integration=FAIL' \
  && ok "RR-5 integration FAIL → 1" || nope "RR-5" "rc=$rc out=$out"
rm -rf "$TD"

# RR-6: reconcile DESYNC — session-progress 는 specify만, 증거는 verify/review
TD=$(mktemp -d); FID=20260803-rr-desync
_mk_base "$TD" "$FID"
_ev_gates "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf '<!-- active-fid: %s -->\n## %s\n- 2026-08-03 09:00 /specify DONE\n' \
  "$FID" "$FID" > "$TD/.specops/session-progress.md"
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'reconcile=DESYNC' \
  && ok "RR-6 DESYNC → 1" || nope "RR-6" "rc=$rc out=$out"
rm -rf "$TD"

# RR-7: review-audit FAIL — dispatch-log 가 없는 리포트 참조
TD=$(mktemp -d); FID=20260803-rr-audit
_mk_base "$TD" "$FID"
_ev_gates "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf '| reviews/T9-B-report.md |\n' > "$TD/.specops/$FID/dispatch-log.md"
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -q 'review=FAIL' \
  && ok "RR-7 review-audit FAIL → 1" || nope "RR-7" "rc=$rc out=$out"
rm -rf "$TD"

# RR-8: legacy — stamp/state 없음 → 2
TD=$(mktemp -d); FID=20260803-rr-legacy
mkdir -p "$TD/.specops/$FID"
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 2 ] && echo "$out" | grep -q 'UNKNOWN' \
  && ok "RR-8 legacy → 2" || nope "RR-8" "rc=$rc out=$out"
rm -rf "$TD"

# RR-9: security FAIL
TD=$(mktemp -d); FID=20260803-rr-secfail
_mk_base "$TD" "$FID"
cat > "$TD/.specops/$FID/evidence.md" <<'EOF'
RUN-VERIFICATION-RESULT: PASS
## /security-review FAIL
**결과**: FAIL
## /integration-test PASS
**결과**: PASS
## /performance-test SKIP
**결과**: SKIP
EOF
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
out=$(cd "$TD" && bash "$RR" "$FID" 2>&1); rc=$?
[ "$rc" -eq 1 ] && echo "$out" | grep -qE 'security=FAIL|crit_high=SECURITY_FAIL' \
  && ok "RR-9 security FAIL → 1" || nope "RR-9" "rc=$rc out=$out"
rm -rf "$TD"

# RR-10: pretool warn-only (비-strict·비-batch) — NOT_READY 여도 PR allow
HOOK="$PLUGIN/hooks/pretool-governance.sh"
FIX="$PLUGIN/scripts/tests/governance/fixtures/transcripts"
TD=$(mktemp -d); FID=20260803-rr-warn
_mk_base "$TD" "$FID"
# verify PASS state but missing security → NOT_READY
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf '{"effective":"standard","computed":"standard","mode":"live","reductions_allowed":[]}\n' \
  > "$TD/.specops/$FID/risk-profile.json"
# staged code so docs-only 면제 안 됨
(cd "$TD" && echo y > src/b.sh && git add src/b.sh)
mkstdin() { jq -nc --arg c "$1" --arg t "$2" '{tool_name:"Bash", tool_input:{command:$c}, transcript_path:$t}'; }
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr")
echo "$out" | grep -q '"continue":true' \
  && ! echo "$out" | grep -q '"permissionDecision":"deny"' \
  && grep -q 'RELEASE_READY warn' "$TD/stderr" \
  && ok "RR-10 warn-only allow + stderr" \
  || nope "RR-10" "out=$out stderr=$(cat "$TD/stderr")"
# R-1 에는 RELEASE 미발화
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr2")
! grep -q 'RELEASE_READY' "$TD/stderr2" \
  && ok "RR-10b R-1에 RELEASE 미발화" \
  || nope "RR-10b" "stderr=$(cat "$TD/stderr2")"
rm -rf "$TD"

# RR-11: effective=strict + NOT_READY → hard deny
TD=$(mktemp -d); FID=20260803-rr-strict
_mk_base "$TD" "$FID"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf '{"effective":"strict","computed":"strict","mode":"live","reductions_allowed":[]}\n' \
  > "$TD/.specops/$FID/risk-profile.json"
(cd "$TD" && echo y > src/b.sh && git add src/b.sh)
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr")
echo "$out" | grep -q '"permissionDecision":"deny"' \
  && echo "$out" | grep -q 'RELEASE_READY' \
  && ok "RR-11 strict + NOT_READY → deny" \
  || nope "RR-11" "out=$out stderr=$(cat "$TD/stderr")"
rm -rf "$TD"

# RR-12: ACTIVE batch + matching branch + NOT_READY → hard deny
TD=$(mktemp -d); FID=20260803-rr-batch
BID=batch-20260803-rr
_mk_base "$TD" "$FID"
mkdir -p "$TD/.specops/$BID"
: > "$TD/.specops/$BID/ACTIVE"
cat > "$TD/.specops/$BID/queue.md" <<EOF
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | $FID | one | IMPL_DONE |
EOF
: > "$TD/.specops/$FID/review-base.sha"
: > "$TD/.specops/$FID/review-request.md"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TD/.specops/$FID/evidence.md"
(cd "$TD" && bash "$STATE" record "$FID" PASS --executed 1)
printf '## %s\n- 2026-08-03 10:00 /verify PASS\n' "$FID" > "$TD/.specops/session-progress.md"
printf '<!-- active-fid: %s -->\n' "$FID" >> "$TD/.specops/session-progress.md"
(cd "$TD" && git checkout -qb "feat/$BID")
(cd "$TD" && echo y > src/b.sh && git add src/b.sh)
# requirements for batch-state --gate (optional path) — gate may fail-open on missing req
printf '| FR-1 | one | M1 | must | s | f |\n' > "$TD/requirements.md"
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr")
echo "$out" | grep -q '"permissionDecision":"deny"' \
  && echo "$out" | grep -qE 'RELEASE_READY|batch' \
  && ok "RR-12 batch ACTIVE + NOT_READY → deny" \
  || nope "RR-12" "out=$out stderr=$(cat "$TD/stderr")"
rm -rf "$TD"

# RR-13: strict + UNKNOWN (legacy-no-verify) → fail-open allow
TD=$(mktemp -d); FID=20260803-rr-unk
_mk_base "$TD" "$FID"
# no evidence stamp, no verification-state → UNKNOWN
rm -f "$TD/.specops/$FID/evidence.md"
printf '{"effective":"strict","computed":"strict","mode":"live","reductions_allowed":[]}\n' \
  > "$TD/.specops/$FID/risk-profile.json"
(cd "$TD" && echo y > src/b.sh && git add src/b.sh)
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr")
# R-2 lookback may still deny for missing verify — use BYPASS? Plan: UNKNOWN allow for RELEASE_READY.
# If R-2 fires first, we need verify exec + session progress verify for R-2 pass, but no state for UNKNOWN.
# Keep evidence absent so release-ready=UNKNOWN; R-2 needs verify in transcript — pretool-with-verify-exec
# provides exec; session-progress has /verify PASS from _mk_base → R-2 allows; RELEASE_READY UNKNOWN → allow.
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" \
  | CLAUDE_PROJECT_DIR="$TD" bash "$HOOK" 2>"$TD/stderr")
echo "$out" | grep -q '"continue":true' \
  && ! echo "$out" | grep -q 'RELEASE_READY 차단' \
  && ok "RR-13 strict + UNKNOWN → fail-open allow" \
  || nope "RR-13" "out=$out stderr=$(cat "$TD/stderr")"
rm -rf "$TD"

finish
