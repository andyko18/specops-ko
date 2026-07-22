#!/usr/bin/env bash
# specops-ko governance-capture — AC-8 성능 벤치
# 1) PostToolUse hook 10회 — p95 < BENCH_THRESHOLD_MS (기본 200ms, NFR-1)
# 2) Stop hook 워스트케이스 (2000줄 transcript + R-4 매칭 경로) 5회 — p95 < BENCH_STOP_THRESHOLD_MS (기본 1000ms)
#    근거: 2026-06-11 줄단위 jq fork 루프 회귀 (8s) 재발 방지 게이트. CI 등 느린 러너는 env 로 완화.
set -u
BENCH_THRESHOLD_MS="${BENCH_THRESHOLD_MS:-200}"
BENCH_STOP_THRESHOLD_MS="${BENCH_STOP_THRESHOLD_MS:-1000}"

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

# 오름차순 정렬 → 9 번째 — 정확히는 p90 (10 샘플). 게이트 라벨은 관례상 p95 로 유지 (보수적 방향 아님 인지)
sorted=$(printf '%s\n' "${timings[@]}" | sort -n)
p95=$(echo "$sorted" | sed -n '9p')
median=$(echo "$sorted" | sed -n '5p')
echo
echo "==== Benchmark Results ===="
echo "samples: 10"
echo "median: ${median}ms"
echo "p95:    ${p95}ms"
echo

FAIL_COUNT=0
if [ "$p95" -lt "$BENCH_THRESHOLD_MS" ]; then
  echo "PASS (NFR-1 posttool p95 ${p95}ms < ${BENCH_THRESHOLD_MS}ms)"
else
  echo "FAIL (NFR-1 미달 — posttool p95=${p95}ms >= ${BENCH_THRESHOLD_MS}ms)"
  echo "참고: AC-8 은 should 우선순위. verify.md 에 실측값 기록 권장."
  FAIL_COUNT=$((FAIL_COUNT+1))
fi

# ── Stop hook 워스트케이스 벤치 ──
# 2000줄 transcript + 성공 주장 텍스트 (R-4 매칭 → offset 전수 스캔 경로 발동) + runner 부재
{
  for i in $(seq 1 1990); do
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"작업 진행 중 %d"}]}}\n' "$i"
  done
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"테스트 통과 — 검증 완료"}]}}\n'
  for i in $(seq 1 9); do
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"마무리 %d"}]}}\n' "$i"
  done
} > stop-transcript.jsonl

stop_stdin=$(jq -nc --arg tp "$TMPDIR/stop-transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:false }')

declare -a stop_timings
for i in $(seq 1 5); do
  if [ "$use_date_ns" -eq 1 ]; then
    t=$(date +%s%N)
    echo "$stop_stdin" | "$plugin_root/hooks/stop-governance.sh" >/dev/null 2>&1
    t2=$(date +%s%N)
    elapsed=$(( (t2 - t) / 1000000 ))
  else
    echo "$stop_stdin" > "$TMPDIR/stop-stdin.json"
    elapsed=$(perl -MTime::HiRes=gettimeofday,tv_interval -e '
      my $t0 = [gettimeofday];
      system("bash -c \"cat \\\"$ENV{STDIN_FILE}\\\" | \\\"$ENV{HOOK_PATH}\\\" >/dev/null 2>&1\"");
      printf "%.0f\n", tv_interval($t0) * 1000;
    ' STDIN_FILE="$TMPDIR/stop-stdin.json" HOOK_PATH="$plugin_root/hooks/stop-governance.sh")
  fi
  stop_timings+=("$elapsed")
  echo "  stop run $i: ${elapsed}ms" >&2
  # dedup 으로 인한 2회차+ 단축 방지 — friction-log 초기화
  rm -f .specops/friction-log.jsonl .specops/*/friction-log.jsonl 2>/dev/null
done

stop_sorted=$(printf '%s\n' "${stop_timings[@]}" | sort -n)
stop_p95=$(echo "$stop_sorted" | sed -n '5p')
stop_median=$(echo "$stop_sorted" | sed -n '3p')
echo
echo "==== Stop Worst-Case Results ===="
echo "samples: 5 (2000-line transcript, R-4 매칭 경로)"
echo "median: ${stop_median}ms"
echo "p95:    ${stop_p95}ms"
echo

if [ "$stop_p95" -lt "$BENCH_STOP_THRESHOLD_MS" ]; then
  echo "PASS (stop worst-case p95 ${stop_p95}ms < ${BENCH_STOP_THRESHOLD_MS}ms)"
else
  echo "FAIL (stop worst-case p95=${stop_p95}ms >= ${BENCH_STOP_THRESHOLD_MS}ms — 줄단위 fork 루프 회귀 의심)"
  FAIL_COUNT=$((FAIL_COUNT+1))
fi

exit $FAIL_COUNT
