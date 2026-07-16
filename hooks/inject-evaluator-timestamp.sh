#!/usr/bin/env bash
# 평가자 아티팩트 timestamp 주입 — **timestamp**: 줄을 현재 ISO-8601로 교체 또는 추가
# 사용: hooks/inject-evaluator-timestamp.sh <artifact-path>
# 예: hooks/inject-evaluator-timestamp.sh .specops/20260520-foo/clarifications.md
set -u

artifact="${1:-}"
if [ -z "$artifact" ]; then
  echo "사용법: $0 <artifact-path>" >&2
  exit 1
fi

if [ ! -f "$artifact" ]; then
  echo "파일 없음: $artifact" >&2
  exit 1
fi

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if grep -q '^\*\*timestamp\*\*:' "$artifact"; then
  sed -i.bak "s|^\*\*timestamp\*\*:.*|\*\*timestamp\*\*: ${ts}|" "$artifact"
  rm -f "${artifact}.bak"
else
  # **status**: 줄 바로 뒤에 삽입 (없으면 파일 끝에 추가)
  # awk 전환 (T2.e2): BSD sed `a\` 는 삽입 텍스트 뒤 개행을 안 붙여 다음 줄이
  # "**timestamp**: ...Zbody" 로 융합됐다. awk print 는 항상 개행 — BSD/GNU 무차이.
  if grep -q '^\*\*status\*\*:' "$artifact"; then
    tmp_out="${artifact}.tmp.$$"
    awk -v ts="$ts" '{print} /^\*\*status\*\*:/ && !done {print "**timestamp**: " ts; done=1}' \
      "$artifact" > "$tmp_out" && mv "$tmp_out" "$artifact"
  else
    printf '\n**timestamp**: %s\n' "$ts" >> "$artifact"
  fi
fi
echo "timestamp injected: $ts → $artifact"
