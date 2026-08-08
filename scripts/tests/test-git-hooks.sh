#!/usr/bin/env bash
# 2단 git hook 게이트 — pre-commit(빠른 정합 ~5s) / pre-push(run-all 전체 195s)
# 계기: 44cd095 revert 가 run-all 없이 나가 main 이 하루 red.
#       Claude Code PreToolUse 훅은 Cursor 등 다른 도구의 커밋에 발화하지 않는다 —
#       git hook 은 도구 무관하게 걸리는 유일한 층이다.
set -uo pipefail
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

PRE_COMMIT="$PLUGIN/.githooks/pre-commit"
PRE_PUSH="$PLUGIN/.githooks/pre-push"
INSTALLER="$PLUGIN/scripts/_internal/install-git-hooks.sh"

# GH-1: 훅 파일 존재 + 실행권한
[ -f "$PRE_COMMIT" ] && [ -x "$PRE_COMMIT" ] \
  && ok "GH-1 .githooks/pre-commit 존재+실행권한" \
  || nope "GH-1" "부재 또는 비실행"

[ -f "$PRE_PUSH" ] && [ -x "$PRE_PUSH" ] \
  && ok "GH-2 .githooks/pre-push 존재+실행권한" \
  || nope "GH-2" "부재 또는 비실행"

# GH-3: pre-commit 은 빠른 게이트 2종 — 정적 구성 + **실측 소요**로 확인한다.
#       (문구 grep 은 안내문 안의 run-all 언급과 실제 호출을 구분하지 못한다.
#        195s 스위트를 돌지 '않음'은 시간으로 증명하는 게 맞다.)
if [ -x "$PRE_COMMIT" ]; then
  grep -q 'validate-structure.sh' "$PRE_COMMIT" && grep -q 'check-propagation.sh' "$PRE_COMMIT" \
    && gate_ok=1 || gate_ok=0
  _s=$(date +%s)
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1) || true
  _e=$(date +%s)
  _d=$((_e - _s))
  [ "$gate_ok" -eq 1 ] && [ "$_d" -lt 60 ] \
    && ok "GH-3 pre-commit = 빠른 게이트 2종 (${_d}s < 60s — run-all 미실행)" \
    || nope "GH-3" "gate_ok=$gate_ok 소요=${_d}s"
else
  nope "GH-3" "pre-commit 부재"
fi

# GH-4: pre-push 는 전체 스위트 + 재귀 가드
if [ -f "$PRE_PUSH" ]; then
  grep -q 'run-all.sh' "$PRE_PUSH" \
    && grep -q 'SPECOPS_RUN_ALL' "$PRE_PUSH" \
    && ok "GH-4 pre-push = run-all + 재귀 가드" \
    || nope "GH-4" "run-all 또는 SPECOPS_RUN_ALL 가드 부재"
else
  nope "GH-4" "pre-push 부재"
fi

# GH-5: 주권 탈출구 안내 — 차단 문구에 --no-verify 명시 (5원칙 4)
if [ -f "$PRE_COMMIT" ] && [ -f "$PRE_PUSH" ]; then
  grep -q -- '--no-verify' "$PRE_COMMIT" && grep -q -- '--no-verify' "$PRE_PUSH" \
    && ok "GH-5 두 훅 모두 --no-verify 주권 안내" \
    || nope "GH-5" "탈출구 안내 부재"
else
  nope "GH-5" "훅 부재"
fi

