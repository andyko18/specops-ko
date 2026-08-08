#!/usr/bin/env bash
# origin main 의 최근 완료 CI 결론을 조회해 red 면 경고한다 — 경고 전용, 절대 차단 없음.
#
# 계기: 2026-08-07, main 이 3커밋 연속 Linux CI red 였는데 아무도 몰랐다. 신호는
#       GitHub 에 있었으나 소비 지점이 없었다. /doctor 는 수동이라 3일간 아무도 안 돌렸다 —
#       push 는 자동으로 일어나므로 pre-push 를 소비 지점으로 삼는다.
#
# 계약: 항상 exit 0 · 파일 무생성(읽기 전용) · gh/jq 부재·미인증·오프라인·타임아웃 전부 무출력 skip
# 환경변수: SPECOPS_CI_CHECK_TIMEOUT (초, 기본 5)
set -uo pipefail

TIMEOUT_S="${SPECOPS_CI_CHECK_TIMEOUT:-5}"

# 선택 의존 — 하나라도 없으면 조용히 넘어간다 (NFR-4). 여기가 가장 앞이라야
# 이후 어떤 경로도 부재한 바이너리를 때리지 않는다.
command -v gh >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
# origin 부재 = 조회 대상 없음 (FR-4)
git remote get-url origin >/dev/null 2>&1 || exit 0

# GNU timeout 미의존 워치독 (bash 3.2 · macOS 기본 환경엔 timeout 이 없다).
#
# **자손 정리가 load-bearing 이다** — kill 은 래퍼 셸만 죽이고, 고아가 된 자식이 명령치환
# 파이프를 계속 물어 $( ) 가 반환되지 않는다. 실측(2026-08-08): 미적용 30.02s / 적용 1.05s.
# 정리가 아니라 동작 조건이다.
#
# `set -m` + `kill -- -$pid` (프로세스 그룹째)를 쓴다. `pkill -P "$pid"` 는 **직계 자식만**
# 죽여서 depth-2 손자가 파이프를 물면 타임아웃이 통째로 무력화된다 — Phase C 리뷰가
# `bash -c 'sleep 30; :'` stub 으로 실증했다(HANG 10s+ · 고아 sleep 잔존). 잡 컨트롤을 켜면
# 백그라운드 작업이 자기 프로세스 그룹의 리더가 되므로 `-$pid` 로 전 자손을 한 번에 잡는다.
# (`set +m` 즉시 복원 — 잡 컨트롤이 켜진 채로 두면 이후 파이프라인 동작이 달라진다.)
#
# wait 2>/dev/null: 비대화형 bash 가 kill 된 job 을 "Terminated" 로 stderr 에 보고한다.
# 이게 새면 AC-2(성공 시 stderr 비어 있음)가 깨진다.
_run_with_timeout() {  # $1=초, $2.. =명령 → 명령의 stdout 통과, rc 반환
  local t="$1"; shift
  local pid wpid rc
  set -m
  "$@" & pid=$!
  set +m
  # 그룹 kill 우선, 그래도 남으면 본체 직접 kill (그룹 생성 실패 환경 대비 이중화)
  ( sleep "$t"; kill -TERM -- "-$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ) >/dev/null 2>&1 & wpid=$!
  wait "$pid" 2>/dev/null; rc=$?
  # 워치독 먼저 죽인 뒤 그 자식(sleep)을 정리한다 — 역순이면 sleep 소멸 순간 깨어난
  # 워치독이 이미 reap 된 $pid 에 신호를 쏘는 race 가 생긴다 (Phase C Suggestion 1).
  kill "$wpid" 2>/dev/null; pkill -P "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
  return "$rc"
}

# --status completed --limit 1: FR-1 "최근 완료된 실행". spec §7 의 명령 예시엔 두 플래그가
# 없지만, 없으면 진행 중(in_progress) 실행의 conclusion 이 null 로 나와 판정이 무의미해진다.
raw=$(_run_with_timeout "$TIMEOUT_S" \
        gh run list --branch main --status completed --limit 1 \
           --json conclusion,headSha,url 2>/dev/null) || exit 0
[ -n "$raw" ] || exit 0

# sentinel 이 "-" 인 이유: 탭은 bash 의 IFS whitespace 라 **연속 구분자가 collapse** 된다.
# 빈 문자열 sentinel 을 쓰면 conclusion 이 없는 응답에서 sha 가 conclusion 칸으로,
# url 이 sha 칸으로 밀려 경고문이 오염된다 — Phase C 리뷰가 실측 실증했다
# (`결론: deadbeef00112233` / `커밋: https://exam`). 비어있지 않은 sentinel 이 시프트를 막는다.
tsv=$(printf '%s' "$raw" \
      | jq -r '.[0] | [(.conclusion // "-"), (.headSha // "-"), (.url // "-")] | @tsv' 2>/dev/null) || exit 0
IFS=$(printf '\t') read -r conclusion sha url <<< "$tsv"

# 분류 = allowlist. success 와 "값 없음"만 조용하고, 그 외는 전부 경고한다.
# 실패 결론을 이름으로 열거하면 GitHub 가 문자열을 추가·개명할 때 조용히 green 이 된다 —
# 워크플로 이름 하드코딩을 clarify Q2 가 기각한 것과 같은 실패 형태다.
#
# "-" 는 위 jq sentinel = **파싱 실패·필드 부재**를 뜻하므로 빈 값과 같은 취급이다
# (spec §7: "jq 가 빈 값을 내고 조용히 skip — 실패 방향이 안전하다"). 이건 allowlist 의
# 예외가 아니라 "결론을 못 읽은 상태" 를 결론 문자열로 오해하지 않는 것이다.
[ -n "${conclusion:-}" ] || exit 0
[ "$conclusion" = "-" ] && exit 0
[ "$conclusion" = "success" ] && exit 0

cat >&2 <<EOF
⚠️  origin/main 최근 CI 가 red 입니다 — 결론: $conclusion
    커밋: ${sha:0:12}
    실행: $url
    (경고 전용 — 이 push 는 계속 진행됩니다. red 위에 더 쌓기 전에 확인하세요.)
EOF
exit 0
