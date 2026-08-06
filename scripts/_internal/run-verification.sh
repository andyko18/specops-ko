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
START_SECONDS=$(date +%s)

if [ ! -f "$TASKS" ]; then
  echo "tasks.md not found: $TASKS" >&2
  exit 1
fi

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
EXTRACT="$PLUGIN/scripts/_internal/extract-test-commands.sh"
AUDIT_SH="$PLUGIN/scripts/_internal/check-review-audit.sh"
FND_SH="$PLUGIN/scripts/_internal/check-foundation-manifest.sh"
STATE_SH="$PLUGIN/scripts/_internal/verification-state.sh"
METRIC_SH="$PLUGIN/scripts/_internal/record-metric.sh"

all_pass=1
executed=0
skipped=0
failed=0

# 단일 판정 기록: evidence 호환 stamp + 구조화 상태 SoT + 비용/수율 계측.
# 구조화 기록 실패가 테스트 결과를 뒤집지는 않지만 stderr로 표면화한다.
_record_result() { # <verdict>
  local verdict="$1" now duration_ms
  now=$(date +%s)
  duration_ms=$(( (now - START_SECONDS) * 1000 ))
  mkdir -p "$(dirname "$EVIDENCE")"
  echo "RUN-VERIFICATION-RESULT: $verdict" >> "$EVIDENCE"
  if ! bash "$STATE_SH" record "$FID" "$verdict" \
      --executed "$executed" --skipped "$skipped" --failed "$failed" \
      --duration-ms "$duration_ms" 2>/dev/null; then
    echo "WARN: verification-state 기록 실패 (FID=$FID)" >&2
  fi
  if ! bash "$METRIC_SH" --fid "$FID" --phase verify --wall-ms "$duration_ms" \
      --verdict "$verdict" 2>/dev/null; then
    echo "WARN: verify metric 기록 실패 (FID=$FID)" >&2
  fi
}

commands=$(bash "$EXTRACT" "$TASKS")
if [ -z "$commands" ]; then
  # 명령 0건이어도 리뷰 감사 추적은 검사한다 — 여기서 무조건 exit 0 하면 "테스트 명령을
  #   안 쓰는 FID" 가 review-audit 을 통째로 비껴가는 구멍이 된다.
  if [ -f "$AUDIT_SH" ]; then
    audit_out=$(bash "$AUDIT_SH" "$FID" 2>&1) || {
      failed=$((failed + 1))
      _record_result FAIL
      echo "VERIFY: FAIL review-audit" >&2
      echo "$audit_out" >&2
      exit 1
    }
  fi
  # foundation manifest 도 동일 이유로 여기서 검사한다 — review-audit 이 봉합한 것과 같은
  #   "NO COMMANDS 우회" 구멍. 테스트 명령 0건인 foundation FID 가 게이트를 통째로 비껴간다.
  if [ -f "$FND_SH" ]; then
    fnd_out=$(bash "$FND_SH" "$FID" 2>&1) || {
      failed=$((failed + 1))
      _record_result FAIL
      echo "VERIFY: FAIL foundation-manifest 미산출" >&2
      echo "$fnd_out" >&2
      exit 1
    }
  fi
  _record_result NOT_RUN
  echo "VERIFY: NOT_RUN — 테스트 명령 0건" >&2
  exit 1
fi

mkdir -p "$(dirname "$EVIDENCE")"
{
  echo ""
  echo "## run-verification.sh ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo ""
} >> "$EVIDENCE"

