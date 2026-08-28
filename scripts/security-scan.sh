#!/usr/bin/env bash
# SAST 래퍼 — semgrep + gitleaks, graceful skip (critic-ask.sh 패턴)
set -u
TARGET="${1:-.}"
crit=0; high=0; med=0; ran=0

# ── 외부 스캐너 상한·차단 스위치 (FID 20260828-sast-timeout) ──
# SPECOPS_SAST_TIMEOUT : 외부 스캐너 1개당 초 상한 (기본 180 · 0 = 무제한, 종전 동작)
# SPECOPS_SAST_EXTERNAL: 0 이면 외부 스캐너를 아예 안 부른다 (오프라인·테스트용)
# 왜 기본값이 180 인가 (실측): `semgrep --config auto` 는 레지스트리에서 룰을 받는 네트워크
#   호출이고, 1줄 .py 대상 **정상 완주에 99초**가 걸린다. 60s 로 잡으면 정상 실행이 매번 잘려
#   SAST 가 영구 강등된다 — 무한 정지를 고치려다 스캐너를 끄는 셈이다. 180s 는 정상 왕복의
#   ~1.8배 여유이면서 무한 정지(실측 run-all 8분+ 무출력)는 확실히 끊는다.
# ★ `--metrics=off` 를 붙이면 안 된다: semgrep 이 "Cannot create auto config when metrics are off"
#   로 **거부**해 스캐너가 통째로 no-op 이 된다(실측). 프라이버시를 원하면 --config auto 자체를
#   고정 룰셋으로 바꿔야 한다 — 별건.
SAST_TIMEOUT="${SPECOPS_SAST_TIMEOUT:-180}"
SAST_EXTERNAL="${SPECOPS_SAST_EXTERNAL:-1}"
_sast_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_internal/run-bounded.sh"
if [ -f "$_sast_lib" ]; then
  # shellcheck source=/dev/null
  . "$_sast_lib"
else
  # 헬퍼 부재 = 상한 없음. 조용히 무제한이 되지 않도록 fallback 을 명시 정의한다.
  bounded_run() { shift; "$@"; }
  bounded_timed_out() { return 1; }
fi
sast_timeout_note=""

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
[ "$SAST_EXTERNAL" = 0 ] && ext_skip=1
# semgrep (변경 코드 SAST)
if [ "$ext_skip" = 0 ] && command -v semgrep >/dev/null 2>&1; then
  ran=1
  j=$(bounded_run "$SAST_TIMEOUT" semgrep --config auto --json --quiet "$TARGET" 2>/dev/null); src=$?
  if bounded_timed_out "$src"; then
    sast_timeout_note="${sast_timeout_note} semgrep(시간초과)"
    j='{}'
  elif [ "$src" -gt 1 ]; then
    # 하드 실패(rc≥2 = semgrep 에러: 네트워크 두절·설정 거부·인증 요구)도 표기한다.
    #   왜: 실패하면 j 가 비고 crit 이 0 인 채로 "SECURITY: crit=0" 이 나간다 — 스캔을 안 한 것과
    #   통과한 것이 구분되지 않는 **무음 통과**다. 시간초과와 같은 축으로 강등 표기한다.
    #   rc=1 은 제외 — semgrep 은 findings 존재를 1 로 낼 수 있어 정상 결과다.
    sast_timeout_note="${sast_timeout_note} semgrep(실행실패 rc=$src)"
    j='{}'
  fi
  [ -n "$j" ] || j='{}'
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
    bounded_run "$SAST_TIMEOUT" gitleaks detect --source "$TARGET" --no-git --no-banner --exit-code 0 --report-format json --report-path "$glrep" >/dev/null 2>&1
    glrc=$?
    # gitleaks 는 --exit-code 0 이라 정상 경로 rc 가 항상 0 — 0 이 아니면 시간초과이거나 실행 실패다.
    if bounded_timed_out "$glrc"; then
      sast_timeout_note="${sast_timeout_note} gitleaks(시간초과)"
    elif [ "$glrc" -ne 0 ]; then
      sast_timeout_note="${sast_timeout_note} gitleaks(실행실패 rc=$glrc)"
    fi
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
# 강등 사유 3종을 **전부** 표기한다 (20260828-sast-timeout 이 시간초과를 추가):
#   상한만 걸고 표기를 빠뜨리면 무한 정지가 "조용한 crit=0 통과" 로 바뀐다 — 정지보다 나쁘다.
ext_note=""
if [ -n "$sast_timeout_note" ]; then
  ext_note=" (외부 SAST 미반영 —${sast_timeout_note}, 상한 ${SAST_TIMEOUT}s)"
elif [ "$SAST_EXTERNAL" = 0 ]; then
  ext_note=" (self-check only — 외부 스캐너 비활성 SPECOPS_SAST_EXTERNAL=0)"
elif ! { command -v semgrep >/dev/null 2>&1 || command -v gitleaks >/dev/null 2>&1; }; then
  ext_note=" (self-check only — semgrep·gitleaks 미설치)"
fi
echo "SECURITY: crit=$crit high=$high med=$med$ext_note"
{ [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; } && exit 1 || exit 0
