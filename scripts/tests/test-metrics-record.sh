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
  --wall-ms 1234 --retry-count 1 --fallback true \
  --verdict PASS --finding-severity high)
LOG="$TD/.specops/20260803-metrics/metrics.jsonl"

# M1 — 유지 필드 보존 + schema_version 2 (AC-3 · AC-R-1)
if [ -f "$LOG" ] && jq -e '
  .schema_version == 2 and .fid == "20260803-metrics" and .task == "T2"
  and .phase == "verify" and .model == "claude-test"
  and .wall_ms == 1234 and .retry_count == 1 and .fallback == true
  and .verdict == "PASS" and .finding_severity == "high"
' "$LOG" >/dev/null; then
  ok "M1 유지 필드 보존 + schema_version 2"
else
  nope "M1" "log=$(cat "$LOG" 2>/dev/null)"
fi

# M1b — 죽은 필드 3종 키가 아예 없다 (AC-1)
#   FID 20260903-metrics-dead-fields: tokens 4필드는 bash 가 관측 불가라 150/150 null 이었고,
#   fixed 는 배선 0, timeout 은 상수 false 였다. 빈 칸은 "측정 중" 이라는 착시를 준다.
if jq -e 'has("tokens") or has("timeout") or has("fixed") | not' "$LOG" >/dev/null; then
  ok "M1b 죽은 필드 키 부재 (tokens·timeout·fixed)"
else
  nope "M1b" "잔존 키=$(jq -r 'keys_unsorted|join(",")' "$LOG" 2>/dev/null)"
fi

# M1c — 유지 키 집합이 정확히 일치 (AC-R-1 — 과잉 제거 방지)
_want='schema_version,ts,fid,task,phase,model,wall_ms,retry_count,fallback,verdict,finding_severity'
_got=$(jq -r 'keys_unsorted|join(",")' "$LOG" 2>/dev/null)
if [ "$_got" = "$_want" ]; then
  ok "M1c 유지 키 집합 정확 일치 (11키)"
else
  nope "M1c" "want=$_want got=$_got"
fi

# M1d — 제거된 플래그는 조용히 무시되지 않고 비0 종료 (AC-2)
#   조용히 무시하면 호출자가 값이 기록된 줄 안다 — 그게 이 FID 가 고치는 병이다.
#   ★ 값은 반드시 **유효한 것**을 쓴다 — 잘못된 값(예: --input-tokens x)은 구 구현에서도
#     값 검증에 걸려 비0 이라 구/신을 가리지 못한다(판별력 0). 유효값이어야 "플래그가
#     사라졌는가" 만 시험한다. (실측: 무효값 판은 구 구현에서도 PASS 했다.)
_bad=0
while IFS='|' read -r _f _v; do
  [ -n "$_f" ] || continue
  if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify "$_f" "$_v" >/dev/null 2>&1); then
    _bad=$((_bad+1)); echo "  (수락됨: $_f $_v)"
  fi
done <<'EOF_FLAGS'
--input-tokens|100
--timeout|false
--fixed|true
EOF_FLAGS
[ "$_bad" -eq 0 ] && ok "M1d 제거된 플래그 3종 거부" || nope "M1d" "수락된 플래그 ${_bad}건"

# 원문을 받을 수 있는 임의 필드는 거부한다.
if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify --prompt "secret" >/dev/null 2>&1); then
  nope "M2" "미등록 prompt 필드가 수락됨"
else
  ok "M2 미등록·원문 필드 거부"
fi

# 숫자/enum 검증 실패는 append 전에 중단한다.
before=$(wc -l < "$LOG" | tr -d ' ')
if (cd "$TD" && bash "$REC" --fid 20260803-metrics --phase verify --wall-ms nope >/dev/null 2>&1); then
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
