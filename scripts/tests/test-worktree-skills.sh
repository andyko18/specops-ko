#!/usr/bin/env bash
# worktree skill 2종 — v5.1.0 (PRI-974) 규약 구조 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
WT="$PLUGIN/skills/using-git-worktrees-ko/SKILL.md"
FIN="$PLUGIN/skills/finishing-a-development-branch-ko/SKILL.md"

# T1.a 중첩 감지 — git-dir vs git-common-dir 비교 + 재사용 안내 + submodule 가드 (AC-1)
if grep -q -- '--git-common-dir' "$WT" && grep -q '현 worktree 재사용' "$WT" \
   && grep -qi 'submodule' "$WT"; then
  PASS=$((PASS+1)); echo "PASS T1.a 중첩 감지"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a"
fi

# 섹션 추출 헬퍼 — awk range(/^## X/,/^## /)는 시작 줄이 종료 패턴에 즉시 매치되는 버그 → flag 방식
section() { awk -v h="$1" '$0 ~ "^## " h {f=1; print; next} /^## /{f=0} f' "$2"; }

# T1.b 동의 게이트 모드 4분기 표 (AC-2) — 섹션 범위 내 4모드 전부
sec=$(section '생성 동의 게이트' "$WT")
if printf '%s' "$sec" | grep -q '단일' && printf '%s' "$sec" | grep -q '§auto' \
   && printf '%s' "$sec" | grep -q '§batch' && printf '%s' "$sec" | grep -q '병렬 wave' \
   && printf '%s' "$sec" | grep -q '가정 다이제스트'; then
  PASS=$((PASS+1)); echo "PASS T1.b 동의 4분기"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b"
fi

# T1.c provenance 규약 (AC-3)
if grep -q '플러그인 생성분' "$WT" && grep -q '불가침' "$WT"; then
  PASS=$((PASS+1)); echo "PASS T1.c provenance 규약"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.c"
fi

# T1.d n 응답 fallback — 순차 전환 (AC-7)
if section '생성 동의 게이트' "$WT" | grep -q 'SEQUENTIAL'; then
  PASS=$((PASS+1)); echo "PASS T1.d n→순차 fallback"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.d"
fi

# T1.e 빠른 참조·적색 플래그 갱신 (AC-8)
if section '적색 플래그' "$WT" | grep -q '동의 없이' \
   && section '적색 플래그' "$WT" | grep -q '중첩'; then
  PASS=$((PASS+1)); echo "PASS T1.e 적색 플래그 갱신"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.e"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
