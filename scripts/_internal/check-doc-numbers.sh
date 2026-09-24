#!/usr/bin/env bash
# 문서의 테스트 집합 수 주장이 실측과 맞는지 검사한다 (doc-lock).
# Usage: bash scripts/_internal/check-doc-numbers.sh
#   대상 트리: $DOC_NUMBERS_ROOT (미설정 시 git rev-parse --show-toplevel)
# exit 0=위반 0 · 1=위반 존재 · 2=대상 트리가 git 저장소 아님/읽기 불가
#
# 왜 트리를 인자로 받는가: 동종 checker(check-propagation.sh·check-matrix-patterns.sh)는
#   BASH_SOURCE 로 실 트리를 고정하는데, 그러면 되돌려-관찰(변이 주입)이 실 트리 쓰기가 되어
#   repo 관례(find-tree-writes.sh 탐지 대상)를 위반한다. 기본값은 cwd 기준 show-toplevel 이라
#   사용자 경험은 동종과 같다.
#
# 한계 (과대 주장 금지):
#   1. 마커 문자열이 코드 리터럴 안에 있어도 마커로 본다 — 주석 문법을 파싱하지 않는다.
#      check-matrix-patterns.sh 가 자인한 것과 같은 클래스다.
#   2. 검출 패턴은 "수치 + 단위어" 한 형태뿐이다 — 어순 반전·조사 결합·영문 표기는 못 잡는다.
#      영문은 test-doc-stamp-sync.sh AC-1 이 README·CLAUDE.md 2파일에서만 금지한다.
#   3. 경로에 콜론이 든 파일은 grep 출력 파싱이 어긋난다(현재 트리 해당 0건).
set -uo pipefail
# 로케일 고정 — 조건부(:-)가 아니다. 주변 환경의 LC_ALL 을 존중하면 한글 바이트 패턴이
#   조용히 매치를 멈출 수 있고, 그 실패는 이 검사 자신의 테스트로는 관측되지 않는다.
export LC_ALL=C.UTF-8

ROOT="${DOC_NUMBERS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
# ★ 훅 환경 변수를 떼어낸다 — git 은 pre-push 훅에 GIT_DIR 를 export 하고, run-all 은 그
#   훅에서 돈다. 그대로 두면 cd 로 대상 트리에 들어가도 git ls-files 가 **실 저장소의 인덱스**를
#   열거해 대상 트리 스캔이 0건이 되고, 검사가 조용히 공허 통과한다
#   (실측: GIT_DIR 주입 시 이 검사의 스위트가 PASS=2 FAIL=8 — 즉 단독 실행만 green 이고
#   도구 무관 게이트에서 깨진다). ROOT 기본값 해석 **뒤에** 떼므로 훅 환경에서의
#   저장소 자동 탐지는 그대로 유지된다.
unset GIT_DIR GIT_WORK_TREE
# .git 은 디렉터리이거나(일반 클론) 파일이다(linked worktree 의 gitdir 포인터).
#   rev-parse --is-inside-work-tree 로 바꾸지 않는다 — 상위 저장소까지 걸어올라가
#   비-git 트리를 통과시키고 rc=2 가 비결정적이 된다.
{ [ -n "$ROOT" ] && { [ -d "$ROOT/.git" ] || [ -f "$ROOT/.git" ]; }; } || {
  echo "DOC-NUMBERS: FAIL 대상 트리가 git 저장소가 아니다 (ROOT='${ROOT:-}')" >&2; exit 2; }
cd "$ROOT" || exit 2

# 한글 단위어를 리터럴로 두지 않는다 — 두면 이 파일이 자기 스캔에 걸려
#   검사가 자기 자신 때문에 FAIL 한다.
SUITE_WORD=$(printf '\xec\x8a\xa4\xec\x9c\x84\xed\x8a\xb8')
RE="[0-9]{2,4}[[:space:]]*${SUITE_WORD}"

