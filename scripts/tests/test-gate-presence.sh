#!/usr/bin/env bash
# test-gate-presence.sh — skill-body HARD GATE 존재 회귀 (②)
#
# 목적: skill body 의 핵심 게이트 문구가 실수로 삭제·drift 되는 것을 **결정적 grep** 으로 방어한다.
#   - LLM 이 게이트를 "지키는지"(행동) 는 llm-eval(주간 smoke) 관할.
#   - 본 테스트는 게이트가 "존재하는지"(구조) 만 — 무료·결정적·CI 상시.
#   - recurring 결함 클래스(feedback_skill_body_infra_propagation: teeth in body, 인프라 소실)의
#     "게이트 자체 소실" 절반을 봉쇄. cross-skill signal 정합은 validate-structure contract_consistency(①) 담당.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd) || exit 1
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
cd "$PLUGIN" || exit 1

# has <file> <regex...> — 모든 패턴이 파일에 존재하면 0
has() {
  local f="$1"; shift
  local p
  for p in "$@"; do grep -qE "$p" "$f" || return 1; done
  return 0
}

# ── foundation 재사용 메커니즘 3-지점 계약 (PR #165) ─────────────
V=skills/verifying-evidence-ko/SKILL.md
if has "$V" '§유형.*foundation' 'foundation-manifest' 'VERIFY: FAIL foundation-manifest'; then
  ok "foundation manifest 생산 게이트 존재 (verify: §유형=foundation → 실제 파일 검사)"
else
  nope "foundation manifest 생산 게이트 소실" "verifying-evidence-ko — 소비 게이트가 침묵 no-op 될 수 있음"
fi

D=skills/decomposing-ko/SKILL.md
if has "$D" 'foundation 재사용 게이트' '재사용 foundation' '미재사용 근거'; then
  ok "foundation 재사용 소비 게이트 존재 (decomposing)"
else
  nope "foundation 재사용 소비 게이트 소실" "decomposing-ko"
fi

P=skills/planning-ko/SKILL.md
if has "$P" 'foundation-manifest' 'verifying-evidence-ko'; then
  ok "foundation 생산 지시 + verify 강제 cross-ref 존재 (planning)"
else
  nope "foundation 생산 지시/강제 cross-ref 소실" "planning-ko"
fi

# 경로 정합 — 생산 게이트·소비 게이트가 동일 정규 경로를 가리키는가
if has "$V" '\.specops/memory/foundation-manifest\.md' && has "$D" 'foundation-manifest\.md'; then
  ok "foundation-manifest 경로 정합 (.specops/memory/)"
else
  nope "foundation-manifest 경로 drift" "verify↔decomposing 경로 불일치"
fi

# ── BATCH halt signal — 방출 skill 에 signal + halt 동시 존재 ────
# (cross-skill 방출↔감시 정합은 ① contract_consistency; 여기선 방출측 halt 구조만)
declare -a SIG=(
  "BATCH-PHASE1-DONE:decomposing-ko"
  "BATCH-REVIEW-DONE:receiving-code-review-ko"
  "BATCH-SECURITY-DONE:security-review-ko"
  "BATCH-INTEGRATION-DONE:integration-test-ko"
  "BATCH-PERF-DONE:performance-test-ko"
)
for pair in "${SIG[@]}"; do
  token="${pair%%:*}"; skill="${pair##*:}"
  f="skills/${skill}/SKILL.md"
  if has "$f" "$token" 'halt|PR 게이트'; then
    ok "batch halt signal 존재: ${token} (${skill})"
  else
    nope "batch halt signal 소실: ${token}" "${skill} — signal 또는 halt 문구 부재"
  fi
done

# ── 가정 다이제스트 "자동 결정 인터페이스" 수집 3-소비처 (P1-3 audit 20260710) ──
# specifying §auto Step 5.6 이 spec.md 에 기록하는 라벨을 다이제스트 소비처가 실제 수집하는지.
for f in skills/performance-test-ko/SKILL.md commands/start-auto.md commands/start-all-auto.md; do
  if grep -q '자동 결정 인터페이스' "$f"; then
    ok "다이제스트 인터페이스 수집 존재 ($f)"
  else
    nope "다이제스트 인터페이스 수집 ($f)" "'자동 결정 인터페이스' 미수집 — 무인 API 가정이 PR 게이트에 안 보임"
  fi
done

finish
