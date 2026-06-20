#!/usr/bin/env bash
# DAST 래퍼 — nuclei > ZAP(docker) > nikto, graceful skip (critic-ask.sh 패턴)
set -u
URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: dast-scan.sh <URL>   (대상 서버는 본인 소유여야 함 — 능동 스캔)" >&2
  exit 2
fi
# 테스트/CI 격리 (plan-reviewer Critical) — 실 docker run/nuclei 없이 도구 탐지·분기만 검증.
# run-all glob 자동편입 게이트가 무거운 실 스캔(128s pull·31s 스캔·네트워크 의존) 떠안는 것 차단.
if [ "${SPECOPS_DAST_NO_RUN:-0}" = "1" ]; then
  for t in nuclei zap-baseline.py nikto docker; do
    command -v "$t" >/dev/null 2>&1 && { echo "DAST: DRY (도구 $t 감지 — 실 스캔 skip, NO_RUN)"; exit 0; }
  done
  echo "DAST: SKIP (nuclei·ZAP·nikto·docker 미설치 — graceful skip)"
  exit 0
fi
crit=0; high=0; ran=0; manual=0
rep=$(mktemp "${TMPDIR:-/tmp}/specops-dast.XXXXXX") || rep=""
[ -n "$rep" ] && trap 'rm -f "$rep"' EXIT
# grep -c 안전 집계 — 0매치 시 stdout '0'+exit1 이라 `|| echo 0` 은 '0\n0' 산술오류(code-reviewer I-1).
# `|| true` 로 exit 만 무시(grep -c 가 숫자 1줄 보장), 빈값은 ${:-0}.
_cnt() { local c; c=$(grep -c "$1" "$2" 2>/dev/null || true); printf '%s' "${c:-0}"; }
if command -v nuclei >/dev/null 2>&1; then
  ran=1
  nuclei -u "$URL" -jsonl -silent -o "$rep" >/dev/null 2>&1 || true
  if [ -s "$rep" ]; then
    crit=$((crit + $(_cnt '"severity":"critical"' "$rep")))
    high=$((high + $(_cnt '"severity":"high"' "$rep")))
  fi
elif command -v zap-baseline.py >/dev/null 2>&1; then
  ran=1
  zap-baseline.py -t "$URL" -J "$rep" >/dev/null 2>&1 || true
  [ -s "$rep" ] && command -v jq >/dev/null 2>&1 && high=$((high + $(jq '[.site[]?.alerts[]?|select(.riskcode|tonumber>=3)]|length' "$rep" 2>/dev/null || echo 0)))
elif command -v docker >/dev/null 2>&1; then
  ran=1
  # ZAP docker baseline (graceful — 이미지 없으면 실패 무시)
  docker run --rm -v "$(dirname "$rep")":/zap/wrk/:rw -t zaproxy/zap-stable zap-baseline.py -t "$URL" -J "$(basename "$rep")" >/dev/null 2>&1 || true
  [ -s "$rep" ] && command -v jq >/dev/null 2>&1 && high=$((high + $(jq '[.site[]?.alerts[]?|select(.riskcode|tonumber>=3)]|length' "$rep" 2>/dev/null || echo 0)))
elif command -v nikto >/dev/null 2>&1; then
  ran=1
  nikto -h "$URL" -Format json -o "$rep" >/dev/null 2>&1 || true
  manual=1  # nikto severity 자동 집계 미지원 — clean 오보 방지(code-reviewer I-2)
fi
if [ "$ran" = 0 ]; then
  echo "DAST: SKIP (nuclei·ZAP·nikto·docker 미설치 — graceful skip)"
  exit 0
fi
if [ "$manual" = 1 ]; then
  # nikto 는 심각도 자동 집계 불가 → clean(exit 0) 오보 금지. 수동 확인 요구(5원칙 5).
  echo "DAST: MANUAL (nikto 결과 자동 집계 미지원 — 리포트 수동 확인 필요, 대상 $URL)" >&2
  echo "DAST: crit=? high=? (nikto — 수동 확인)"
  exit 1
fi
echo "DAST: crit=$crit high=$high (대상 $URL)"
{ [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; } && exit 1 || exit 0
