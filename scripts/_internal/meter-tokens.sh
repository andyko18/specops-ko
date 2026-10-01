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
  SCOPE=fid-window
  if [ -n "$SINCE_ARG" ]; then
    BASE="$SINCE_ARG"; SCOPE=since-manual
  else
    [ -f "$MET" ] || exit 0
    BASE=$(jq -r 'select(.phase=="fid-start") | .ts' "$MET" 2>/dev/null | head -1)
  fi
  [ -n "${BASE:-}" ] || exit 0

  # 세션 확정 — 이후의 모든 unmeasured 사유 레코드가 이 SID 로 기록된다(비면 "unknown")
  SID="${SESSION_ARG:-${CLAUDE_CODE_SESSION_ID:-}}"
  if [ -n "$TRANSCRIPT_ARG" ] && [ -z "$SID" ]; then SID=$(basename "$TRANSCRIPT_ARG" .jsonl); fi
  E=$(date -u +%s); NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)   # E 먼저 — window_end(NOW) ≥ 필터 상한 E

  # 같은 세션의 기존 레코드를 모두 제거하고 새 레코드를 추가(upsert) — tmp 파일 후 mv
  _upsert() {
    local newrec="$1" tmp="$TOK.tmp.$$" old=""
    if [ -f "$TOK" ]; then
      old=$(jq -c --arg s "${SID:-unknown}" 'select(.session != $s)' "$TOK" 2>/dev/null) || return 0
    fi
    { [ -n "$old" ] && printf '%s\n' "$old"; cat "$newrec"; } > "$tmp" 2>/dev/null \
      && mv "$tmp" "$TOK" 2>/dev/null || rm -f "$tmp" 2>/dev/null
    return 0
  }

  # _unmeasured <reason> — 토큰 필드 없이 사유만 기록(착시 방지). fid-start 가 있는데 측정 못 한 경우에만 호출.
  _unmeasured() {
    local nr; nr=$(mktemp "${TMPDIR:-/tmp}/meter-tokens.XXXXXX") || exit 0
    jq -nc --arg ts "$NOW" --arg fid "$FID" --arg sid "${SID:-unknown}" --arg r "$1" \
      '{schema_version:1,ts:$ts,fid:$fid,session:$sid,status:"unmeasured",reason:$r}' > "$nr"
    _upsert "$nr"; rm -f "$nr"; exit 0
  }

  _epoch() { jq -rn --arg t "$1" '$t | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' 2>/dev/null; }
  S=$(_epoch "$BASE")
  case "$S" in ''|*[!0-9]*) _unmeasured bad-baseline ;; esac

  # transcript 탐색 — cwd 유도 금지, glob 사용
  TR=""
  if [ -n "$TRANSCRIPT_ARG" ]; then
    TR="$TRANSCRIPT_ARG"
  elif [ -n "$SID" ] && printf '%s' "$SID" | grep -qE '^[A-Za-z0-9._-]+$'; then
    ROOT="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/projects"
    for f in "$ROOT"/*/"$SID.jsonl"; do [ -f "$f" ] && { TR="$f"; break; }; done
  fi
  if [ -z "$TRANSCRIPT_ARG" ] && [ -z "$SID" ]; then _unmeasured no-session-id; fi
  [ -n "$TR" ] && [ -f "$TR" ] || _unmeasured transcript-not-found

  AGG_JQ='
    [ inputs | (fromjson? // empty)
      | select(type == "object" and .type == "assistant" and (.message.id? != null) and (.message.usage? != null))
      | (try (.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch null) as $t
      | select($t != null and $t >= $s and $t <= $e)
      | { id: .message.id, model: (.message.model // "unknown"),
          i: (.message.usage.input_tokens // 0), o: (.message.usage.output_tokens // 0),
          cr: (.message.usage.cache_read_input_tokens // 0),
          cw: (.message.usage.cache_creation_input_tokens // 0) } ] as $all
    | ($all | map(select(.model == "<synthetic>")) | group_by(.id) | length) as $syn
    | ($all | map(select(.model != "<synthetic>")) | group_by(.id)
        | map({ model: .[0].model, i: (map(.i) | max), o: (map(.o) | max),
                cr: (map(.cr) | max), cw: (map(.cw) | max) })
        | group_by(.model)
        | map({ model: .[0].model, messages: length, input: (map(.i) | add), output: (map(.o) | add),
                cache_read: (map(.cr) | add), cache_write: (map(.cw) | add) })) as $rows
    | { rows: $rows, synthetic_excluded: $syn }'
  _agg() { jq -nRc --argjson s "$S" --argjson e "$E" "$AGG_JQ" "$1" 2>/dev/null; }

  # _records <file> <agent> <agent_model|""> <overlap|""> — 레코드 JSON 줄을 stdout 으로
  _records() {
    local res; res=$(_agg "$1") || return 0
    [ -n "$res" ] || return 0
    printf '%s' "$res" | jq -c --arg ts "$NOW" --arg fid "$FID" --arg sid "$SID" --arg agent "$2" \
      --arg am "$3" --arg ov "$4" --arg scope "$SCOPE" --arg ws "$BASE" --arg we "$NOW" '
      . as $r | $r.rows[] |
      { schema_version: 1, ts: $ts, fid: $fid, session: $sid, agent: $agent, model: .model, scope: $scope,
        window_start: $ws, window_end: $we, messages: .messages, input: .input, output: .output,
        cache_read: .cache_read, cache_write: .cache_write, dedupe: "max-per-message-id" }
      + (if $am != "" then { agent_model: $am } else {} end)
      + (if $ov != "" then { overlap_other_sessions: ($ov | tonumber), synthetic_excluded: $r.synthetic_excluded } else {} end)'
  }

  NEWREC=$(mktemp "${TMPDIR:-/tmp}/meter-tokens.XXXXXX") || exit 0
  trap 'rm -f "$NEWREC"' EXIT
  PDIR=$(dirname "$TR")
  M=$(( (E - S) / 60 + 1 ))
  OV=$(find "$PDIR" -maxdepth 1 -name '*.jsonl' ! -name "$(basename "$TR")" -mmin "-$M" 2>/dev/null | wc -l | tr -d ' ')
  _records "$TR" main "" "${OV:-0}" >> "$NEWREC"
  SUBDIR="${TR%.jsonl}/subagents"
  if [ -d "$SUBDIR" ]; then
    for sf in "$SUBDIR"/agent-*.jsonl; do
      [ -f "$sf" ] || continue
      aid=$(basename "$sf" .jsonl); aid=${aid#agent-}
      aid=$(printf '%s' "$aid" | tr -c 'A-Za-z0-9._-' '_')
      atype=unknown; amodel=unknown
      meta="${sf%.jsonl}.meta.json"
      if [ -f "$meta" ]; then
        atype=$(jq -r '.agentType // "unknown"' "$meta" 2>/dev/null) || atype=unknown
        amodel=$(jq -r '.model // "unknown"' "$meta" 2>/dev/null) || amodel=unknown
        [ -n "$atype" ] || atype=unknown
        [ -n "$amodel" ] || amodel=unknown
        atype=$(printf '%s' "$atype" | tr -c 'A-Za-z0-9._-' '_')
        amodel=$(printf '%s' "$amodel" | tr -c 'A-Za-z0-9._/@+-' '_')
      fi
      _records "$sf" "$atype:$aid" "$amodel" "" >> "$NEWREC"
    done
  fi
  [ -s "$NEWREC" ] || _unmeasured no-messages-in-window
  _upsert "$NEWREC"
  exit 0
fi

# 조회 모드: tokens.jsonl 만 읽는다(transcript·config 미접근, 기록 없음)
if [ "$MODE" = report ]; then
  _fid_line() { # <FID> — FID 생략 모드의 1줄 요약
    local f="$SPECOPS/$1/tokens.jsonl" rs
    [ -f "$f" ] && [ ! -L "$f" ] || return 0
    if jq -e 'select(.status==null)' "$f" >/dev/null 2>&1; then
      jq -rs --arg fid "$1" '[.[]|select(.status==null)] as $m
        | "\($fid)  input=\($m|map(.input)|add) output=\($m|map(.output)|add) cache_read=\($m|map(.cache_read)|add) cache_write=\($m|map(.cache_write)|add) sessions=\($m|map(.session)|unique|length)"' "$f"
    else
      rs=$(jq -r 'select(.status=="unmeasured")|.reason' "$f" | sort -u | paste -sd, -)
      printf '%s  측정 안 됨 (%s)\n' "$1" "${rs:-사유 없음}"
    fi
  }
  if [ -z "$FID" ]; then
    for tf in "$SPECOPS"/*/tokens.jsonl; do
      [ -f "$tf" ] || continue
      _fid_line "$(basename "$(dirname "$tf")")"
    done
    exit 0
  fi
  f="$SPECOPS/$FID/tokens.jsonl"
  if [ ! -f "$f" ] || [ -L "$f" ]; then printf '%s  측정 안 됨 (기록 없음)\n' "$FID"; exit 0; fi
  if ! jq -e 'select(.status==null)' "$f" >/dev/null 2>&1; then _fid_line "$FID"; exit 0; fi
  echo "SESSION  AGENT  MODEL  MESSAGES  INPUT  OUTPUT  CACHE_READ  CACHE_WRITE"
  jq -r 'select(.status==null) | [.session[0:8], .agent, .model, .messages, .input, .output, .cache_read, .cache_write] | @tsv' "$f" \
    | awk -F'\t' '{ printf "%s  %s  %s  %s  %s  %s  %s  %s\n", $1,$2,$3,$4,$5,$6,$7,$8
                    m+=$4; i+=$5; o+=$6; cr+=$7; cw+=$8 }
                  END { printf "TOTAL  -  -  %d  %d  %d  %d  %d\n", m,i,o,cr,cw }'
  echo "※ 중복 제거: message.id 별 최댓값(max-per-message-id) — 줄 합산이 아님"
  echo "※ advisor 도구 호출 토큰은 usage 에 나타나지 않아 미포함"
  echo "※ 포함 세션: $(jq -r 'select(.status==null)|.session[0:8]' "$f" | sort -u | paste -sd, -)"
  ov=$(jq -r 'select(.overlap_other_sessions!=null)|.overlap_other_sessions' "$f" | sort -n | tail -1)
  [ "${ov:-0}" -gt 0 ] && echo "※ 구간과 겹치는 다른 세션 ${ov}개 미포함 (--session <uuid> 로 추가)"
  exit 0
fi
exit 0
