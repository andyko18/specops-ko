#!/usr/bin/env bash
# library-only
# isolated-tree.sh — 실 repo 를 건드리지 않는 격리 사본 헬퍼
#
# 왜: 스위트가 실 트리를 변이하면 동시 실행 중인 다른 프로세스(다른 세션·CI·
#   사용자 수동 실행)가 원인 불명 FAIL 을 본다. trap 은 **중단** 안전만 준다 —
#   정상 실행 중 변이 창에 남이 트리를 읽는 것은 못 막는다(concurrency-safety).
#   실측 피해: commands/start-all.md 가 431→300줄로 보이는 창이 실재했고
#   check-propagation 이 FAIL (14/208) 로 떨어졌다(20260906 세션).
#
# 사용:
#   source "$PLUGIN/scripts/tests/lib/isolated-tree.sh" 2>/dev/null || true
#   command -v iso::make_tree >/dev/null 2>&1 && command -v iso::make_git_tree >/dev/null 2>&1 \
#     || { echo "FATAL: isolated-tree 미로드(또는 반쯤 로드)" >&2; exit 1; }
#   T=$(iso::make_tree) || { nope "..." "사본 실패"; finish; exit 1; }
#   trap "rm -rf '$T'" EXIT      # 정리는 호출자 책임
#
# ★ 사본 **안의** 스크립트를 실행해야 한다 — validate-structure.sh:17-19 가 루트를
#   자기 BASH_SOURCE 기준(script_dir/../..)으로 잡으므로, 사본의 스크립트를 부르면
#   사본을 검사한다. $PLUGIN 의 스크립트를 부르면 실 트리를 검사해 격리가 무의미해진다.

# iso::make_tree — tracked 파일을 **워킹트리 내용 그대로** tmpdir 에 복사, 경로 echo
#   ★ git archive HEAD 를 쓰지 않는다: 커밋된 트리라 미커밋 수정이 검사에서 빠져
#     래칫이 약해진다(현행은 워킹트리를 검사한다).
# iso::make_tree [root] — root 기본값은 **$PLUGIN**(cwd 아님).
#   ★ 현행 두 스위트는 `cd "$PLUGIN"` 을 명시해 cwd 에 무관했다. cwd 기준으로 잡으면
#     `cd /tmp && bash $PLUGIN/scripts/tests/...` 같은 호출에서 git rev-parse 가 fatal 이 되고,
#     cwd 가 **다른 git repo** 면 그 repo 를 복사한다(plan-review 2회차 I4).
#   ★ 중첩 호출(T1 의 I3)은 사본을 복사해야 하므로 **인자를 명시**한다: iso::make_tree "$G"
iso::make_tree() {
  local root tmp
  root="${1:-${PLUGIN:?PLUGIN 미설정 — iso::make_tree 는 root 를 인자로 받거나 PLUGIN 을 요구한다}}"
  [ -d "$root/.git" ] || root=$( cd "$root" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null ) || return 1
  tmp=$(mktemp -d) || return 1
  # ★ pipefail 여부가 호출자마다 다르다 — `test-git-hooks.sh:6` 은 `set -uo pipefail`,
  #   `test-hardgate-ratchet.sh` 는 없다. 워킹트리에서 **삭제된** tracked 파일이 있으면
  #   `tar -c` 가 에러를 내는데, pipefail 유무에 따라 한쪽만 return 1 이 되어 동작이 갈린다.
  #   실측: 삭제 1건 있는 repo — pipefail 없으면 naive OK / 있으면 naive rc≠0, guarded 는 양쪽 OK.
  ( set +o pipefail
    cd "$root" && git ls-files -z \
      | while IFS= read -r -d '' f; do [ -e "$f" ] && printf '%s\0' "$f"; done \
      | tar --null -cf - -T - ) 2>/dev/null | tar -xf - -C "$tmp" || {
    rm -rf "$tmp"; return 1
  }
  # 사본이 쓸모 있는지 확인 — 빈 사본에 검사를 돌리면 vacuous PASS 가 된다
  [ -f "$tmp/scripts/_internal/validate-structure.sh" ] || { rm -rf "$tmp"; return 1; }
  printf '%s\n' "$tmp"
}

# iso::make_git_tree — 위 + git init + 초기 커밋
#   ★ git init 이 없으면 .githooks/pre-commit:16-17 이 관할 판정
#     (git rev-parse --show-toplevel)에서 빠져나가 **rc=0(면제)** 를 내므로,
#     "차단됐다" 판정이 조용히 거짓이 된다(실측: 파손 리비전 주입에도 rc=0).
iso::make_git_tree() {
  local tmp; tmp=$(iso::make_tree "${1:-}") || return 1
  ( cd "$tmp" \
    && git init -q \
    && git add -A \
    && git -c user.email=t@example.com -c user.name=t \
         -c commit.gpgsign=false -c core.hooksPath=/dev/null \
         commit -qm "iso baseline" ) >/dev/null 2>&1 || {
    rm -rf "$tmp"; return 1
  }
  printf '%s\n' "$tmp"
}
