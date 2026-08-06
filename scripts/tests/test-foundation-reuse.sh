#!/usr/bin/env bash
# foundation 재사용 게이트 (소비측) 기계화 — 20260806 /start-foundation 정밀분석
#
# 생산측(manifest 산출)은 check-foundation-manifest.sh 로 닫혔다. 소비측 —
# "§유형≠foundation 이고 manifest 가 있으면 각 task 에 `**재사용 foundation**` 또는
#  `**미재사용 근거**` 를 반드시 기재, 누락 시 implementing-ko 호출 금지" — 는
# decomposing-ko 산문뿐이었다(검사 스크립트 0곳). 모델이 안 쓰면 그대로 통과.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-foundation-reuse.sh"

_mk() {  # $1=dir $2=fid $3=§유형 $4=manifest여부(y/n)
  mkdir -p "$1/.specops/$2" "$1/.specops/memory"
  printf '**§유형**: %s\n' "$3" > "$1/.specops/$2/spec.md"
  [ "$4" = "y" ] && printf '| 라우팅 | `src/router.ts` | 라우트 | `import` |\n' \
    > "$1/.specops/memory/foundation-manifest.md"
  return 0
}
_tasks() {  # $1=경로 $2=T1선언 $3=T2선언 (빈 문자열=선언 없음)
  { printf '# 태스크 목록\n\n## 태스크 1: 로그인 폼\n\n**파일**: src/login.ts\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\n## 태스크 2: 세션 저장\n\n**파일**: src/session.ts\n'
    [ -n "$3" ] && printf '%s\n' "$3"
    printf '\n## 의존 그래프\n'
  } > "$1"
}

# T1: 전 task 선언 있음 → PASS
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: 라우팅' '**미재사용 근거**: 순수 유틸이라 공통부 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T1 전 task 선언 → PASS" || nope "T1" "rc=$rc"
rm -rf "$TD"

# T2: ★ 한 task 누락 → FAIL (핵심 — 산문일 때 통과하던 케이스)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: 라우팅' ''
out=$(cd "$TD" && bash "$CHK" 20260806-f 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '태스크 2' \
  && ok "T2 1건 누락 → FAIL + 해당 태스크 지목" || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: 전 task 누락 → FAIL
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T3 전 task 누락 → FAIL" || nope "T3" "rc=$rc"
rm -rf "$TD"

# T4: manifest 부재 → 게이트 비발동 (foundation 미사용 프로젝트에 월권 금지)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 n
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T4 manifest 부재 → skip" || nope "T4" "rc=$rc"
rm -rf "$TD"

# T5: §유형=foundation 자신 → skip (자기 자신에게 재사용 요구 금지)
TD=$(mktemp -d); _mk "$TD" 20260806-f foundation y
_tasks "$TD/.specops/20260806-f/tasks.md" '' ''
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T5 §유형=foundation → skip" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: 선언은 있으나 값이 placeholder → FAIL (형식만 갖춘 통과 차단)
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**재사용 foundation**: <모듈명>' '**미재사용 근거**: 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T6 placeholder 값 → FAIL" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: 선언은 있으나 값이 비어 있음 → FAIL
TD=$(mktemp -d); _mk "$TD" 20260806-f 신규 y
_tasks "$TD/.specops/20260806-f/tasks.md" '**미재사용 근거**:' '**미재사용 근거**: 범위 밖'
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T7 빈 값 → FAIL" || nope "T7" "rc=$rc"
rm -rf "$TD"

# T8: tasks.md·spec.md 부재 → fail-open
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-f"
(cd "$TD" && bash "$CHK" 20260806-f >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T8 산출물 부재 → fail-open" || nope "T8" "rc=$rc"
rm -rf "$TD"

# T9: emit-context 배선 — 구현 **전** 차단 지점에 연결됐는가
grep -q 'check-foundation-reuse.sh' "$PLUGIN/scripts/dag/emit-context.sh" \
  && ok "T9 emit-context 배선 (구현 전 fail-fast)" || nope "T9" "미배선 — 산문 잔존"

# T10: decomposing-ko 가 스크립트를 SoT 로 지목
grep -q 'check-foundation-reuse.sh' "$PLUGIN/skills/decomposing-ko/SKILL.md" \
  && ok "T10 decomposing-ko 스크립트 지목" || nope "T10" "스킬 본문 미갱신"

finish
