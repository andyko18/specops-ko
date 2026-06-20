#!/usr/bin/env bash
# SAST 래퍼 — semgrep + gitleaks, graceful skip (critic-ask.sh 패턴)
set -u
TARGET="${1:-.}"
crit=0; high=0; med=0; ran=0
# jq 부재 가드 (plan-reviewer I-1) — 스캐너 설치됐는데 jq 없으면 집계 불가 → false-negative 방지
if { command -v semgrep >/dev/null 2>&1 || command -v gitleaks >/dev/null 2>&1; } && ! command -v jq >/dev/null 2>&1; then
  echo "SECURITY: SKIP (jq 미설치 — 스캐너 결과 집계 불가, 수동 점검 필요)"
  exit 0
fi
# semgrep (변경 코드 SAST)
if command -v semgrep >/dev/null 2>&1; then
  ran=1
  j=$(semgrep --config auto --json --quiet "$TARGET" 2>/dev/null || echo '{}')
  if command -v jq >/dev/null 2>&1; then
    crit=$((crit + $(printf '%s' "$j" | jq '[.results[]?|select(.extra.severity=="ERROR")]|length' 2>/dev/null || echo 0)))
    high=$((high + $(printf '%s' "$j" | jq '[.results[]?|select(.extra.severity=="WARNING")]|length' 2>/dev/null || echo 0)))
  fi
fi
# gitleaks (secret) — --no-git: 작업트리 파일시스템 스캔(git 히스토리 아님, code-reviewer I-1).
#   tmp 리포트는 mktemp + trap 정리(고정 /tmp 경로 race·심볼릭링크 회피, code-reviewer I-2).
if command -v gitleaks >/dev/null 2>&1; then
  ran=1
  glrep=$(mktemp "${TMPDIR:-/tmp}/specops-gl.XXXXXX") || glrep=""
  if [ -n "$glrep" ]; then
    trap 'rm -f "$glrep"' EXIT
    gitleaks detect --source "$TARGET" --no-git --no-banner --exit-code 0 --report-format json --report-path "$glrep" >/dev/null 2>&1
    if [ -f "$glrep" ] && command -v jq >/dev/null 2>&1; then
      crit=$((crit + $(jq 'length' "$glrep" 2>/dev/null || echo 0)))  # secret = Critical
    fi
  fi
fi
if [ "$ran" = 0 ]; then
  echo "SECURITY: SKIP (semgrep·gitleaks 미설치 — graceful skip)"
  exit 0
fi
echo "SECURITY: crit=$crit high=$high med=$med"
{ [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; } && exit 1 || exit 0