# ── 실측: run-all.sh:71-81 과 같은 수집 목록 ──────────────────────
# ★ brace 확장으로 쓰지 않는다 — 디렉터리를 중괄호로 묶어 한 줄로 적으면 닫는 괄호가
#   경로 중간에 박혀 원장 앵커 promote/test- 에 매치가 0 이 된다(실측).
#   아래 리터럴 경로는 propagation edge 앵커를 겸한다 — run-all.sh 와 이 블록의
#   디렉터리 집합이 어긋나면 실측값이 거짓이 되고 잠금이 틀린 값을 강제한다.
_measure() {
  local n=1 f   # validate-structure.sh 는 무조건 1건 — run-all.sh:71 이 파일 존재를
                # 확인하지 않고 SUITES+= 한다. 검사도 동형이어야 값이 같다.
  for f in "scripts/tests/test-"*.sh \
           "scripts/tests/dag/test-"*.sh \
           "scripts/tests/governance/test-"*.sh \
           "scripts/tests/llm-eval/test-"*.sh \
           "scripts/tests/test-convention/test-"*.sh \
           "scripts/tests/freecomment/test-"*.sh \
           "scripts/tests/promote/test-"*.sh; do
    [ -f "$f" ] || continue
    n=$((n+1))
  done
  printf '%s' "$n"
}

# 경로 allowlist — 정확히 3종 (clarify Q1 확정).
#   날짜 병기는 allowlist 가 아니다 — 날짜 규칙이면 가장 낡은 값이 통과한다.
_allowlisted() {
  case "$1" in
    CHANGELOG.md)                              return 0 ;;
    docs/audit/*)                              return 0 ;;
    docs/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) return 0 ;;
  esac
  return 1
}

MEASURED=$(_measure)
files=0 lines=0 locked=0 hist=0 fail=0
prev_path=""

# grep -H 를 쓴다 — xargs 가 마지막 배치에 파일 1개만 넘기면 -n 만으로는 파일명 접두가
#   빠져 path 자리에 줄 번호가 들어온다(대형 트리에서만 발현하는 무음 오파싱).
while IFS= read -r rec; do
  [ -n "$rec" ] || continue
  path=${rec%%:*}; rest=${rec#*:}; lno=${rest%%:*}; text=${rest#*:}
  lines=$((lines+1))
  [ "$path" = "$prev_path" ] || { files=$((files+1)); prev_path="$path"; }

  if _allowlisted "$path"; then hist=$((hist+1)); continue; fi

  case "$text" in
    *"doc-lock: historical"*) hist=$((hist+1)); continue ;;
    *"doc-lock: suite-count"*)
      locked=$((locked+1))
      # 한 줄에 수치가 2개 이상이면 첫 매치를 판정하고 나머지도 별도 FAIL 로 보고한다 —
      #   침묵하면 뒤쪽 수치가 영구 무검증이 된다.
      hits=$(printf '%s' "$text" | grep -oE "$RE" | wc -l | tr -d ' ')
      if [ "${hits:-0}" -gt 1 ]; then
        echo "DOC-NUMBERS: FAIL $path:$lno 같은 줄에 수치가 2개 이상(${hits}개) — 한 줄에 하나만 두세요" >&2
        fail=$((fail+1))
      fi
      got=$(printf '%s' "$text" | grep -oE "$RE" | head -1 | grep -oE '[0-9]{2,4}' | head -1)
      if [ "$got" != "$MEASURED" ]; then
        echo "DOC-NUMBERS: FAIL $path:$lno 기대=$MEASURED 실제=$got — 마커 줄의 수치를 $MEASURED 로 고치세요" >&2
        fail=$((fail+1))
      fi
      ;;
    *)
      echo "DOC-NUMBERS: FAIL $path:$lno 마커 없음 — 'doc-lock: suite-count' 로 잠그거나 과거 기록이면 'doc-lock: historical' 을 다세요" >&2
      fail=$((fail+1))
      ;;
  esac
done < <(git ls-files -z | xargs -0 grep -HnE "$RE" 2>/dev/null || true)

if [ "$fail" -gt 0 ]; then
  echo "DOC-NUMBERS: FAIL 위반 ${fail}건 (스캔 ${files}파일/${lines}줄)" >&2
  exit 1
fi
echo "DOC-NUMBERS: OK (suite-count=$MEASURED · 스캔 ${files}파일/${lines}줄 · locked $locked · historical $hist)"