# GH-6: 비-specops repo 면제 — 게이트 스크립트 없는 트리에서 exit 0 (월권 금지, 5원칙 4)
if [ -x "$PRE_COMMIT" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q && printf 'x\n' > a.txt && git add a.txt)
  (cd "$TD" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "GH-6 비-specops repo 면제 (exit 0)" || nope "GH-6" "rc=$rc"
  rm -rf "$TD"
else
  nope "GH-6" "pre-commit 부재"
fi

# GH-7: 현재 트리 정상 → pre-commit exit 0
if [ -x "$PRE_COMMIT" ]; then
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  [ "$rc" -eq 0 ] && ok "GH-7 정상 트리 → exit 0" || nope "GH-7" "rc=$rc"
else
  nope "GH-7" "pre-commit 부재"
fi

# GH-8: 실제 드리프트 차단 실증 — 44cd095(파손 리비전)의 start-all.md 복원 시 exit 1
#       (이 커밋이 run-all 없이 나가 T1.e 를 하루 red 로 남긴 그 변경이다)
if [ -x "$PRE_COMMIT" ] && (cd "$PLUGIN" && git cat-file -e 44cd095:commands/start-all.md 2>/dev/null); then
  BAK=$(mktemp)
  cp "$PLUGIN/commands/start-all.md" "$BAK"
  # shellcheck disable=SC2064
  trap "cp '$BAK' '$PLUGIN/commands/start-all.md'; rm -f '$BAK'" EXIT
  (cd "$PLUGIN" && git show 44cd095:commands/start-all.md > commands/start-all.md)
  (cd "$PLUGIN" && bash "$PRE_COMMIT" >/dev/null 2>&1); rc=$?
  cp "$BAK" "$PLUGIN/commands/start-all.md"; rm -f "$BAK"
  trap - EXIT
  [ "$rc" -ne 0 ] && ok "GH-8 44cd095 파손 리비전 → pre-commit 차단" || nope "GH-8" "rc=$rc (차단 실패)"
else
  ok "GH-8 SKIP (44cd095 미도달 — shallow clone)"
fi

# GH-9: 설치 스크립트가 core.hooksPath 를 .githooks 로 설정
if [ -f "$INSTALLER" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q && mkdir -p .githooks)
  (cd "$TD" && bash "$INSTALLER" >/dev/null 2>&1)
  hp=$(cd "$TD" && git config core.hooksPath || true)
  [ "$hp" = ".githooks" ] && ok "GH-9 installer → core.hooksPath=.githooks" \
    || nope "GH-9" "hooksPath=$hp"
  rm -rf "$TD"
else
  nope "GH-9" "install-git-hooks.sh 부재"
fi

# GH-9b: 관할 한정 — .githooks/ 없는 repo 는 설치 거부 (없는 경로를 가리키게 두지 않는다)
if [ -f "$INSTALLER" ]; then
  TD=$(mktemp -d)
  (cd "$TD" && git init -q)
  (cd "$TD" && bash "$INSTALLER" >/dev/null 2>&1); rc=$?
  hp=$(cd "$TD" && git config core.hooksPath || true)
  [ "$rc" -ne 0 ] && [ -z "$hp" ] \
    && ok "GH-9b .githooks 부재 repo → 설치 거부" \
    || nope "GH-9b" "rc=$rc hooksPath=$hp"
  rm -rf "$TD"
else
  nope "GH-9b" "install-git-hooks.sh 부재"
fi

# GH-10: 설치 안내가 문서화됐는가 (clone 마다 1회 필요 — core.hooksPath 는 버전관리 대상이 아님)
grep -q 'install-git-hooks' "$PLUGIN/CLAUDE.md" && grep -q 'install-git-hooks' "$PLUGIN/scripts/README.md" \
  && ok "GH-10 CLAUDE.md·scripts/README 설치 안내" \
  || nope "GH-10" "설치 안내 문서 부재"

# ─────────────────────────────────────────────────────────────
# GH-ci.*: pre-push CI 상태 경고 (FID 20260807-doctor-ci-check)
#
# ⚠️ 하드 규칙: 아래 어서션은 어떤 경로로도 run-all.sh 에 도달하면 안 된다.
#    (증상이 "스위트가 195s 가 됨" 하나뿐이라 리뷰에서 안 보인다)
#    실행되는 pre-push 경로는 면제 4종뿐이고, 배선 검사는 소스 grep 이다.
# ─────────────────────────────────────────────────────────────
CI_SH="$PLUGIN/scripts/_internal/check-ci-status.sh"
CI_RCS=""   # GH-ci.6 이 집계할 전 경로 종료코드

# gh stub 디렉터리 생성 — $1=stub 본문 → stdout=디렉터리 경로
_ci_stub() {
  local d; d=$(mktemp -d)
  printf '%s\n' "$1" > "$d/gh"
  chmod +x "$d/gh"
  printf '%s' "$d"
}

# GH-ci.3: gh 부재 → 무출력 exit 0 (AC-3)
#   PATH 를 통째로 교체하므로 bash·jq·git 심링크가 필수다 — 없으면 `bash: command not found`
#   (rc=127)가 나서 구현과 무관하게 영구 FAIL 이 된다.
if [ -f "$CI_SH" ]; then
  D=$(mktemp -d)
  ln -s "$(command -v bash)" "$D/bash" 2>/dev/null
  ln -s "$(command -v jq)" "$D/jq" 2>/dev/null
  ln -s "$(command -v git)" "$D/git" 2>/dev/null
  out=$(cd "$PLUGIN" && PATH="$D" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] \
    && ok "GH-ci.3 gh 부재 → 무출력 exit 0" \
    || nope "GH-ci.3" "rc=$rc out=[$out]"
  rm -rf "$D"
else
  nope "GH-ci.3" "check-ci-status.sh 부재"
fi

# GH-ci.4: gh 비-0 종료(미인증·오프라인) → 무출력 exit 0 (AC-4)
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
echo "gh: not authenticated" >&2
exit 1')
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] \
    && ok "GH-ci.4 gh 실패 → 무출력 exit 0" \
    || nope "GH-ci.4" "rc=$rc out=[$out]"
  rm -rf "$D"
