#!/usr/bin/env bash
# test-intent.sh — 기능 단위 intent.md 계약 (판정기 + 문서 잠금)
# FID 20260917-intent-md-adoption · AC-3·4·6·7·8·9·10·11
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
TPL="$PLUGIN/templates/intent.md"

# T-tpl.a: 5절 고정
_missing=""
for h in '## 문제' '## 기대 결과' '## 영향 사용자·시스템' '## 제약' '## 열린 질문'; do
  grep -qF "$h" "$TPL" || _missing="${_missing}${_missing:+ · }$h"
done
[ -z "$_missing" ] && ok "T-tpl.a 5절 고정" || nope "T-tpl.a" "누락: $_missing"

# T-tpl.b: Status 3값 + 열린 질문 없음 표기 규약
## `- 없음` 은 `--` 로 옵션 파싱을 끊는다 (plan-review 2회차 I-A: 안 끊으면 `grep: invalid option`)
grep -q 'Status' "$TPL" && grep -q 'accepted' "$TPL" && grep -qF -- '- 없음' "$TPL" \
  && ok "T-tpl.b Status·열린질문 없음 표기" || nope "T-tpl.b" "규약 문구 부재"

# T-tpl.c: spec 템플릿 추적 줄
grep -q 'intent\.md' "$PLUGIN/templates/spec.md" \
  && ok "T-tpl.c spec 템플릿 Intent 추적" || nope "T-tpl.c" "spec 템플릿 미갱신"
finish
