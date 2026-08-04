#!/usr/bin/env bash
# 비용·수율 계측 기반 — 제한된 메타데이터 스키마와 안전한 JSONL append
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
REC="$PLUGIN/scripts/_internal/record-metric.sh"

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/.specops/20260803-metrics"

(cd "$TD" && bash "$REC" \
  --fid 20260803-metrics --task T2 --phase verify --model claude-test \
  --input-tokens 100 --output-tokens 20 --cache-read-tokens 50 --cache-write-tokens 5 \
  --wall-ms 1234 --retry-count 1 --timeout false --fallback true \
  --verdict PASS --finding-severity high --fixed true)
LOG="$TD/.specops/20260803-metrics/metrics.jsonl"

if [ -f "$LOG" ] && jq -e '
  .schema_version == 1 and .fid == "20260803-metrics" and .task == "T2"
  and .phase == "verify" and .model == "claude-test"
  and .tokens.input == 100 and .tokens.output == 20
  and .tokens.cache_read == 50 and .tokens.cache_write == 5
  and .wall_ms == 1234 and .retry_count == 1
  and .timeout == false and .fallback == true
  and .verdict == "PASS" and .finding_severity == "high" and .fixed == true
' "$LOG" >/dev/null; then
  ok "M1 구조화 계측 JSONL 기록"
else
  nope "M1" "log=$(cat "$LOG" 2>/dev/null)"
fi

# 원문을 받을 수 있는 임의 필드는 거부한다.
if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify --prompt "secret" >/dev/null 2>&1); then
  nope "M2" "미등록 prompt 필드가 수락됨"
else
  ok "M2 미등록·원문 필드 거부"
fi

# 숫자/enum 검증 실패는 append 전에 중단한다.
before=$(wc -l < "$LOG" | tr -d ' ')
if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify --input-tokens nope >/dev/null 2>&1); then
  nope "M3" "잘못된 숫자가 수락됨"
else
  after=$(wc -l < "$LOG" | tr -d ' ')
  [ "$before" = "$after" ] && ok "M3 잘못된 값은 무기록" || nope "M3" "before=$before after=$after"
fi

# path escape와 symlink write-through를 거부한다.
if (cd "$TD" && bash "$REC" --fid ../escape --phase verify >/dev/null 2>&1); then
  nope "M4a" "잘못된 FID 수락"
else
  ok "M4a 잘못된 FID 거부"
fi
mkdir -p "$TD/outside"
ln -s "$TD/outside" "$TD/.specops/20260803-link"
if (cd "$TD" && bash "$REC" --fid 20260803-link --phase verify >/dev/null 2>&1); then
  nope "M4b" "FID symlink 수락"
else
  ok "M4b FID symlink 거부"
fi

# task/model은 식별자만 허용한다 (자유 텍스트·원문 거부).
before=$(wc -l < "$LOG" | tr -d ' ')
if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify --task "secret prompt" >/dev/null 2>&1); then
  nope "M4c" "공백 포함 task가 수락됨"
else
  after=$(wc -l < "$LOG" | tr -d ' ')
  [ "$before" = "$after" ] && ok "M4c task 자유 텍스트 거부" || nope "M4c" "before=$before after=$after"
fi

# BYPASS 수율 계측 — 거버넌스 헬퍼가 phase=governance-bypass만 남기고 사유 원문은 받지 않는다.
source "$PLUGIN/hooks/governance-lib.sh"
mkdir -p "$TD/.specops/20260803-bypass"
(cd "$TD" && _record_bypass_metric 20260803-bypass)
BLOG="$TD/.specops/20260803-bypass/metrics.jsonl"
if [ -f "$BLOG" ] && jq -e '
  .phase == "governance-bypass" and .fallback == true
  and .verdict == null and (.tokens.input == null)
' "$BLOG" >/dev/null; then
  ok "M5 BYPASS 계측(식별자만)"
else
  nope "M5" "blog=$(cat "$BLOG" 2>/dev/null)"
fi
(cd "$TD" && _record_bypass_metric "")
(cd "$TD" && _record_bypass_metric "../escape")
[ "$(wc -l < "$BLOG" | tr -d ' ')" = "1" ] && ok "M5b 빈/잘못된 FID no-op" || nope "M5b" "lines=$(wc -l < "$BLOG")"

# M6: evaluator-degradation phase 기록 + 스킬/커맨드 배선
(cd "$TD" && bash "$REC" \
  --fid 20260803-metrics --task T1 --phase evaluator-degradation \
  --fallback true --model claude-sonnet-override)
if jq -e 'select(.phase=="evaluator-degradation" and .fallback==true and .model=="claude-sonnet-override")' \
     "$LOG" >/dev/null; then
  ok "M6a evaluator-degradation JSONL"
else
  nope "M6a" "log=$(cat "$LOG")"
fi
grep -q 'evaluator-degradation' "$PLUGIN/skills/implementing-ko/SKILL.md" \
  && grep -q 'evaluator-degradation' "$PLUGIN/commands/start-all.md" \
  && ok "M6b implementing-ko·start-all 배선" \
  || nope "M6b" "doc wiring missing"

finish