else
  nope "GH-ci.4" "check-ci-status.sh 부재"
fi

# GH-ci.4b: origin 부재 repo → gh 를 부르지 않고 무출력 exit 0 (FR-4 "origin 부재")
#   계약서에 전용 AC 가 없는 FR 경로다(specify 단계 공백). FR 이 must 이므로 여기서 잠근다.
if [ -f "$CI_SH" ]; then
  D=$(mktemp -d); SENT0="$D/called"
  printf '#!/usr/bin/env bash\ntouch "%s"\n' "$SENT0" > "$D/gh"; chmod +x "$D/gh"
  TD=$(mktemp -d); (cd "$TD" && git init -q)
  out=$(cd "$TD" && PATH="$D:$PATH" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] && [ ! -f "$SENT0" ] \
    && ok "GH-ci.4b origin 부재 → gh 미호출·무출력 exit 0" \
    || nope "GH-ci.4b" "rc=$rc out=[$out] gh=$([ -f "$SENT0" ] && echo 호출됨 || echo 미호출)"
  rm -rf "$TD" "$D"
else
  nope "GH-ci.4b" "check-ci-status.sh 부재"
fi

# GH-ci.5: 응답 없는 gh + SPECOPS_CI_CHECK_TIMEOUT=1 → 즉시 exit 0 (AC-5)
#   stub 은 exec 없는 평범한 sleep 이다 — 고아 자식이 명령치환 파이프를 무는
#   실제 실패 형태를 재현하기 위함(실측: pkill -P 미적용 시 30.02s).
#   상한은 < 3s — AC-5 는 "약 1초 안에"이고 실측 워치독은 1.05s 다. < 5s 는 계약보다 느슨하다.
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
sleep 30')
  _s=$(date +%s)
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" SPECOPS_CI_CHECK_TIMEOUT=1 bash "$CI_SH" 2>&1); rc=$?
  _e=$(date +%s); _d=$((_e - _s))
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$_d" -lt 3 ] \
    && ok "GH-ci.5 타임아웃 상한 (${_d}s < 3s, 무출력 exit 0)" \
    || nope "GH-ci.5" "rc=$rc 소요=${_d}s out=[$out]"
  rm -rf "$D"
else
  nope "GH-ci.5" "check-ci-status.sh 부재"
fi

# GH-ci.5b: **depth-2 손자**가 파이프를 물어도 타임아웃이 걸린다 (AC-5 — Phase C 적발)
#   `pkill -P "$pid"` 는 직계 자식만 죽인다. gh 가 손자를 띄우면 타임아웃이 통째로
#   무력화되고, hang 지점이 pre-push 의 "run-all 실행 중" 안내 **앞**이라 push 가
#   무출력 동결된다. 프로세스 그룹 kill(`set -m` + `kill -- -$pid`)이 이걸 막는다.
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
bash -c "sleep 30; :"')
  _s=$(date +%s)
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" SPECOPS_CI_CHECK_TIMEOUT=1 bash "$CI_SH" 2>&1); rc=$?
  _e=$(date +%s); _d=$((_e - _s))
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] && [ "$_d" -lt 3 ] \
    && ok "GH-ci.5b depth-2 손자 타임아웃 (${_d}s < 3s)" \
    || nope "GH-ci.5b" "rc=$rc 소요=${_d}s out=[$out]"
  rm -rf "$D"
else
  nope "GH-ci.5b" "check-ci-status.sh 부재"
fi

# GH-ci.1: CI 실패 → 결론·SHA·URL 을 담은 경고 (AC-1)
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
cat <<JSON
[{"conclusion":"failure","headSha":"abc123def4567890fedcba","url":"https://example.test/runs/42"}]
JSON')
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  if [ "$rc" -eq 0 ] \
     && printf '%s' "$out" | grep -q 'failure' \
     && printf '%s' "$out" | grep -q 'abc123def456' \
     && printf '%s' "$out" | grep -q 'https://example.test/runs/42'; then
    ok "GH-ci.1 CI red → 결론·SHA·URL 경고"
  else
    nope "GH-ci.1" "rc=$rc out=[$out]"
  fi
  rm -rf "$D"