# 러너별 선두 앵커 — 각 패턴이 ^ 로 고정되어 임의 명령 실행 차단 (AC-2).
# bash: 기존 동작 보존(scripts/*.sh 한정). 그 외 러너는 표준 호출형만 허용.
#
# 한계 고백 (5원칙 5) — 아래는 의도된 미지원이지 버그가 아니다:
#   1. `go test ./...` 는 실행되지 않는다. 아래 `*..*` path-traversal 가드가 `./...` 를 먼저 잡아 SKIP.
#      go 의 사실상 표준 호출형이지만 미지원 — 개별 패키지 경로(`go test ./pkg/foo`)를 쓸 것.
#   2. `npm run test:unit` 처럼 `:` 를 포함한 스크립트명도 인자 char-class 밖이라 SKIP.
#   3. 성격: 보안 경계가 아니라 anti-footgun 이다. 화이트리스트를 통과하면서 아무것도 검증하지 않는
#      exit-0 스푸핑(`pytest --collect-only` 류)은 차단하지 못한다 (spec §2 · F-3 클래스).
#   4. npx·(pnpm|yarn) exec 는 **임의 bin** 을 허용한다 — `npx cowsay` 류 비테스트 명령도 exit 0 이면
#      통과한다(exit-0 스푸핑 = 위 #3 `pytest --collect-only` 동류의 수용 한계, 위협모델=환각이지 침입 아님).
#      러너명 고정리스트(vitest·jest·ava·uvu·bun test…)로 제한하지 않는 이유: 러너명이 예측 불가라
#      고정하면 정직한 외부 테스트가 false-block 되는 재발(본 FID 의 존재 이유)을 부른다. bin 선두 char 를
#      [A-Za-z0-9_@] 로 조인 것(FIX-A)은 절대경로·옵션주입(파괴형)만 축소할 뿐 임의 bin 자체는 여전히 허용.
# bash 접두: (scripts|tests|test)/ — downstream 표준 테스트 배치 인정 (20260716 trivial dogfood
#   발견 #3: scripts/ 하드코딩 편향으로 외부 `bash tests/test-x.sh` 가 PARTIAL → 실행-근거 게이트
#   불인정 → 정직한 외부 완주가 커밋 deny. anti-footgun 성격(L50)이라 상대경로 테스트 디렉토리
#   확장은 안전 — 절대경로·lib/ 등은 여전히 차단 (T2.h 잠금).
# subdir/러너형: 선택적 `cd <상대subdir> && ` 접두 + `npx <bin>`·`pnpm|yarn exec <bin>` 러너형 인정
#   (false-block 9호 — monorepo `cd apps/web && npx vitest run`). subdir 첫 문자 '/' 불허(절대경로 차단)
#   + `*..*` 가드로 트래버설 차단. bare `pnpm|yarn <bin>`(예 `pnpm vitest`)는 미지원 (clarify Q1=(2)).
_WHITELIST_PAT='^(cd[[:blank:]]+[A-Za-z0-9_.][A-Za-z0-9_/.-]*[[:blank:]]+&&[[:blank:]]+)?(bash[[:blank:]]+(scripts|tests?)/[A-Za-z0-9_/.-]+\.sh([[:blank:]][A-Za-z0-9_/.=-]*)*|(python[[:blank:]]+-m[[:blank:]]+)?pytest([[:blank:]][A-Za-z0-9_/.=-]*)*|(npm|pnpm|yarn)[[:blank:]]+(run[[:blank:]]+)?test([[:blank:]][A-Za-z0-9_/.=-]*)*|go[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*|cargo[[:blank:]]+test([[:blank:]][A-Za-z0-9_/.=-]*)*|npx[[:blank:]]+[A-Za-z0-9_@][A-Za-z0-9_@/.-]*([[:blank:]][A-Za-z0-9_@/.=-]*)*|(pnpm|yarn)[[:blank:]]+exec[[:blank:]]+[A-Za-z0-9_@][A-Za-z0-9_@/.-]*([[:blank:]][A-Za-z0-9_@/.=-]*)*)$'

