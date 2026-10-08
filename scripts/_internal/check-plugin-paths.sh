#!/usr/bin/env bash
# check-plugin-paths.sh — 프롬프트(skill·agent·command·template) 속 "실행 지시"의 plugin 상대 경로 적발 (20261008)
# Usage: check-plugin-paths.sh [ROOT]   (기본 플러그인 루트)  ·  Exit: 0 = 깨끗 · 1 = 위반 있음
#
# 왜 필요한가: `bash scripts/...`·`source hooks/...` 는 cwd 가 플러그인 repo 일 때만 동작한다. 하류 repo 에서는 파일이 없어
#   조용히 실패한다(실측: clarifying-ko 의 evaluator 회전·타임스탬프 주입, decomposing-ko 의 DAG 초기화 등).
#   하류에서도 맞는 표기는 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/...` 이다.
# 대상: `bash|source` + (선택적 따옴표) + `scripts/|hooks/|skills/` 로 시작하는 경로. 설명용 언급(판정 SoT = `scripts/...`)은 실행 지시가 아니라 대상 아님.
# 허용(plugin repo 자체에서만 도는 도구/예시):
#   skills/release-ko·commands/release.md(릴리즈는 plugin repo 에서만) · skills/e2e-test-ko(plugin 개발자 수동 E2E) ·
#   `scripts/tests/test-*` (하류 프로젝트의 테스트 명령 "예시" 표기) · `bash scripts/*.sh` 처럼 glob 인 러너 패턴 설명
set -u
ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$ROOT" || exit 2
hits=$(command grep -rnE '(bash|source) +"?(\./)?(scripts|hooks|skills)/' skills agents commands templates 2>/dev/null \
  | command grep -vE '^(skills/release-ko/|commands/release\.md:|skills/e2e-test-ko/)' \
  | command grep -vE '(bash|source) +"?(\./)?scripts/tests/(test-|run-all)' \
  | command grep -vE '(bash|source) +"?(\./)?scripts/\*' \
  | command grep -v 'CLAUDE_PLUGIN_ROOT')
if [ -n "$hits" ]; then
  echo "PLUGIN-PATHS: FAIL — 하류 repo 에서 깨지는 plugin 상대 경로 실행 지시:"
  printf '%s\n' "$hits" | cut -c1-200 | sed 's/^/  /'
  echo "  → bash \"\${CLAUDE_PLUGIN_ROOT}\"/<경로> 로 바꾸세요."
  exit 1
fi
echo "PLUGIN-PATHS: OK"
exit 0