else
  nope "GH-ci.1" "check-ci-status.sh 부재"
fi

# GH-ci.2: CI 성공 → stdout·stderr 모두 비어 있음 (AC-2, 잡음 금지)
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
cat <<JSON
[{"conclusion":"success","headSha":"0123456789abcdef","url":"https://example.test/runs/43"}]
JSON')
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  [ "$rc" -eq 0 ] && [ -z "$out" ] \
    && ok "GH-ci.2 CI green → 무출력" \
    || nope "GH-ci.2" "rc=$rc out=[$out]"
  rm -rf "$D"
else
  nope "GH-ci.2" "check-ci-status.sh 부재"
fi

# GH-ci.1b: conclusion 부재 응답에서 **필드 시프트가 없다** (Phase C 적발)
#   탭은 bash IFS whitespace 라 빈 필드가 collapse 된다 — 빈 sentinel 이면 sha 가 결론 칸으로,
#   url 이 커밋 칸으로 밀려 경고문이 오염됐다(실측: `결론: deadbeef00112233`).
#   현재 계약은 "-" sentinel → **파싱 실패로 보고 조용히 skip**(spec §7 안전 방향).
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
cat <<JSON
[{"headSha":"deadbeef00112233","url":"https://example.test/runs/45"}]
JSON')
  out=$(cd "$PLUGIN" && PATH="$D:$PATH" bash "$CI_SH" 2>&1); rc=$?
  CI_RCS="$CI_RCS $rc"
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    ok "GH-ci.1b conclusion 부재 → 필드 시프트 없이 조용히 skip"
  else
    nope "GH-ci.1b" "rc=$rc out=[$out]"
  fi
  rm -rf "$D"
else
  nope "GH-ci.1b" "check-ci-status.sh 부재"
fi

# GH-ci.6: 전 경로 종료코드가 예외 없이 0 (AC-6)
#   위 8개 시나리오(.3 .4 .4b .5 .5b .1 .2 .1b)가 CI_RCS 에 rc 를 적재해 뒀다. 0 아닌 값이 하나라도 있으면 FAIL.
if [ -n "$CI_RCS" ]; then
  _bad=0
  for _rc in $CI_RCS; do [ "$_rc" -eq 0 ] || _bad=1; done
  _n=$(printf '%s' "$CI_RCS" | wc -w | tr -d ' ')
  [ "$_bad" -eq 0 ] && [ "$_n" -ge 6 ] \
    && ok "GH-ci.6 전 경로 exit 0 (${_n}경로)" \
    || nope "GH-ci.6" "rcs=[$CI_RCS] n=$_n"
else
  nope "GH-ci.6" "수집된 rc 없음"
fi