while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  if [[ ! "$cmd" =~ $_WHITELIST_PAT ]] || [[ "$cmd" == *..* ]]; then
    echo "WARN: SKIP '$cmd' — whitelist 미통과. 허용: bash (scripts|tests)/*.sh · pytest · npm/pnpm/yarn (run) test · go test · cargo test · npx <bin> · pnpm|yarn exec <bin>, 선택적 'cd <상대subdir> && ' 접두. 힌트: bare 'pnpm|yarn <러너>'(예 pnpm vitest)는 미지원 → 'pnpm exec <러너>' 를 쓸 것. '..' 포함 경로·절대경로는 차단(예 'go test ./...' 미지원 — 개별 패키지 경로를 쓸 것)" >&2
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
  # cd <subdir> && <rest> → 서브셸 직접-exec (no-shell 유지 · 부모 cwd 비오염 · false-block 9호)
  #   서브셸 `$(…)` 의 exit 가 곧 마지막 명령(runner) 종료코드. subdir 부재면 cd 실패 → 비0 → FAIL 정직포착.
  # bash 러너는 기존대로 bash 로 실행(scripts/*.sh 한정). 그 외 러너는 첫 토큰을 그대로 실행(PATH 조회).
  if [[ "$cmd" =~ ^cd[[:blank:]]+([^[:blank:]]+)[[:blank:]]+\&\&[[:blank:]]+(.*)$ ]]; then
    _sub_dir="${BASH_REMATCH[1]}"; read -r -a _sub_parts <<< "${BASH_REMATCH[2]}"
    # 그룹 `{ … }` 전체 stderr 캡처 — `2>&1` 를 러너에만 결속하면 cd 실패 진단이
    #   스크립트 stderr 로 유출되어 evidence 출력블록이 빈 채 exit 만 기록됨(L12 투명성 위반, Imp1).
    out=$( { cd "$_sub_dir" && "${_sub_parts[@]}"; } 2>&1 )
  elif [ "${_parts[0]}" = "bash" ]; then
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
    failed=$((failed + 1))
    echo "VERIFY: FAIL $cmd (exit=$ec)" >&2
  fi
done <<< "$commands"

# 리뷰 감사 추적 대조 — Phase B/C 판정 리포트가 dispatch-log 에 기록됐는지 (F1 teeth).
#   테스트 명령 결과와 별개 축이지만 여기에 배선한 이유: 실행-근거 게이트(R-1/R-2)가
#   "VERIFY: PASS" 만 커밋 면제로 인정하므로, 이 축의 위반도 같은 관문을 통과해야 실효가 있다.
#   누락 전용 검사이며 산출물 부재는 fail-open(SKIP) 이라 무관 repo·초기 FID 에 월권하지 않는다.
if [ -f "$AUDIT_SH" ]; then
  audit_out=$(bash "$AUDIT_SH" "$FID" 2>&1)
  audit_ec=$?
  {
    echo "### review-audit"
    echo '```'
    echo "$audit_out"
    echo '```'
    echo ""
  } >> "$EVIDENCE"
  if [ "$audit_ec" -ne 0 ]; then
    all_pass=0
    failed=$((failed + 1))
    echo "VERIFY: FAIL review-audit (exit=$audit_ec)" >&2
    echo "$audit_out" >&2
  fi
fi

# foundation manifest 산출 게이트 — §유형=foundation 인 FID 만 대상(그 외 SKIP).
#   review-audit 과 같은 이유로 여기 배선한다: 실행-근거 게이트(R-1/R-2)가 "VERIFY: PASS" 만
#   커밋·PR 면제로 인정하므로, 이 축의 위반도 같은 관문을 통과해야 실효가 있다.
#   종전엔 verifying-evidence-ko 산문뿐이라 모델이 건너뛰면 무발동이었다(20260806 실측).
if [ -f "$FND_SH" ]; then
  fnd_out=$(bash "$FND_SH" "$FID" 2>&1)
  fnd_ec=$?
  {
    echo "### foundation-manifest"
    echo '```'
    echo "$fnd_out"
    echo '```'
    echo ""
  } >> "$EVIDENCE"
  if [ "$fnd_ec" -ne 0 ]; then
    all_pass=0
    failed=$((failed + 1))
    echo "VERIFY: FAIL foundation-manifest 미산출 (exit=$fnd_ec)" >&2
    echo "$fnd_out" >&2
  fi
fi

if [ "$skipped" -gt 0 ]; then
  _record_result PARTIAL
  echo "VERIFY: PARTIAL — ${skipped}개 명령 whitelist 미통과, 수동 검증 필요 (executed=${executed} skipped=${skipped})"
  exit 1
fi
if [ "$executed" -eq 0 ]; then
  _record_result NOT_RUN
  echo "VERIFY: NOT_RUN — 실행된 명령 0건" >&2
  exit 1
fi
if [ "$all_pass" = "1" ]; then
  _record_result PASS
  echo "VERIFY: PASS"
  exit 0
fi
_record_result FAIL
exit 1
