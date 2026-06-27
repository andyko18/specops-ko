#!/usr/bin/env bash
# SAST 래퍼 — semgrep + gitleaks, graceful skip (critic-ask.sh 패턴)
set -u
TARGET="${1:-.}"
crit=0; high=0; med=0; ran=0

# ── self-check 1단계 (설치 0, 항상 실행) — secret 전 파일·위험함수/SQL 비-bash ──
# 언어 판별: .sh/.bash 확장자 또는 bash shebang → bash (위험함수 룰 제외, secret 만)
_is_bash() { case "$1" in *.sh|*.bash) return 0;; esac; head -1 "$1" 2>/dev/null | grep -q '^#!.*\(bash\|sh\)' && return 0; return 1; }
_selfcheck_file() {
  local f="$1"
  # secret (전 파일) → crit
  grep -Eq 'AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{36}|sk-[0-9A-Za-z]{20,}|-----BEGIN[^-]*PRIVATE KEY|(password|api_key|secret)[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']{6,}' "$f" 2>/dev/null && crit=$((crit+1))
  # 위험함수·SQL (비-bash 만) → high
  if ! _is_bash "$f"; then
    grep -Eq '\beval\(|\bexec\(|os\.system|subprocess[^)]*shell[[:space:]]*=[[:space:]]*True|dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=' "$f" 2>/dev/null && high=$((high+1))
    grep -Eq '(query|execute).*\+.*(req\.|request\.|params)|f["'"'"'][^"'"'"']*SELECT[^"'"'"']*\{' "$f" 2>/dev/null && high=$((high+1))
  fi
}
if [ -e "$TARGET" ]; then
  ran=1
  if [ -f "$TARGET" ]; then _selfcheck_file "$TARGET"
  else
    # 디렉토리: 텍스트 파일 순회 (.git·node_modules·.specops 제외)
    # */tests/* 제외 (C-1) — 보안 테스트 fixture 가 의도적 가짜 secret 보유 → 자기 오탐 방지
    while IFS= read -r f; do _selfcheck_file "$f"; done < <(find "$TARGET" -type f \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.sh' -o -name '*.bash' -o -name '*.go' -o -name '*.rb' -o -name '*.java' -o -name '*.php' \) -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.specops/*' -not -path '*/tests/*' 2>/dev/null)
  fi
fi

# jq 부재 가드 (code-reviewer I-2) — 외부 스캐너 결과는 jq 없으면 집계 불가라 SKIP 하되,
# self-check(grep, jq 무관) 결과는 보존: early-exit 0 으로 self-check crit 폐기하지 않음.
ext_skip=0
if { command -v semgrep >/dev/null 2>&1 || command -v gitleaks >/dev/null 2>&1; } && ! command -v jq >/dev/null 2>&1; then
  echo "SECURITY: 외부 스캐너 jq 미설치 — self-check 결과로만 판정 (외부 집계 skip)" >&2
  ext_skip=1
fi
# semgrep (변경 코드 SAST)
if [ "$ext_skip" = 0 ] && command -v semgrep >/dev/null 2>&1; then
  ran=1
  j=$(semgrep --config auto --json --quiet "$TARGET" 2>/dev/null || echo '{}')
  if command -v jq >/dev/null 2>&1; then
    crit=$((crit + $(printf '%s' "$j" | jq '[.results[]?|select(.extra.severity=="ERROR")]|length' 2>/dev/null || echo 0)))
    high=$((high + $(printf '%s' "$j" | jq '[.results[]?|select(.extra.severity=="WARNING")]|length' 2>/dev/null || echo 0)))
  fi
fi
# gitleaks (secret) — --no-git: 작업트리 파일시스템 스캔(git 히스토리 아님, code-reviewer I-1).
#   tmp 리포트는 mktemp + trap 정리(고정 /tmp 경로 race·심볼릭링크 회피, code-reviewer I-2).
if [ "$ext_skip" = 0 ] && command -v gitleaks >/dev/null 2>&1; then
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
# 외부 SAST 미실행 표기 — self-check 만 ran=1 일 때 crit=0 을 full SAST 통과로 오인 방지 (M6)
ext_note=""
{ command -v semgrep >/dev/null 2>&1 || command -v gitleaks >/dev/null 2>&1; } \
  || ext_note=" (self-check only — semgrep·gitleaks 미설치)"
echo "SECURITY: crit=$crit high=$high med=$med$ext_note"
{ [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; } && exit 1 || exit 0
