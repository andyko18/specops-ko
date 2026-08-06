#!/usr/bin/env bash
# foundation 기술스택 확정 게이트 (clarify 층 봉합) — 20260806
#
# clarifying-ko 는 "§유형=foundation 이고 architecture 문서에 placeholder 가 있으면
#   기술 프레임워크 확정을 BLOCKING 으로 강제, RESOLVED 전 planning 진입 차단" 을 선언한다.
#   판정기(check-decisions-ledger.sh)를 만들었지만 **호출은 여전히 산문 의무**였다 —
#   clarify 단계엔 스크립트가 반드시 지나는 관문이 없기 때문.
# 그래서 결정의 **증거**를 다음 하드 관문(emit-context, 구현 직전)에서 검사한다.
#   증거 = ① 원장에 스택 확정 행(clarifying HARD 규약: RESOLVED → decisions.md upsert)
#        또는 ② clarifications.md 에 스택 관련 RESOLVED 기록
#   둘 다 없으면 = 아무도 스택을 정하지 않았는데 구현으로 넘어가는 것 → 차단.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-stack-decided.sh"

_base() {  # $1=dir $2=fid $3=§유형 $4=arch placeholder(y/n)
  mkdir -p "$1/.specops/$2" "$1/.specops/memory"
  printf '**§유형**: %s\n' "$3" > "$1/.specops/$2/spec.md"
  if [ "$4" = "y" ]; then
    printf '# 프론트 아키텍처\n- 프레임워크: <확정 필요>\n' \
      > "$1/.specops/memory/frontend-architecture.md"
  else
    printf '# 프론트 아키텍처\n- 프레임워크: React 19\n' \
      > "$1/.specops/memory/frontend-architecture.md"
  fi
}
_ledger() {  # $1=dir $2=행 (빈 문자열이면 골격 예시행만)
  { printf '| DECISION-ID | 주제 | 확정값 | 출처 | 갱신일 |\n|---|---|---|---|---|\n'
    printf '| D-001 | (예시) UI 유무 | 있음 | init Phase11.5 | YYYY-MM-DD |\n'
    [ -n "$2" ] && printf '%s\n' "$2"
  } > "$1/.specops/memory/decisions.md"
  return 0
}

# T1: ★ foundation + arch placeholder + 원장 골격(예시행만) + clarifications 없음 → FAIL
TD=$(mktemp -d); _base "$TD" 20260806-f foundation y; _ledger "$TD" ""
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T1 스택 결정 증거 전무 → FAIL" || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: 원장에 실제 스택 확정 행 → PASS
TD=$(mktemp -d); _base "$TD" 20260806-f foundation y
_ledger "$TD" '| D-002 | 프론트엔드 스택 | React 19 + Vite | clarify 20260806-f | 2026-08-06 |'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T2 원장 스택 확정 → PASS" || nope "T2" "rc=$rc"
rm -rf "$TD"

# T3: 원장엔 없지만 clarifications.md 에 스택 RESOLVED → PASS (upsert 누락은 경고)
TD=$(mktemp -d); _base "$TD" 20260806-f foundation y; _ledger "$TD" ""
printf '## Q-1 기술 프레임워크\nstatus: RESOLVED\n답변: React 19 + Vite\n' \
  > "$TD/.specops/20260806-f/clarifications.md"
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'upsert' \
  && ok "T3 clarifications RESOLVED → PASS + upsert 경고" || nope "T3" "rc=$rc out=$out"
rm -rf "$TD"

# T4: clarifications 에 스택 언급은 있으나 status: ASSUMED → 증거 불인정 → FAIL
TD=$(mktemp -d); _base "$TD" 20260806-f foundation y; _ledger "$TD" ""
printf '## Q-1 기술 프레임워크\nstatus: ASSUMED\n**가정 근거**: 흔한 선택\n' \
  > "$TD/.specops/20260806-f/clarifications.md"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T4 ASSUMED → 증거 불인정 FAIL" || nope "T4" "rc=$rc"
rm -rf "$TD"

# T5: arch 문서에 placeholder 없음(이미 확정) → 게이트 비발동
TD=$(mktemp -d); _base "$TD" 20260806-f foundation n; _ledger "$TD" ""
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T5 arch placeholder 없음 → skip" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: §유형≠foundation → skip (일반 기능은 본 게이트 대상 아님)
TD=$(mktemp -d); _base "$TD" 20260806-f 신규 y; _ledger "$TD" ""
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T6 비-foundation → skip" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: arch 문서 자체가 없음 → skip (UI 없는 프로젝트 등)
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-f" "$TD/.specops/memory"
printf '**§유형**: foundation\n' > "$TD/.specops/20260806-f/spec.md"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T7 arch 문서 부재 → skip" || nope "T7" "rc=$rc"
rm -rf "$TD"

# T8: spec.md 부재 → fail-open
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-f"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T8 spec.md 부재 → fail-open" || nope "T8" "rc=$rc"
rm -rf "$TD"

# T9: emit-context 배선 (구현 직전 하드 관문)
grep -q 'check-stack-decided.sh' "$PLUGIN/scripts/dag/emit-context.sh" \
  && ok "T9 emit-context 배선" || nope "T9" "미배선 — clarify 층 여전히 산문"

# T10: clarifying-ko 가 후속 관문 존재를 명시 (건너뛰어도 잡힌다는 계약)
grep -q 'check-stack-decided.sh' "$PLUGIN/skills/clarifying-ko/SKILL.md" \
  && ok "T10 clarifying-ko 후속 관문 명시" || nope "T10" "스킬 본문 미갱신"

finish
