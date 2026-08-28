#!/usr/bin/env bash
# run-bounded.sh — 시간 상한 실행 공용 헬퍼 (FID 20260828-sast-timeout)
#
# 사용: source "$PLUGIN/scripts/_internal/run-bounded.sh"
#         bounded_run <초> <명령...>      → 명령 rc · 시간초과 = 124
#         bounded_timed_out <rc>          → 124 면 0(참)
# 소스 전용 — 함수만 정의한다(main 없음). run-all.sh(스위트별)·security-scan.sh(외부 스캐너)가 소비.
#
# 왜 필요한가 (실측):
#   `semgrep --config auto` 는 레지스트리에서 룰을 받는 **네트워크 호출**이고 자체 상한이 없다.
#   run-all.sh 에도 스위트별 상한이 없어, 네트워크가 막히면 `git push`(pre-push 훅)와
#   릴리즈 pre-flight 가 통째로 무한 정지했다 — 1줄 .py 대상 semgrep 이 30초 alarm 에 미완료,
#   run-all 은 test-security-scan 에서 8분+ 무출력. CI(ubuntu)는 semgrep 미설치라 graceful skip
#   되므로 **로컬 개발 환경에서만 발화하는 함정**이었다.
#
# ★ 왜 GNU timeout 도 perl alarm 도 아닌 워치독인가 — **자손 정리가 동작 조건이다**:
#   둘 다 대상 프로세스 하나만 죽인다. 대상이 래퍼 셸(`#!/usr/bin/env bash` 스크립트)이면
#   고아가 된 손자가 명령치환 파이프를 계속 물어 `$( )` 가 반환되지 않는다 — 상한을 걸었는데
#   호출부는 그대로 멈춘다. 실측(이 FID): `sleep 99` stub 을 perl alarm 2s 로 감쌌더니
#   bounded_run 은 2초에 rc 를 냈으나 `j=$(...)` 는 **102초** 걸렸다.
#   `set -m` + `kill -- -$pid`(프로세스 그룹째)로 전 자손을 한 번에 잡는다. `pkill -P` 는
#   직계 자식만 죽여 depth-2 손자에 뚫린다.
#   이 메커니즘의 원본과 실증은 `scripts/_internal/check-ci-status.sh:_run_with_timeout`
#   (FID 20260807-doctor-ci-check, 실측 미적용 30.02s / 적용 1.05s). 여기 재구현한 이유는
#   그쪽이 `gh` 조회 전용 내부 함수라 소스 가능한 계약이 아니기 때문이다 — 두 구현의 드리프트는
#   propagation-matrix `bounded-run-watchdog` 원장이 잠근다.
#
# 왜 rc 를 124 로 정규화하는가:
#   시간초과 rc 는 경로마다 다르다 — SIGTERM=143 · SIGALRM=142 · SIGKILL=137 · GNU timeout=124.
#   호출부가 네 값을 각자 알아야 하면 한 곳만 빠뜨려도 "시간초과를 정상 실패로 오분류" 가 난다.
#   판정은 여기서 한 번만 한다.
#   한계 고백: 스스로 143/142/137 로 끝나는 명령은 시간초과로 오분류된다. 상한 대상(외부 스캐너·
#   테스트 스위트)에서 그 rc 는 신호사망이라 실질 구분 가치가 없다.

# 시간 상한 실행. 상한이 0·비수치면 무제한(종전 동작 보존 — 의도적 "상한 없음" 선택을 존중한다).
bounded_run() {
  local secs="${1:-0}"; shift
  case "$secs" in ''|*[!0-9]*) secs=0 ;; esac
  if [ "$secs" -le 0 ]; then "$@"; return $?; fi

  local pid rc flag
  # 워치독 생사 신호를 파일로 둔다 — 아래 "왜 신호로 안 죽이는가" 참조.
  flag=$(mktemp "${TMPDIR:-/tmp}/specops-bounded.XXXXXX") || { "$@"; return $?; }

  # 잡 컨트롤을 켜야 백그라운드 작업이 자기 프로세스 그룹의 리더가 된다 → `-$pid` 로 전 자손 kill.
  # 즉시 복원 — 켜진 채로 두면 이후 파이프라인 동작이 달라진다.
  set -m
  "$@" & pid=$!
  set +m

  # ★ 왜 워치독을 신호로 죽이지 않는가 (실측):
  #   `kill "$wpid"` 로 정리하면 비대화형 bash 가 **다음 명령 경계에서** 잡 종료 알림
  #   ("Terminated: 15 ( sleep … )") 을 stderr 에 흘린다. `wait "$wpid" 2>/dev/null` 로는 못 막는다 —
  #   알림 시점이 wait 안이 아니기 때문이다. 그 한 줄이 run-all 출력과 stderr 계약을 오염시킨다.
  #   그래서 부모는 flag 파일만 지우고, 워치독은 그걸 보고 **스스로 정상 종료**한다
  #   (정상 종료 잡은 비대화형에서 아무것도 출력하지 않는다). 부모는 워치독을 wait 하지 않으므로
  #   대기 비용도 0 이다 — 최대 1초 남아 있다 사라진다.
  # 그룹 kill 우선, 그래도 남으면 본체 직접 kill (그룹 생성 실패 환경 대비 이중화)
  (
    n=0
    while [ "$n" -lt "$secs" ]; do
      [ -e "$flag" ] || exit 0
      sleep 1
      n=$((n + 1))
    done
    [ -e "$flag" ] || exit 0
    kill -TERM -- "-$pid" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null
  ) >/dev/null 2>&1 &

  wait "$pid" 2>/dev/null; rc=$?
  rm -f "$flag"

  case "$rc" in 143|142|137) rc=124 ;; esac
  return "$rc"
}

bounded_timed_out() { [ "${1:-0}" -eq 124 ]; }
