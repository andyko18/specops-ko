#!/usr/bin/env bash
# test-review-return-contract — 리뷰 반환 요약화 문서 계약 (AC-7) · FID 20260914-review-return-summary
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

# ── T1 리뷰어 문서 ──
for a in spec-reviewer-ko code-reviewer-ko; do
  f="$PLUGIN/agents/$a.md"
  if grep -qF '<<<REVIEW fid=' "$f" && grep -qF '<<<END>>>' "$f"; then ok "T1.a $a 마커 형식"
  else nope "T1.a $a 마커 형식"; fi
  if grep -qF 'stop-hook 지시' "$f"; then ok "T1.b $a stop-hook 지시 준수 문구"
  else nope "T1.b $a stop-hook 지시"; fi
  if ! grep -qE '요약 형식|300토큰|Critical: <' "$f"; then ok "T1.c $a 요약 형식 미기재 (선취 방지)"
  else nope "T1.c $a 요약 형식이 에이전트 정의에 있음"; fi
  if ! grep -m1 '^tools:' "$f" | grep -qE 'Write|Edit'; then ok "T1.d $a Write/Edit 박탈 유지"
  else nope "T1.d $a tools"; fi
done
if grep -qF 'verdict=<PASS|NEEDS_FIX>' "$PLUGIN/agents/spec-reviewer-ko.md"; then ok "T1.e Phase B 판정 어휘"
else nope "T1.e Phase B 판정 어휘"; fi
if grep -qF 'verdict=<READY_TO_MERGE|NEEDS_FIX|NEEDS_DISCUSSION>' "$PLUGIN/agents/code-reviewer-ko.md"; then ok "T1.f Phase C 판정 어휘"
else nope "T1.f Phase C 판정 어휘"; fi
if grep -qF '## 🔴 Critical' "$PLUGIN/agents/code-reviewer-ko.md"; then ok "T1.g 보고서 템플릿 🔴 헤딩 유지 (release-ready)"
else nope "T1.g 🔴 헤딩"; fi

# ── T2 부모 문서 공통 리터럴 (implementing-ko) ──
for d in skills/implementing-ko/SKILL.md; do
  for lit in '판정 SoT = reviews 파일' 'report 부재 시 부모 fallback 저장' 'dispatch-log 행은 부모가 기록'; do
    if grep -qF "$lit" "$PLUGIN/$d"; then ok "T2.a $d · $lit"
    else nope "T2.a $d" "'$lit' 부재"; fi
  done
done
if grep -qF 'hooks/save-review-report.sh' "$PLUGIN/skills/implementing-ko/SKILL.md"; then ok "T2.b implementing-ko 훅 경로 명시"
else nope "T2.b implementing-ko 훅 경로"; fi
# ── T3 propagation edge ──
if grep -qF '"id": "review-return-summary"' "$PLUGIN/scripts/_internal/propagation-matrix.jsonl"; then ok "T3.a propagation edge 존재"
else nope "T3.a propagation edge"; fi
if bash "$PLUGIN/scripts/_internal/check-propagation.sh" >/dev/null 2>&1; then ok "T3.b check-propagation 전 edge PASS"
else nope "T3.b check-propagation"; fi

finish
