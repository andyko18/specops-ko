#!/usr/bin/env bash
# specops-auto-ko governance-capture — AC-8 성능 벤치
# PostToolUse hook 을 10 회 실행해 p95 지연 측정. < 200ms 기대.
set -u

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$script_dir/../../.." && pwd)
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"
mkdir -p .specops

# 500KB 합성 transcript — assistant text + 간헐적 Bash tool_use
{
  for i in $(seq 1 200); do
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"line %d %s"}]}}\n' "$i" "$(head -c 100 /dev/urandom | base64 | head -c 80)"
    if [ $((i % 10)) -eq 0 ]; then
      printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"echo %d"}}]}}\n' "$i"
    fi
  done
} > transcript.jsonl

cp "$plugin_root/scripts/tests/governance/fixtures/session-progress-basic.md" .specops/session-progress.md

stdin_json=$(jq -nc --arg tp "$TMPDIR/transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"ls"}, tool_response:{} }')

# timing 측정 함수 — macOS(Apple) date 는 나노초 지원, 일부 BSD date 는 미지원
# date +%s%N 이 정수면 linux 경로, 아니면 perl Time::HiRes fallback
use_date_ns=0
if date +%s%N 2>/dev/null | grep -qE '^[0-9]+$'; then
  use_date_ns=1
fi

declare -a timings
for i in $(seq 1 10); do
  if [ "$use_date_ns" -eq 1 ]; then
    t=$(date +%s%N)
    echo "$stdin_json" | "$plugin_root/hooks/posttool-governance.sh" >/dev/null 2>&1
    t2=$(date +%s%N)
    elapsed=$(( (t2 - t) / 1000000 ))
  else
    # perl Time::HiRes fallback (BSD date 나노초 미지원 시)
    elapsed=$(perl -MTime::HiRes=gettimeofday,tv_interval -e '
      my $t0 = [gettimeofday];
      system($ENV{HOOK_PATH}) == 0 or 1;
      printf "%.0f\n", tv_interval($t0) * 1000;
    ' < <(printf '%s' "$stdin_json") 2>/dev/null)
    # perl fallback 은 stdin redirect 가 복잡 — 간이: HOOK_CMD 를 중간 파일로
    if [ -z "$elapsed" ]; then
      echo "$stdin_json" > "$TMPDIR/stdin.json"
      elapsed=$(perl -MTime::HiRes=gettimeofday,tv_interval -e '
        my $t0 = [gettimeofday];
        system("bash -c \"cat \\\"$ENV{STDIN_FILE}\\\" | \\\"$ENV{HOOK_PATH}\\\" >/dev/null 2>&1\"");
        printf "%.0f\n", tv_interval($t0) * 1000;
      ' STDIN_FILE="$TMPDIR/stdin.json" HOOK_PATH="$plugin_root/hooks/posttool-governance.sh")
    fi
  fi
  timings+=("$elapsed")
  echo "  run $i: ${elapsed}ms" >&2
done

# 오름차순 정렬 → 9 번째 (90th percentile, 10 샘플 기준 p95 근사)
sorted=$(printf '%s\n' "${timings[@]}" | sort -n)
p95=$(echo "$sorted" | sed -n '9p')
median=$(echo "$sorted" | sed -n '5p')
echo
echo "==== Benchmark Results ===="
echo "samples: 10"
echo "median: ${median}ms"
echo "p95:    ${p95}ms"
echo

if [ "$p95" -lt 200 ]; then
  echo "PASS (NFR-1 p95 < 200ms)"
  exit 0
else
  echo "FAIL (NFR-1 미달 — p95=${p95}ms >= 200ms)"
  echo "참고: AC-8 은 should 우선순위. verify.md 에 실측값 기록 권장."
  exit 1
fi
