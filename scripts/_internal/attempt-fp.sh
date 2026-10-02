#!/usr/bin/env bash
# attempt-fp.sh — verify 동일 실패 지문(attempt fingerprint) 기록·판정 (FID 20261002-attempt-fingerprint)
#
# 사용:
#   attempt-fp.sh record <FID> <PASS|FAIL> [--material <파일>]
#   attempt-fp.sh check  <FID>
#
# 파일: .specops/<FID>/attempts.jsonl (cwd 기준 — run-verification.sh 와 같은 해석), append-only·회전 없음.
#   줄 형식: {"ts":"<ISO8601 UTC>","verdict":"FAIL|PASS","fp":"<hex16>|-","n":<int>}
#   n = 직전 줄이 FAIL 이고 fp 가 같으면 직전 n+1, 아니면 1. PASS 줄은 fp "-"·n 0 (연속을 끊는다).
#   fp 가 "-" 인 FAIL(재료 없음·판독 불가·해시 불가)은 같은 실패로 세지 않는다 — 항상 n=1.
#
# rc 계약:
#   record  0 = 기록함 또는 기록 불가(stderr WARN — fail-open) · 2 = 인자 오류(사용법 안내)
#   check   0 = 계속(`ATTEMPT: OK (…)`) — 파일 부재·마지막 줄 판독 불가도 0(`기존 cap 경로`)
#           1 = 정지(`ATTEMPT-STOP: …`) — 마지막 줄이 FAIL 이고 n >= ATTEMPT_FP_MAX
#           2 = 인자 오류
#
# 왜 필요한가:
#   verify→fix 루프(verifying-evidence-ko)·Phase B/C 재dispatch·§auto 전역 재시도는 **횟수 cap** 만
#   갖는다. 같은 실패를 같은 방식으로 반복해도 횟수만 소모하고 계속 진행하며, 카운터 4종은 전부
#   모델이 손으로 갱신해 틀리게 쓰거나 안 쓰면 cap 자체가 작동하지 않는다. 이 스크립트는 (1) 실패
#   재료를 정규화·해시해 "같은 실패" 를 기계적으로 판정하고, (2) 기록은 run-verification.sh 가 하며
#   모델은 쓰지 않는다(queue-set-status.sh 선례). 지문이 달라졌다고 cap 카운터를 되돌려 주지 않는다.
#
# 지문 재료(--material): run-verification.sh 가 실패한 테스트 명령마다 `CMD: <cmd>`·`EXIT: <n>`·출력을,
#   사전 검사(review-audit·ac-format·…) 실패는 `REASON: <tag>` 줄을 쓴다. 정규화 규칙은 AFP_AWK 참조.
#   해시만 attempts.jsonl 에 남긴다 — 실패 출력 원문(비밀 포함 가능)은 저장하지 않는다.
#
# 한계(정직): 정지 판정(check)을 부르는 쪽은 verifying-ko 산문(모델)이라 훅 수준 강제가 아니다.
#   이 기록은 R-1/R-2 verify 면제 판정이 읽지 않는다 — 면제를 넓히지 않는다.
#   실패 줄에 키워드가 없는 출력(한글 전용 메시지·set -e 중단·go 상세 줄·긴 메시지만 다른 같은-테스트 실패)은
#   CMD·EXIT·테스트 id 단위로 접힌다 — 정지 시 재료 부족일 수 있다. 8자 이상 hex/10진 id(test_deadbeef01 vs
#   test_cafebabe02)도 접힌다. 반대로 줄 머리 `●`(jest 외 도구의 글머리표)는 실패 줄로 취해질 수 있다 — 지문이 달라지는 미탐 방향이다.
set -u

# 상수 — env 로 바꿀 수 없다(무조건 대입). 값을 바꾸는 것은 코드 변경이다.
ATTEMPT_FP_MAX=2

afp::usage() {
  {
    echo "usage: attempt-fp.sh record <FID> <PASS|FAIL> [--material <파일>]"
    echo "       attempt-fp.sh check <FID>"
  } >&2
}

