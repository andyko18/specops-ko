#!/usr/bin/env bash
# foundation-kind.sh — UI/BE/풀스택/모바일이면 foundation 필수 KIND (20260812)
# source 전용. 호출: foundation_kind_is_required → 0=필수 · 1=비필수
#
# SoT: check-foundation-present / check-foundation-merged 가 공유.
# SPECOPS_ROOT 또는 cwd 의 .specops/memory 를 본다.
# shellcheck shell=bash

_fk_uninformative() {
  local v="$1"
  [ -z "$v" ] && return 0
  printf '%s' "$v" | grep -qE '^<[^>]*>$' && return 0
  printf '%s' "$v" | grep -qE '^(TBD|tbd|N/A|n/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$' && return 0
  printf '%s' "$v" | grep -qE '^<미확정' && return 0
  return 1
}

foundation_kind_is_required() {
  local mem="${SPECOPS_ROOT:-.specops}/memory"
  local ledger="$mem/decisions.md"
  local ctx="$mem/project-context.md"

  [ -f "$mem/frontend-architecture.md" ] && return 0
  [ -f "$mem/backend-architecture.md" ] && return 0

  if [ -f "$ledger" ]; then
    local rows topic value
    rows=$(awk -F'|' '
      /^\|/ {
        if ($2 ~ /DECISION-ID/) next
        if ($2 ~ /^[[:space:]]*-+[[:space:]]*$/) next
        if (NF < 4) next
        topic = $3; value = $4
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", topic)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        if (topic == "") next
        if (topic ~ /^\(예시\)/) next
        if (value == "") next
        if (value ~ /^<[^>]*>$/) next
        if (value ~ /^(TBD|tbd|N\/A|n\/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$/) next
        print topic "|" value
      }
    ' "$ledger")
    while IFS='|' read -r topic value; do
      [ -n "$topic" ] || continue
      if printf '%s' "$topic" | grep -q 'UI 유무'; then
        printf '%s' "$value" | grep -q '있음' && return 0
      fi
      if printf '%s' "$topic" | grep -q '프로젝트 종류'; then
        printf '%s' "$value" | grep -qE '풀스택|Web|UI|BE|API|모바일|Mobile|프론트|백엔드' && return 0
      fi
    done <<EOF
$rows
EOF
  fi

  if [ -f "$ctx" ]; then
    local area value
    while IFS='|' read -r _ area value _; do
      area=$(printf '%s' "$area" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if printf '%s' "$area" | grep -q 'UI 유무'; then
        printf '%s' "$value" | grep -q '있음' && return 0
      fi
      if printf '%s' "$area" | grep -qE '^(프론트|백엔드)$'; then
        _fk_uninformative "$value" && continue
        printf '%s' "$value" | grep -qiE '없음|해당[[:space:]]*없음|N/A' && continue
        [ -n "$value" ] && return 0
      fi
    done <<EOF
$(grep -E '^\|[[:space:]]*[^|]+[[:space:]]*\|' "$ctx" 2>/dev/null)
EOF
  fi

  return 1
}
