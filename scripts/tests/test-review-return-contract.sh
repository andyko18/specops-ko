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
# 채운 예시 — 자리표시자 `>` 와 마커 `>>>` 가 겹쳐 꺾쇠 개수가 모호해지는 것을 막는다 (Phase C T3 🟡)
if grep -qF '<<<REVIEW fid=20260914-example tid=T1 phase=B verdict=PASS>>>' "$PLUGIN/agents/spec-reviewer-ko.md"; then ok "T1.h Phase B 채운 예시 줄"
else nope "T1.h Phase B 채운 예시 줄 부재"; fi
if grep -qF '<<<REVIEW fid=20260914-example tid=T1 phase=C verdict=READY_TO_MERGE>>>' "$PLUGIN/agents/code-reviewer-ko.md"; then ok "T1.i Phase C 채운 예시 줄"
else nope "T1.i Phase C 채운 예시 줄 부재"; fi

# ── T2 부모 문서 공통 리터럴 (implementing-ko) ──
for d in skills/implementing-ko/SKILL.md; do
  for lit in '판정 SoT = reviews 파일' 'report 부재 시 부모 fallback 저장' 'dispatch-log 행은 부모가 기록'; do
    if grep -qF "$lit" "$PLUGIN/$d"; then ok "T2.a $d · $lit"
    else nope "T2.a $d" "'$lit' 부재"; fi
  done
done
if grep -qF 'hooks/save-review-report.sh' "$PLUGIN/skills/implementing-ko/SKILL.md"; then ok "T2.b implementing-ko 훅 경로 명시"
else nope "T2.b implementing-ko 훅 경로"; fi
# fallback 확장 — 형식 오류·이동 실패로 옛 report 가 남아 옛 판정을 읽는 경로 차단 (Phase C T4 🟡)
if grep -qF '반환에 훅 요약이 없으면 파일 존재와 무관하게 덮어쓰기 저장' "$PLUGIN/skills/implementing-ko/SKILL.md"; then ok "T2.c implementing-ko fallback 덮어쓰기 조건"
else nope "T2.c implementing-ko fallback 덮어쓰기 조건 부재"; fi
# ── T3 propagation edge ──
if grep -qF '"id": "review-return-summary"' "$PLUGIN/scripts/_internal/propagation-matrix.jsonl"; then ok "T3.a propagation edge 존재"
else nope "T3.a propagation edge"; fi
if bash "$PLUGIN/scripts/_internal/check-propagation.sh" >/dev/null 2>&1; then ok "T3.b check-propagation 전 edge PASS"
else nope "T3.b check-propagation"; fi

# ── T4 부모 문서 공통 리터럴 (start-all · file-based-communication) ──
for d in commands/start-all.md skills/file-based-communication-ko/SKILL.md; do
  for lit in '판정 SoT = reviews 파일' 'report 부재 시 부모 fallback 저장' 'dispatch-log 행은 부모가 기록'; do
    if grep -qF "$lit" "$PLUGIN/$d"; then ok "T4.a $d · $lit"
    else nope "T4.a $d" "'$lit' 부재"; fi
  done
done
FBC="$PLUGIN/skills/file-based-communication-ko/SKILL.md"
if grep -qF '반환에 훅 요약이 없으면 파일 존재와 무관하게 덮어쓰기 저장' "$FBC"; then ok "T4.b file-based-communication-ko fallback 덮어쓰기 조건"
else nope "T4.b file-based-communication-ko fallback 덮어쓰기 조건 부재"; fi
# 프로필 한계 — standard·minimal 에서 is-hook-enabled 가 훅을 끈다 (사용자 결정: 현행 유지 + 한계 기록)
if grep -qF 'SPECOPS_GOVERNANCE_PROFILE' "$FBC"; then ok "T4.c file-based-communication-ko 프로필 한계 기록"
else nope "T4.c file-based-communication-ko 프로필 한계 부재"; fi

finish
