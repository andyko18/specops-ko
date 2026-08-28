#!/usr/bin/env bash
# 2단 git hook 게이트 설치 — core.hooksPath 를 .githooks 로 지정
#
# core.hooksPath 는 .git/config 에 남는 로컬 설정이라 **버전관리되지 않는다** —
# clone 마다 1회 실행이 필요하다 (훅 본문 자체는 .githooks/ 로 버전관리된다).
#
# Usage: bash scripts/_internal/install-git-hooks.sh [--uninstall]
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "install-git-hooks: git repo 아님" >&2; exit 1
}
cd "$ROOT" || exit 1

if [ "${1:-}" = "--uninstall" ]; then
  git config --unset core.hooksPath 2>/dev/null || true
  echo "install-git-hooks: 해제 완료 (core.hooksPath unset)"
  exit 0
fi

# 관할 한정 — .githooks/ 없는 repo 를 없는 경로로 가리키게 두지 않는다 (훅과 동일 원칙)
[ -d .githooks ] || {
  echo "install-git-hooks: .githooks/ 부재 — specops 플러그인 repo 에서 실행하세요" >&2
  exit 1
}

git config core.hooksPath .githooks || { echo "install-git-hooks: 설정 실패" >&2; exit 1; }
chmod +x .githooks/pre-commit .githooks/pre-push 2>/dev/null || true

cat <<'EOF'
install-git-hooks: 설치 완료 (core.hooksPath=.githooks)

  pre-commit  → validate-structure + check-propagation   (~5s)
  pre-push    → run-all.sh 전체 스위트                    (~330s)

탈출구(주권): git commit --no-verify · git push --no-verify
해제: bash scripts/_internal/install-git-hooks.sh --uninstall
EOF