# GH-ci.9: 읽기 전용 — 경고가 실제로 나가는 경로에서도 파일을 쓰지 않는다 (AC-9)
#   origin 이 있는 임시 repo 를 만들어 red 응답을 주입한다(경고 경로 = 가장 많이 도는 코드).
#   한계: cwd 트리만 해시한다 — $TMPDIR·$HOME 쓰기는 미탐(Phase C Suggestion 2).
if [ -f "$CI_SH" ]; then
  D=$(_ci_stub '#!/usr/bin/env bash
cat <<JSON
[{"conclusion":"failure","headSha":"deadbeefcafe0001","url":"https://example.test/runs/44"}]
JSON')
  TD=$(mktemp -d)
  (cd "$TD" && git init -q && git remote add origin https://example.test/x.git && printf 'x\n' > a.txt)
  before=$(cd "$TD" && find . -type f | sort | xargs shasum 2>/dev/null | shasum)
  (cd "$TD" && PATH="$D:$PATH" bash "$CI_SH" >/dev/null 2>&1)
  after=$(cd "$TD" && find . -type f | sort | xargs shasum 2>/dev/null | shasum)
  [ "$before" = "$after" ] \
    && ok "GH-ci.9 읽기 전용 (경고 경로에서 파일 무변경)" \
    || nope "GH-ci.9" "트리 해시 변화"
  rm -rf "$TD" "$D"
else
  nope "GH-ci.9" "check-ci-status.sh 부재"
fi

# GH-ci.7: 배선 위치 — 면제 4종 뒤 · run-all 앞 (AC-7)
if [ -f "$PRE_PUSH" ]; then
  ln_exempt=$(grep -n 'has_update' "$PRE_PUSH" | tail -1 | cut -d: -f1)
  ln_ci=$(grep -n 'check-ci-status.sh' "$PRE_PUSH" | tail -1 | cut -d: -f1)
  ln_run=$(grep -n 'RUN_ALL.*--quiet' "$PRE_PUSH" | head -1 | cut -d: -f1)
  if [ -n "$ln_exempt" ] && [ -n "$ln_ci" ] && [ -n "$ln_run" ] \
     && [ "$ln_ci" -gt "$ln_exempt" ] && [ "$ln_ci" -lt "$ln_run" ]; then
    ok "GH-ci.7 배선 위치 (면제:${ln_exempt} < ci:${ln_ci} < run-all:${ln_run})"
  else
    nope "GH-ci.7" "면제=$ln_exempt ci=$ln_ci run-all=$ln_run"
  fi
else
  nope "GH-ci.7" "pre-push 부재"
fi

# GH-ci.8: 판정 로직 단일 소스 — 훅 본문에 gh 호출·파싱 없음 (AC-8)
if [ -f "$PRE_PUSH" ]; then
  if grep -qE '(^|[^-[:alnum:]_])gh[[:space:]]+run' "$PRE_PUSH" \
     || grep -q 'conclusion' "$PRE_PUSH"; then
    nope "GH-ci.8" "훅 본문에 gh 판정 로직 인라인"
  else
    grep -q 'check-ci-status.sh' "$PRE_PUSH" \
      && ok "GH-ci.8 판정 SoT 위임 (훅에 gh 로직 없음)" \
      || nope "GH-ci.8" "check-ci-status.sh 호출 부재"
  fi
else
  nope "GH-ci.8" "pre-push 부재"
fi

# GH-ci.R1: 면제 4경로에서 gh 미호출 + run-all 미실행 (AC-R-1)
#   sentinel = "gh 안 불렸다" / 경과시간 = "run-all 안 돌았다" (GH-3 관용구)
if [ -x "$PRE_PUSH" ]; then
  D=$(mktemp -d); SENT="$D/called"
  printf '#!/usr/bin/env bash\ntouch "%s"\n' "$SENT" > "$D/gh"; chmod +x "$D/gh"

  TD_nogit=$(mktemp -d)                                    # ① 비-git
  TD_norepo=$(mktemp -d); (cd "$TD_norepo" && git init -q) # ② 비-specops repo
  ZERO='refs/heads/main 0000000000000000000000000000000000000000 refs/heads/main 0000000000000000000000000000000000000000'

  _s=$(date +%s)
  (cd "$TD_nogit"  && PATH="$D:$PATH" bash "$PRE_PUSH" </dev/null >/dev/null 2>&1); r1=$?
  (cd "$TD_norepo" && PATH="$D:$PATH" bash "$PRE_PUSH" </dev/null >/dev/null 2>&1); r2=$?
  (cd "$PLUGIN" && PATH="$D:$PATH" SPECOPS_RUN_ALL=1 bash "$PRE_PUSH" </dev/null >/dev/null 2>&1); r3=$?
  (cd "$PLUGIN" && PATH="$D:$PATH" bash "$PRE_PUSH" <<< "$ZERO" >/dev/null 2>&1); r4=$?
  _e=$(date +%s); _d=$((_e - _s))

  if [ ! -f "$SENT" ] && [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$r3" -eq 0 ] && [ "$r4" -eq 0 ] && [ "$_d" -lt 20 ]; then
    ok "GH-ci.R1 면제 4경로 무오염 (gh 미호출 · ${_d}s < 20s = run-all 미실행)"
  else
    nope "GH-ci.R1" "sentinel=$([ -f "$SENT" ] && echo 호출됨 || echo 부재) rc=$r1/$r2/$r3/$r4 소요=${_d}s"
  fi
  rm -rf "$D" "$TD_nogit" "$TD_norepo"
else
  nope "GH-ci.R1" "pre-push 부재"
fi

# GH-ci.doc: gh 선택 의존이 문서화됐는가 (GH-10 과 동형 — 의존 고지는 문서가 유일한 층)
#   CLAUDE.md 측은 'gh' 로 grep 하면 안 된다 — 기존 문장("gh pr create" 등)에 이미 매치해
#   편집 전부터 green 인 vacuous 검사가 된다. 고유 문구로 잠근다.
grep -q 'check-ci-status' "$PLUGIN/scripts/README.md" && grep -q 'CI 상태 경고' "$PLUGIN/CLAUDE.md" \
  && ok "GH-ci.doc CLAUDE.md·scripts/README gh 의존 고지" \
  || nope "GH-ci.doc" "문서 고지 부재"

finish
