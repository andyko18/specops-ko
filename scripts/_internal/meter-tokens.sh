#!/usr/bin/env bash
# meter-tokens.sh — FID 구간 토큰 사용량 관측 (관측 전용 · fail-open)
# Usage:
#   meter-tokens.sh <FID> [--session <uuid>] [--since <ISO>] [--transcript <path>]
#   meter-tokens.sh --report [<FID>]
# 런타임 실패는 항상 exit 0(무기록 또는 unmeasured 레코드). 인자 오류만 exit 2.
# jq 검사는 어떤 외부 명령보다 먼저 — PATH 가 비어도 stderr 로 새지 않게 한다.
command -v jq >/dev/null 2>&1 || exit 0
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
MODE=record; FID=""; SESSION_ARG=""; SINCE_ARG=""; TRANSCRIPT_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --report)     MODE=report; shift ;;
    --session)    [ "$#" -ge 2 ] || exit 2; SESSION_ARG="$2"; shift 2 ;;
    --since)      [ "$#" -ge 2 ] || exit 2; SINCE_ARG="$2"; shift 2 ;;
    --transcript) [ "$#" -ge 2 ] || exit 2; TRANSCRIPT_ARG="$2"; shift 2 ;;
    -*) echo "meter-tokens: unknown option: $1" >&2; exit 2 ;;
    *)  FID="$1"; shift ;;
  esac
done

if [ "$MODE" = record ]; then
  [ -n "$FID" ] || { echo "usage: meter-tokens.sh <FID> | --report [<FID>]" >&2; exit 2; }
fi
if [ -n "$FID" ]; then
  printf '%s' "$FID" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || { echo "meter-tokens: invalid FID" >&2; exit 2; }
fi

# 기록 모드: symlink 거부(record-metric.sh:56 의 검사 조건 차용 — meter 는 fail-open 이라 종료는 0)
if [ "$MODE" = record ]; then
  [ ! -L "$SPECOPS" ] && [ ! -L "$SPECOPS/$FID" ] || exit 0
  MET="$SPECOPS/$FID/metrics.jsonl"; TOK="$SPECOPS/$FID/tokens.jsonl"
  [ ! -L "$MET" ] && [ ! -L "$TOK" ] || exit 0
  # 기준점: --since 우선, 없으면 metrics.jsonl 의 첫 phase=fid-start. 없으면 transcript 를 열지 않고 종료.
  if [ -n "$SINCE_ARG" ]; then
    BASE="$SINCE_ARG"
  else
    [ -f "$MET" ] || exit 0
    BASE=$(jq -r 'select(.phase=="fid-start") | .ts' "$MET" 2>/dev/null | head -1)
  fi
  [ -n "${BASE:-}" ] || exit 0
  # 집계·기록은 다음 태스크에서 추가한다.
  exit 0
fi
exit 0
