#!/usr/bin/env bash
# 추출된 검증 명령을 순차 실행 + evidence.md append + exit code 집계
# Usage: run-verification.sh <FID>
#
# 동작:
#   1. extract-test-commands.sh <FID 의 tasks.md> 로 명령 목록 추출
#   2. 각 명령 순차 실행 + stdout/stderr 전문을 evidence.md 에 append
#   3. 모두 PASS → stdout "VERIFY: PASS" + exit 0
#   4. 1건 FAIL → stderr "VERIFY: FAIL <cmd> (exit=N)" + exit 1
#
# U3 (wobbly §U3): verifying-evidence-ko 의 수동 명령 실행 → 자동화.
# "요약 금지" 5원칙 1 투명성을 스크립트가 강제 (출력 전문 기록).
set -u

FID="${1:?usage: $0 <FID>}"
TASKS=".specops/$FID/tasks.md"
EVIDENCE=".specops/$FID/evidence.md"

if [ ! -f "$TASKS" ]; then
  echo "tasks.md not found: $TASKS" >&2
  exit 1
fi

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
EXTRACT="$PLUGIN/scripts/_internal/extract-test-commands.sh"

commands=$(bash "$EXTRACT" "$TASKS")
if [ -z "$commands" ]; then
  echo "VERIFY: NO COMMANDS"
  exit 0
fi

mkdir -p "$(dirname "$EVIDENCE")"
{
  echo ""
  echo "## run-verification.sh ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo ""
} >> "$EVIDENCE"

all_pass=1
executed=0
skipped=0
# 러너별 선두 앵커 — 각 패턴이 ^ 로 고정되어 임의 명령 실행 차단 (AC-2).
# bash: 기존 동작 보존(scripts/*.sh 한정). 그 외 러너는 표준 호출형만 허용.
#
# 한계 고백 (5원칙 5) — 아래는 의도된 미지원이지 버그가 아니다:
#   1. `go test ./...` 는 실행되지 않는다. 아래 `*..*` path-traversal 가드가 `./...` 를 먼저 잡아 SKIP.
#      go 의 사실상 표준 호출형이지만 미지원 — 개별 패키지 경로(`go test ./pkg/foo`)를 쓸 것.
#   2. `npm run test:unit` 처럼 `:` 를 포함한 스크립트명도 인자 char-class 밖이라 SKIP.
#   3. 성격: 보안 경계가 아니라 anti-footgun 이다. 화이트리스트를 통과하면서 아무것도 검증하지 않는
#      exit-0 스푸핑(`pytest --collect-only` 류)은 차단하지 못한다 (spec §2 · F-3 클래스).
# bash 접두: (scripts|tests|test)/ — downstream 표준 테스트 배치 인정 (20260716 trivial dogfood
#   발견 #3: scripts/ 하드코딩 편향으로 외부 `bash tests/test-x.sh` 가 PARTIAL → 실행-근거 게이트
#   불인정 → 정직한 외부 완주가 커밋 deny. anti-footgun 성격(L50)이라 상대경로 테스트 디렉토리
#   확장은 안전 — 절대경로·lib/ 등은 여전히 차단 (T2.h 잠금).
_WHITELIST_PAT='^(bash[[:blank:]]+(scripts|tests?)/[A-Za-z0-9_/.-]+\.sh([[:blank:]][A-Za-z0-9_/.=-]*)*|(python[[:blank:]]+-m[[:blank:]]+)?pytest([[:blank:]][A-Za-z0-9_/.=-]*)*|(npm|pnpm|yarn)[[:blank:]]+(run[[:blank:]]+)?test([[:blank:]][A-Za-z0-9_/.=-]*)*|go[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*|cargo[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*)$'

while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  if [[ ! "$cmd" =~ $_WHITELIST_PAT ]] || [[ "$cmd" == *..* ]]; then
    echo "WARN: SKIP '$cmd' — whitelist 미통과 (bash scripts/*.sh · pytest · npm/pnpm/yarn test · go test · cargo test 만 허용). 힌트: '..' 포함 경로는 차단되므로 'go test ./...' 는 미지원 — 개별 패키지 경로를 쓸 것" >&2
    {
      echo "### \`$cmd\`"
      echo '> WARN: SKIP — whitelist 미통과'
      echo ""
    } >> "$EVIDENCE"
    skipped=$((skipped + 1))
    continue
  fi
  {
    echo "### \`$cmd\`"
    echo '```'
  } >> "$EVIDENCE"
  executed=$((executed + 1))
  read -r -a _parts <<< "$cmd"
  # bash 러너는 기존대로 bash 로 실행(scripts/*.sh 한정). 그 외 러너는 첫 토큰을 그대로 실행(PATH 조회).
  if [ "${_parts[0]}" = "bash" ]; then
    out=$(bash "${_parts[@]:1}" 2>&1)
  else
    out=$("${_parts[@]}" 2>&1)
  fi
  # ⚠️ 위 if/fi 블록과 이 줄 사이에 어떤 명령도 삽입 금지 (주석은 무해).
  #    명령을 넣으면 ec 가 그 명령의 status(0)를 캡처해 **실패한 테스트가 VERIFY: PASS 로 샌다**.
  #    실증된 함정(plan I-4) — test-verifying-automation.sh 의 T-multi.e/f 가 이 회귀를 고정한다.
  ec=$?
  {
    echo "$out"
    echo '```'
    echo "exit: $ec"
    echo ""
  } >> "$EVIDENCE"
  if [ "$ec" -ne 0 ]; then
    all_pass=0
    echo "VERIFY: FAIL $cmd (exit=$ec)" >&2
  fi
done <<< "$commands"

if [ "$skipped" -gt 0 ]; then
  echo "RUN-VERIFICATION-RESULT: PARTIAL" >> "$EVIDENCE"
  echo "VERIFY: PARTIAL — ${skipped}개 명령 whitelist 미통과, 수동 검증 필요 (executed=${executed} skipped=${skipped})"
  exit 1
fi
if [ "$executed" -eq 0 ]; then
  echo "VERIFY: WARN — 실행된 명령 0건" >&2
  exit 0
fi
if [ "$all_pass" = "1" ]; then
  echo "RUN-VERIFICATION-RESULT: PASS" >> "$EVIDENCE"
  echo "VERIFY: PASS"
  exit 0
fi
echo "RUN-VERIFICATION-RESULT: FAIL" >> "$EVIDENCE"
exit 1
