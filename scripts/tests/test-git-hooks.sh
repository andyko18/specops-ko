#!/usr/bin/env bash
# 2단 git hook 게이트 — pre-commit(빠른 정합 ~5s) / pre-push(run-all 전체 195s)
# 계기: 44cd095 revert 가 run-all 없이 나가 main 이 하루 red.
#       Claude Code PreToolUse 훅은 Cursor 등 다른 도구의 커밋에 발화하지 않는다 —
#       git hook 은 도구 무관하게 걸리는 유일한 층이다.
set -uo pipefail
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

PRE_COMMIT="$PLUGIN/.githooks/pre-commit"
PRE_PUSH="$PLUGIN/.githooks/pre-push"
INSTALLER="$PLUGIN/scripts/_internal/install-git-hooks.sh"

# GH-1: 훅 파일 존재 + 실행권한
[ -f "$PRE_COMMIT" ] && [ -x "$PRE_COMMIT" ] \
  && ok "GH-1 .githooks/pre-commit 존재+실행권한" \
  || nope "GH-1" "부재 또는 비실행"

[ -f "$PRE_PUSH" ] && [ -x "$PRE_PUSH" ] \
  && ok "GH-2 .githooks/pre-push 존재+실행권한" \
  || nope "GH-2" "부재 또는 비실행"

# GH-3: pre-commit 은 빠른 게이트 2종 — 정적 구성 + **실측 소요**로 확인한다.
#       (문구 grep 은 안내문 안의 run-all 언급과 실제 호출을 구분하지 못한다.
#        195s 스위트를 돌지 '않음'은 시간으로 증명하는 게 맞다.)
if [ -x "$PRE_COMMIT" ]; then
  grep -q 'validate-structure.sh' "$PRE_COMMIT" && grep -q 'check-propagation.sh' "$PRE_COMMIT" \
    && gate_ok=1 || gate_ok=0
  _s=$(date +%s)
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1) || true
  _e=$(date +%s)
  _d=$((_e - _s))
  [ "$gate_ok" -eq 1 ] && [ "$_d" -lt 60 ] \
    && ok "GH-3 pre-commit = 빠른 게이트 2종 (${_d}s < 60s — run-all 미실행)" \
    || nope "GH-3" "gate_ok=$gate_ok 소요=${_d}s"
else
  nope "GH-3" "pre-commit 부재"
fi

# GH-4: pre-push 는 전체 스위트 + 재귀 가드
if [ -f "$PRE_PUSH" ]; then
  grep -q 'run-all.sh' "$PRE_PUSH" \
    && grep -q 'SPECOPS_RUN_ALL' "$PRE_PUSH" \
    && ok "GH-4 pre-push = run-all + 재귀 가드" \
    || nope "GH-4" "run-all 또는 SPECOPS_RUN_ALL 가드 부재"
else
  nope "GH-4" "pre-push 부재"
fi

# GH-5: 주권 탈출구 안내 — 차단 문구에 --no-verify 명시 (5원칙 4)
if [ -f "$PRE_COMMIT" ] && [ -f "$PRE_PUSH" ]; then
  grep -q -- '--no-verify' "$PRE_COMMIT" && grep -q -- '--no-verify' "$PRE_PUSH" \
    && ok "GH-5 두 훅 모두 --no-verify 주권 안내" \
    || nope "GH-5" "탈출구 안내 부재"
else
  nope "GH-5" "훅 부재"
fi

# GH-6: 비-specops repo 면제 — 게이트 스크립트 없는 트리에서 exit 0 (월권 금지, 5원칙 4)
if [ -x "$PRE_COMMIT" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q && printf 'x\n' > a.txt && git add a.txt)
  (cd "$TD" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "GH-6 비-specops repo 면제 (exit 0)" || nope "GH-6" "rc=$rc"
  rm -rf "$TD"
else
  nope "GH-6" "pre-commit 부재"
fi

# GH-7: 현재 트리 정상 → pre-commit exit 0
if [ -x "$PRE_COMMIT" ]; then
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "GH-7 정상 트리 → exit 0" || nope "GH-7" "rc=$rc"
else
  nope "GH-7" "pre-commit 부재"
fi

# GH-8: 실제 드리프트 차단 실증 — 44cd095(파손 리비전)의 start-all.md 복원 시 exit 1
#       (이 커밋이 run-all 없이 나가 T1.e 를 하루 red 로 남긴 그 변경이다)
if [ -x "$PRE_COMMIT" ] && (cd "$PLUGIN" && git cat-file -e 44cd095:commands/start-all.md 2>/dev/null); then
  BAK=$(mktemp)
  cp "$PLUGIN/commands/start-all.md" "$BAK"
  # shellcheck disable=SC2064
  trap "cp '$BAK' '$PLUGIN/commands/start-all.md'; rm -f '$BAK'" EXIT
  (cd "$PLUGIN" && git show 44cd095:commands/start-all.md > commands/start-all.md)
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  cp "$BAK" "$PLUGIN/commands/start-all.md"; rm -f "$BAK"
  trap - EXIT
  [ "$rc" -ne 0 ] && ok "GH-8 44cd095 파손 리비전 → pre-commit 차단" || nope "GH-8" "rc=$rc (차단 실패)"
else
  ok "GH-8 SKIP (44cd095 미도달 — shallow clone)"
fi

# GH-9: 설치 스크립트가 core.hooksPath 를 .githooks 로 설정
if [ -f "$INSTALLER" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q && mkdir -p .githooks)
  (cd "$TD" && bash "$INSTALLER" >/dev/null 2>&1)
  hp=$(cd "$TD" && git config core.hooksPath || true)
  [ "$hp" = ".githooks" ] && ok "GH-9 installer → core.hooksPath=.githooks" \
    || nope "GH-9" "hooksPath=$hp"
  rm -rf "$TD"
else
  nope "GH-9" "install-git-hooks.sh 부재"
fi

# GH-9b: 관할 한정 — .githooks/ 없는 repo 는 설치 거부 (없는 경로를 가리키게 두지 않는다)
if [ -f "$INSTALLER" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q)
  (cd "$TD" && bash "$INSTALLER" >/dev/null 2>&1); rc=$?
  hp=$(cd "$TD" && git config core.hooksPath || true)
  [ "$rc" -ne 0 ] && [ -z "$hp" ] \
    && ok "GH-9b .githooks 부재 repo → 설치 거부" \
    || nope "GH-9b" "rc=$rc hooksPath=$hp"
  rm -rf "$TD"
else
  nope "GH-9b" "install-git-hooks.sh 부재"
fi

# GH-10: 설치 안내가 문서화됐는가 (clone 마다 1회 필요 — core.hooksPath 는 버전관리 대상이 아님)
grep -q 'install-git-hooks' "$PLUGIN/CLAUDE.md" && grep -q 'install-git-hooks' "$PLUGIN/scripts/README.md" \
  && ok "GH-10 CLAUDE.md·scripts/README 설치 안내" \
  || nope "GH-10" "설치 안내 문서 부재"

finish
