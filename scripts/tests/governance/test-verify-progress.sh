#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
. "$PLUGIN/hooks/governance-lib.sh"
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"; mkdir -p .specops
sp=".specops/session-progress.md"

# T1: verify PASS 최신(위) > /implement → 유효(0)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:36 /verify PASS (evidence.md, AC 12/12)
- 2026-06-25 16:34 /implement DONE (T1~T5)
EOF
_verify_passed_in_progress 20260625-x && { PASS=$((PASS+1)); echo "PASS T1 verify최신→유효"; } || { FAIL=$((FAIL+1)); echo "FAIL T1"; }

# T2: /implement 가 verify 보다 최신(위) → 무효(1)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:40 /implement DONE (재구현)
- 2026-06-25 16:36 /verify PASS (AC 12/12)
EOF
_verify_passed_in_progress 20260625-x && { FAIL=$((FAIL+1)); echo "FAIL T2"; } || { PASS=$((PASS+1)); echo "PASS T2 implement최신→무효"; }

# T3: verify 없음 → 무효(1)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:34 /implement DONE
EOF
_verify_passed_in_progress 20260625-x && { FAIL=$((FAIL+1)); echo "FAIL T3"; } || { PASS=$((PASS+1)); echo "PASS T3 verify없음→무효"; }

# T4: 무수정 리뷰(신규 0)는 코드변경 아님 → verify 유효(0)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:37 /receive-review 완료 (Critical 0, 신규 0)
- 2026-06-25 16:36 /verify PASS (AC 12/12)
EOF
_verify_passed_in_progress 20260625-x && { PASS=$((PASS+1)); echo "PASS T4 무수정리뷰→유효"; } || { FAIL=$((FAIL+1)); echo "FAIL T4"; }

# T5: 수정흔적 리뷰(fix 1라운드)가 verify 보다 최신 → 무효(1)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:38 /receive-review 완료 (Important 1 수용, fix 1라운드)
- 2026-06-25 16:36 /verify PASS (AC 12/12)
EOF
_verify_passed_in_progress 20260625-x && { FAIL=$((FAIL+1)); echo "FAIL T5"; } || { PASS=$((PASS+1)); echo "PASS T5 수정리뷰최신→무효"; }

# T7(I-2): verify 줄 memo 에 "/implement" 문자열 있어도 명령앵커로 무시 → verify 유효(0)
cat > "$sp" <<'EOF'
## 20260625-x · 기능
- 2026-06-25 16:36 /verify PASS (/implement 단계 검증)
EOF
_verify_passed_in_progress 20260625-x && { PASS=$((PASS+1)); echo "PASS T7 memo명령언급무시→유효"; } || { FAIL=$((FAIL+1)); echo "FAIL T7"; }

# T6: session-progress 부재 → 무효(1, fallback)
rm -f "$sp"
_verify_passed_in_progress 20260625-x && { FAIL=$((FAIL+1)); echo "FAIL T6"; } || { PASS=$((PASS+1)); echo "PASS T6 부재→무효"; }

# === _verify_evidence_stamp (AC-2/4) ===
mkdir -p .specops/test-fid
_verify_evidence_stamp test-fid && { FAIL=$((FAIL+1)); echo "FAIL: AC-4 stamp 부재 면제됨"; } || PASS=$((PASS+1))
printf 'RUN-VERIFICATION-RESULT: PASS\n' > .specops/test-fid/evidence.md
_verify_evidence_stamp test-fid && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: AC-2 PASS stamp 면제"; }
printf 'RUN-VERIFICATION-RESULT: FAIL\n' > .specops/test-fid/evidence.md
_verify_evidence_stamp test-fid && { FAIL=$((FAIL+1)); echo "FAIL: AC-4 FAIL stamp 면제됨"; } || PASS=$((PASS+1))
rm -rf .specops/test-fid
# === 3-state affirmative-stale 보존 (T39 정합) ===
mkdir -p .specops/stale-fid
printf '## stale-fid\n- 2026-06-26 10:10 /implement DONE (재구현)\n- 2026-06-26 10:05 /verify PASS (AC 5/5)\n' >> .specops/session-progress.md
printf 'RUN-VERIFICATION-RESULT: PASS\n' > .specops/stale-fid/evidence.md
_verify_passed_in_progress stale-fid; vp=$?
[ "$vp" -eq 2 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: 3-state affirmative-stale return 2 아님 (vp=$vp)"; }
rm -rf .specops/stale-fid

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