afp::fid_ok() { # <FID> — 경로 탈출 차단
  [[ "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] && [[ "$1" != *..* ]]
}

# 정규화 awk (gawk·mawk·BSD awk 공용 — interval expression·gensub·IGNORECASE 금지).
#   1) CMD:/EXIT:/REASON: 구조 줄은 항상 취한다(키워드가 없어도 — 조용한 exit 1 이 빈 지문이 되지 않게).
#   2) 요약 카운트 줄(PASS=N FAIL=M · N failed, M passed · Results: · ==== … ==== · TAP `# fail N`)은 제외.
#   3) 강한 실패 시작(FAIL·ERROR·not ok·✗·✕·Traceback·panic·--- FAIL · jest 기본 리포터 `●` 헤더 — `● Console` 제외)은 취한다.
#   4) 통과 줄(PASS … · ok … · ✓ · … PASSED · go 의 --- PASS/=== RUN · run-all 의 `--- <스위트>.sh` 헤더 · TAP `# Subtest:` 헤더)은 제외.
#   5) 나머지는 키워드(FAIL|ERROR|not ok|✗|✕|Traceback|panic, 대소문자 무시) 포함 줄만 취한다.
#   취한 줄에서 ANSI·ISO 시각·소요시간·tmp 경로·16진·PID 를 치환하고 공백을 접는다. 테스트 id 는 보존.
read -r -d '' AFP_AWK <<'AWKEOF' || true
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# 앞뒤 경계 문자를 보존하며 re 에 맞는 토큰을 rep 으로 치환한다(re 는 경계 1자 + 본문 + 경계 1자).
function repl_tok(s, re, rep,    out, lead) {
  s = " " s " "
  out = ""
  while (match(s, re)) {
    lead = substr(s, RSTART, 1)
    out = out substr(s, 1, RSTART - 1) lead rep
    s = substr(s, RSTART + RLENGTH - 1)
  }
  s = out s
  return substr(s, 2, length(s) - 2)
}

# 앞 경계 1자만 요구하는 치환(경로용).
function repl_lead(s, re, rep,    out, lead) {
  s = " " s
  out = ""
  while (match(s, re)) {
    lead = substr(s, RSTART, 1)
    out = out substr(s, 1, RSTART - 1) lead rep
    s = substr(s, RSTART + RLENGTH)
  }
  s = out s
  return substr(s, 2)
}

function count_re(s, re,    n) {
  n = 0
  while (match(s, re)) { n++; s = substr(s, RSTART + RLENGTH) }
  return n
}

function is_summary(low) {
  if (low ~ /^=+.*=+$/) return 1
  if (low ~ /^results?:/) return 1
  if (low ~ /^(tests?|test suites?|test files?|snapshots?|suites?|summary|total|ran)[ ]*:/) return 1
  if (low ~ /(pass|passed|ok|success)=[0-9]/ && low ~ /(fail|failed|failures?|errors?)=[0-9]/) return 1
  if (low ~ /\((failures|errors)=[0-9]/) return 1
  if (low ~ /^# (tests|suites|pass|fail|cancelled|skipped|todo|duration_ms) /) return 1
  if (low ~ /^[0-9]+ (failed|errors?|failures?)( |,|$)/) return 1
  if (count_re(low, "[0-9]+ (passed|failed|skipped|errors?|failures?|warnings?|total|xfailed|xpassed|deselected)") >= 2) return 1
  return 0
}

function strong_fail(low, t) {
  if (low ~ /^(fail|error|not ok|panic|--- fail|traceback)/) return 1
  if (index(t, "✗") == 1 || index(t, "✕") == 1) return 1
  # jest 기본 리포터의 실패 테스트 헤더(`● suite › name`). `● Console` 은 통과 테스트에도 나오는 console 머리줄이다.
  if (index(t, "●") == 1 && t != "● Console") return 1
  return 0
}

function is_pass(low, t) {
  if (low ~ /^(pass|passed|ok)([^a-z0-9]|$)/) return 1
  if (low ~ /^--- (pass|skip)/ || low ~ /^=== (run|pause|cont|name)/) return 1
  if (low ~ /^--- [^ ]+\.sh$/) return 1
  if (low ~ /^# subtest:/) return 1
  if (index(t, "✓") == 1 || index(t, "✔") == 1) return 1
  if (low ~ / passed( |\[|$)/) return 1
  return 0
}

function has_kw(low, t) {
  if (index(low, "fail") || index(low, "error") || index(low, "not ok") || index(low, "traceback") || index(low, "panic")) return 1
  if (index(t, "✗") || index(t, "✕")) return 1
  return 0
}

function norm(s,    hex8) {
  # ISO 시각·날짜·시각(요일 월 일 형 포함)
  gsub(/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][T ][0-9][0-9]:[0-9][0-9]:[0-9][0-9][.,0-9]*(Z|[+-][0-9][0-9]:?[0-9][0-9])?/, "<TS>", s)
  gsub(/(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[ ,]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[ ]+[0-9]+/, "<TS>", s)
  gsub(/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/, "<TS>", s)
  gsub(/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]([.,][0-9]+)?/, "<TS>", s)
  # 16진 주소(0x…)
  gsub(/0[xX][0-9a-fA-F]+/, "<HEX>", s)
  # tmp 계열 경로 — mktemp 디렉터리 컴포넌트까지만 치환(뒤의 상대 경로·테스트 id 는 보존)
  s = repl_lead(s, "[^A-Za-z0-9._/-]/(private/)?var/folders/[^/ \t]+/[^/ \t]+/[A-Za-z0-9]/[^/ \t]*", "<TMP>")
  s = repl_lead(s, "[^A-Za-z0-9._/-]/(private/)?(var/)?tmp/[^/ \t)]*", "<TMP>")
  # mktemp 랜덤 접미(tmp.AbCd12·tmp-XXXX 류)
  gsub(/tmp[._-][A-Za-z0-9]+/, "tmp.<R>", s)
  # 소요시간 — 선행 문자가 영숫자면(T15s 같은 id) 건드리지 않는다
  s = repl_tok(s, "[^A-Za-z0-9]([0-9]+(\\.[0-9]+)?[hm])*[0-9]+(\\.[0-9]+)?[ ]?(ms|ns|us|s|sec|secs|seconds)[^A-Za-z0-9]", "<DUR>")
  # PID
  gsub(/[Pp][Ii][Dd][ =:]*[0-9]+/, "pid <N>", s)
  # 16진 8자 이상(순수 10진 8자 이상 포함) — interval expression 대신 8개 클래스 + *
  hex8 = "[^A-Za-z0-9][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*[^A-Za-z0-9]"
  s = repl_tok(s, hex8, "<HEX>")
  gsub(/[ \t]+/, " ", s)
  return trim(s)
}

BEGIN { ESC = sprintf("%c", 27) }
{
  line = $0
  sub(/\r$/, "", line)
  gsub(ESC "\\[[0-9;]*[A-Za-z]", "", line)
  t = trim(line)
  if (t == "") next
  if (t ~ /^(CMD|EXIT|REASON): /) { print norm(t); next }
  low = tolower(t)
  if (is_summary(low)) next
  if (strong_fail(low, t)) { print norm(t); next }
  if (is_pass(low, t)) next
  if (has_kw(low, t)) print norm(t)
}
AWKEOF

# afp::normalize <file> — 정규화된 실패 줄 집합(정렬·중복 제거). 판독 불가면 rc≠0.
afp::normalize() {
  [ -f "$1" ] && [ -r "$1" ] || return 1
  LC_ALL=C awk "$AFP_AWK" "$1" | LC_ALL=C sort -u
}

# afp::hash — stdin → 16 hex. shasum -a 256 → sha256sum → cksum 순(앞 도구가 실패하면 다음으로).
afp::hash() {
  local data h
  data=$(cat)
  h=$(printf '%s\n' "$data" | shasum -a 256 2>/dev/null | cut -c1-16)
  if [[ ! "$h" =~ ^[0-9a-f]{16}$ ]]; then
    h=$(printf '%s\n' "$data" | sha256sum 2>/dev/null | cut -c1-16)
  fi
  if [[ ! "$h" =~ ^[0-9a-f]{16}$ ]]; then
    set -- $(printf '%s\n' "$data" | cksum 2>/dev/null)
    case "${1:-}${2:-}" in
      ''|*[!0-9]*) h="" ;;
      *) h=$(printf '%08x%08x' "$1" "$2") ;;
    esac
  fi
  [[ "$h" =~ ^[0-9a-f]{16}$ ]] || return 1
  printf '%s\n' "$h"
}

# afp::fingerprint <재료파일|빈문자열> — stdout 에 hex16 또는 "-". 항상 rc0(fail-open).
afp::fingerprint() {
  local material="$1" set h
  if [ -z "$material" ]; then printf '%s\n' "-"; return 0; fi
  if ! set=$(afp::normalize "$material"); then
    echo "WARN: attempt-fp 재료 판독 불가 ($material) — 지문 없이 기록" >&2
    printf '%s\n' "-"; return 0
  fi
  if [ -z "$set" ]; then printf '%s\n' "-"; return 0; fi
  if ! h=$(printf '%s\n' "$set" | afp::hash); then
    echo "WARN: attempt-fp 해시 도구 없음 — 지문 없이 기록" >&2
    printf '%s\n' "-"; return 0
  fi
  printf '%s\n' "$h"
}

# afp::parse_last <attempts.jsonl> → P_VERDICT P_FP P_N 설정.
#   rc 0 = 판독 성공 · 1 = 파일 부재/빈 파일 · 2 = 마지막 줄 판독 불가. **마지막 줄만 읽는다**(tail -n 1).
afp::parse_last() {
  local f="$1" last re n
  P_VERDICT=""; P_FP=""; P_N=0
  [ -f "$f" ] || return 1
  [ -s "$f" ] || return 1
  last=$(tail -n 1 "$f" 2>/dev/null) || return 2
  re='^\{"ts":"[^"]*","verdict":"(FAIL|PASS)","fp":"([0-9a-f]+|-)","n":([0-9]+)\}$'
  [[ "$last" =~ $re ]] || return 2
  n="${BASH_REMATCH[3]}"
  [ "${#n}" -le 6 ] || return 2
  P_VERDICT="${BASH_REMATCH[1]}"
  P_FP="${BASH_REMATCH[2]}"
  P_N=$((10#$n))
  return 0
}

afp::record() { # <FID> <PASS|FAIL> [--material <파일>]
  local fid="${1:-}" verdict="${2:-}" material="" dir file fp n ts line
  if [ $# -lt 2 ]; then afp::usage; return 2; fi
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --material)
        if [ $# -lt 2 ]; then afp::usage; return 2; fi
        material="$2"; shift 2 ;;
      *) afp::usage; return 2 ;;
    esac
  done
  afp::fid_ok "$fid" || { echo "attempt-fp: FID 형식 오류 ($fid)" >&2; afp::usage; return 2; }
  case "$verdict" in
    PASS|FAIL) ;;
    *) echo "attempt-fp: verdict 는 PASS|FAIL ($verdict)" >&2; afp::usage; return 2 ;;
  esac

  dir=".specops/$fid"; file="$dir/attempts.jsonl"
  if [ "$verdict" = "PASS" ]; then
    fp="-"; n=0
  else
    fp=$(afp::fingerprint "$material")
    n=1
    if [ "$fp" != "-" ] && afp::parse_last "$file" \
       && [ "$P_VERDICT" = "FAIL" ] && [ "$P_FP" = "$fp" ]; then
      n=$((P_N + 1))
    fi
  fi

  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  line=$(printf '{"ts":"%s","verdict":"%s","fp":"%s","n":%s}' "$ts" "$verdict" "$fp" "$n")
  if ! mkdir -p "$dir" 2>/dev/null; then
    echo "WARN: attempt-fp 기록 불가 — $dir 생성 실패 (기존 cap 경로로 진행)" >&2
    return 0
  fi
  # 마지막 줄이 개행 없이 끝났으면(중단된 쓰기) 새 줄이 그 줄에 붙지 않도록 개행을 먼저 둔다.
  if [ -s "$file" ] && [ -f "$file" ] && [ -n "$(tail -c 1 "$file" 2>/dev/null)" ]; then
    printf '\n' 2>/dev/null >> "$file"
  fi
  if ! printf '%s\n' "$line" 2>/dev/null >> "$file"; then
    echo "WARN: attempt-fp 기록 불가 — $file 쓰기 실패 (기존 cap 경로로 진행)" >&2
    return 0
  fi
  printf 'ATTEMPT-RECORD: %s n=%s fp=%s\n' "$verdict" "$n" "$fp"
  return 0
}

afp::check() { # <FID>
  local fid="${1:-}" rc short
  if [ $# -ne 1 ]; then afp::usage; return 2; fi
  afp::fid_ok "$fid" || { echo "attempt-fp: FID 형식 오류 ($fid)" >&2; afp::usage; return 2; }
  afp::parse_last ".specops/$fid/attempts.jsonl"
  rc=$?
  if [ "$rc" -eq 1 ]; then
    echo "ATTEMPT: OK (attempts.jsonl 기록 없음 — 기존 cap 경로)"; return 0
  fi
  if [ "$rc" -ne 0 ]; then
    echo "ATTEMPT: OK (마지막 줄 판독 불가 — 기존 cap 경로)"; return 0
  fi
  short="${P_FP:0:8}"
  if [ "$P_VERDICT" = "FAIL" ] && [ "$P_N" -ge "$ATTEMPT_FP_MAX" ]; then
    echo "ATTEMPT-STOP: 동일 실패 지문 ${P_N}회 연속 (fp=${short}) — 같은 실패가 반복된다. 추가 fix 시도 없이 cap 초과와 같은 경로(§auto: systematic-debugging-ko → 전역 재시도 · 단일: HARD GATE)로 처리하라"
    return 1
  fi
  echo "ATTEMPT: OK (마지막 판정 ${P_VERDICT} n=${P_N}/${ATTEMPT_FP_MAX} fp=${short})"
  return 0
}

afp::main() {
  case "${1:-}" in
    record) shift; afp::record "$@" ;;
    check)  shift; afp::check "$@" ;;
    *) afp::usage; return 2 ;;
  esac
}

# source 되면(스위트가 afp::normalize 등을 직접 단언) 실행하지 않는다.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  afp::main "$@"
  exit $?
fi
