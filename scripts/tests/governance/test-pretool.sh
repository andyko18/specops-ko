#!/usr/bin/env bash
# pretool-governance.sh 단위 — 4종 모드 + R-2 + 미매칭 + fail-open
set -uo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(cd "$script_dir/../../.." && pwd)
HOOK="$PLUGIN/hooks/pretool-governance.sh"
FIX="$script_dir/fixtures/transcripts"
pass=0; fail=0
check() { if printf '%s' "$3" | grep -q "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 — expected '$2' in: $3"; fail=$((fail+1)); fi; }
mkstdin() { jq -nc --arg c "$1" --arg t "$2" '{tool_name:"Bash", tool_input:{command:$c}, transcript_path:$t}'; }

# deny 테스트 격리용 공유 sandbox — 코드(.sh) staged 로 is_docs_only_change 면제 미발동 유도
# (실 repo working tree 의 .md dirty 오염과 분리 — pretool-governance L19 CLAUDE_PROJECT_DIR cd)
codesandbox=$(mktemp -d) || exit 1
# .specops 보유 = specops 관할 repo (M2 가드 통과 → verify 강제 검사 진입). deny 의도 유지.
( cd "$codesandbox" && git init -q && echo "echo x" > a.sh && git add a.sh && mkdir .specops )
trap 'rm -rf "$codesandbox"' EXIT

# 자기오염 회귀 락 — 어떤 케이스도 실제 repo 의 active-FID friction-log 에 BYPASS-ENV 를 쓰면 안 된다.
#   세션-env BYPASS 케이스가 CLAUDE_PROJECT_DIR 격리를 빠뜨리면 run-all(cd $PLUGIN) 실행 시 실제
#   .specops/<FID>/friction-log.jsonl 을 오염시킨다(감사 무결성 훼손). suite 시작 count 를 기록해 끝에서 대조.
_repo_fl=$(ls "$PLUGIN/.specops"/*/friction-log.jsonl 2>/dev/null)
_repo_bypass_before=0
[ -n "$_repo_fl" ] && _repo_bypass_before=$(cat $_repo_fl 2>/dev/null | grep -c 'BYPASS-ENV')

out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T1 commit no-verify → deny" '"permissionDecision":"deny"' "$out"
# T2: Skill 호출 + 실제 실행증거 = 정직한 경로 → allow
#   (20260713-verify-exec-gate fixture 보강 — 조임 후 Skill 호출'만'으로는 부족. 구 fixture 는 T2b 로 이관)
# ★ 격리 필수 (20260807 실사용 검증 11호) — 형제 T1·T2b·T2d 는 전부 CLAUDE_PROJECT_DIR 를
#   붙였는데 **T2 만 빠져** 실 repo 루트에서 돌았다. 그래서 훅이 repo 의 **실제 활성 FID** 를
#   해석하고 그 FID 의 진행 기록을 봤다 — 활성 FID 가 verify 미완료면 T2 가 red 가 된다.
#   평소엔 활성 FID 가 우연히 verify PASS 라 통과했고, **실제 lifecycle 을 돌리는 순간 red**.
#   allow 케이스라 ②진행기록 앵커까지 필요하므로 전용 sandbox 를 만든다.
allowsandbox=$(mktemp -d) || exit 1
( cd "$allowsandbox" && git init -q && echo "echo x" > a.sh && git add a.sh \
  && mkdir -p .specops/20260101-t2allow \
  && printf '# Session Progress\n\n## 20260101-t2allow\n\n- 2026-01-01 10:00 /verify PASS\n' \
     > .specops/session-progress.md )
trap 'rm -rf "$codesandbox" "$allowsandbox"' EXIT
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$allowsandbox" bash "$HOOK" 2>/dev/null)
check "T2 commit with-verify(+exec) → allow" '"continue":true' "$out"
# T2b ★ 조임 — Skill 호출만(실행증거 없음) → deny (구 T2 가 allow 하던 것)
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2b ★ Skill 호출만(실행증거 없음) → deny" '"permissionDecision":"deny"' "$out"
# T2c·T2d 심층 필터 통합 잠금 (verify-exec-gate 잔여 backlog — 단위 T9·T10 은 인라인 fixture 라
#   pretool 통합 경로(훅 전체 파이프)의 is_error·negative guard 배선은 별도 파일 fixture 로 잠근다)
# ── T-stale.a~c: deny 사유가 stale 을 stale 이라고 말한다 (FID 20260828-deny-cause-truth) ──
# 왜: 러너를 정직하게 완주하고 그 뒤 파일을 고치면 stale 로 막히는데(설계상 옳다), 메시지는
#   "이 세션에 러너 실행 기록이 없습니다" 라고 **거짓 원인**을 말했다. 사용자는 방금 돌린 러너를
#   또 돌리거나(수분대 낭비) 게이트를 결함으로 의심하고 BYPASS 로 간다.
#   실측: 마찰로그 BYPASS 24건 중 **15건이 "이 세션에서 verify PASS" 를 사유로 적었다** —
#   증거가 있었는데 막힌 것이고, 4건은 아예 "게이트 결함 의심" 이라고 썼다.
#   틀린 deny 문안이 BYPASS 를 유도한 것은 이번이 **두 번째**다(v1.45.0 이 같은 이유로 문안 교체).
out=$(mkstdin "git commit -m x" "$FIX/pretool-verify-then-edit.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-stale.a 러너 PASS 후 코드 편집 → deny 유지(판정은 불변)" '"permissionDecision":"deny"' "$out"
# 'stale' 단어만 요구하면 안 된다 — 구 문안에도 "stale 위험도 있습니다" 가 있어 tautology 다(실측).
#   원인을 **구별해서** 말하는 고유 문구를 요구한다.
check "T-stale.b ★ 사유가 '러너 실행 후 코드 수정' 을 명시" '그 뒤 코드가 수정' "$out"
if printf '%s' "$out" | grep -q '러너 실행 기록이 없습니다'; then
  echo "FAIL T-stale.c 거짓 원인 잔존 — 증거가 있는데 '실행 기록이 없습니다' 라고 말함"; fail=$((fail+1))
else
  echo "PASS T-stale.c 거짓 원인 제거"; pass=$((pass+1))
fi
# 되돌려-관찰: 증거가 **정말로** 없는 경로는 종전 문안을 유지해야 한다(과잉 일반화 차단)
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-stale.d 증거 부재 경로는 종전 문안 유지" '러너 실행 기록이 없습니다' "$out"

out=$(mkstdin "git commit -m x" "$FIX/pretool-verify-exec-error.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2c 러너 is_error 결과(PASS 문자열) → deny (에러 실행 불인정)" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git commit -m x" "$FIX/pretool-verify-exec-partial-mixed.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2d PASS/PARTIAL 혼재 출력 → deny (negative guard)" '"permissionDecision":"deny"' "$out"
# T3 는 CLAUDE_PROJECT_DIR 격리 필수 — repo 루트서 실행(run-all cd $PLUGIN)하면
#   세션-env BYPASS 가 실제 active-FID friction-log 에 BYPASS-ENV 를 기록해 자기오염(감사 무결성 훼손).
#   T-bypass-log.a 와 동일 격리 패턴(mktemp -d + .specops + CLAUDE_PROJECT_DIR override) 적용. 훅 로직은 불변.
bs_t3=$(mktemp -d); mkdir -p "$bs_t3/.specops"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 CLAUDE_PROJECT_DIR="$bs_t3" bash "$HOOK" 2>/dev/null)
check "T3 env bypass → allow" '"continue":true' "$out"
rm -rf "$bs_t3"
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T4 pr no-verify → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "ls -la" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T5 unmatched → allow" '"continue":true' "$out"
out=$(printf 'NOT JSON' | bash "$HOOK" 2>/dev/null)
check "T6 bad json → allow" '"continue":true' "$out"
# T7 §auto — 실행증거 없으면 더 이상 면제되지 않는다 (AC-11 — 20260713-verify-exec-gate 조임).
#   구 기대값은 "§auto exempt → allow" 였다. 근거: `§auto: true` 라벨은 모델이 spec.md 에 쓰는 자기발급
#   면제표라, 무인 진입(/start-auto·/start-all-auto)이면 실행-근거 gate 가 통째로 무효화됐다.
#   §auto 의 의미는 "가역 게이트 자동 통과"(사용자 확인 생략)이지 "검증 면제"가 아니다.
tmproot=$(mktemp -d) || exit 1
( cd "$tmproot" && git init -q && echo "echo x" > a.sh && git add a.sh )
mkdir -p "$tmproot/.specops/20260101-auto-fixture"
printf '## 20260101-auto-fixture\n' > "$tmproot/.specops/session-progress.md"
printf '# spec\n**§auto**: true\n' > "$tmproot/.specops/20260101-auto-fixture/spec.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$tmproot" bash "$HOOK" 2>/dev/null)
check "T7 ★ §auto + 실행증거 없음 → deny" '"permissionDecision":"deny"' "$out"
# T7b §auto + 실행증거 있음 → allow (정직한 무인 흐름 무손상 — AC-12)
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$tmproot" bash "$HOOK" 2>/dev/null)
check "T7b §auto + 실행증거 → allow" '"continue":true' "$out"
rm -rf "$tmproot"

# T-auto-removed: §auto 무조건 면제 블록이 코드에서 제거됐는지 구조 검사 (AC-10)
#   패턴은 **코드형**(`grep -qE '...§auto...spec.md'` 호출 라인)만 매치한다 — 단순 '§auto.*spec.md' 로
#   하면 제거 자리에 남긴 근거 주석과도 매치되어 영원히 FAIL 한다.
if grep -qE "grep -qE .*§auto.*spec\.md" "$PLUGIN/hooks/pretool-governance.sh" 2>/dev/null; then
  echo "FAIL T-auto-removed — §auto 무조건 면제 블록 잔존"; fail=$((fail+1))
else
  echo "PASS T-auto-removed §auto 면제 블록 제거됨"; pass=$((pass+1))
fi

# T8~T12 evasion 우회 deny (no-verify fixture)
out=$(mkstdin "cd /tmp && git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T8 compound commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git -C . commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T9 -C commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin " git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T10 선행공백 commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "env FOO=1 git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T11 env-prefix commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "cd /x && gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T12 compound pr create → deny" '"permissionDecision":"deny"' "$out"
# T13~T15 오탐 allow (commit/pr 아님)
out=$(mkstdin 'echo "git commit"' "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T13 echo string → allow" '"continue":true' "$out"
out=$(mkstdin "mygit commit" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T14 mygit → allow" '"continue":true' "$out"
out=$(mkstdin "git committed --amend" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T15 committed 단어경계 → allow" '"continue":true' "$out"
out=$(mkstdin "git commit-tree abc123" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T15b commit-tree plumbing(over-match 해소) → allow" '"continue":true' "$out"

# T16 docs-only(.md staged) → allow [면제, AC-R-1]
dgit=$(mktemp -d) || exit 1; ( cd "$dgit" && git init -q && echo x > CHANGELOG.md && git add CHANGELOG.md )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$dgit" bash "$HOOK" 2>/dev/null)
check "T16 docs-only → allow" '"continue":true' "$out"
rm -rf "$dgit"
# T17 코드 혼합(.md+.sh staged) → deny [보안 불변식, AC-R-2]
mgit=$(mktemp -d) || exit 1; ( cd "$mgit" && git init -q && echo x > a.md && echo y > b.sh && git add a.md b.sh && mkdir .specops )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$mgit" bash "$HOOK" 2>/dev/null)
check "T17 코드혼합 → deny" '"permissionDecision":"deny"' "$out"
rm -rf "$mgit"
# T18 staged docs + unstaged tracked 코드 + `git commit -am` → deny [commit -am 우회 차단, 보안 Critical]
agit=$(mktemp -d) || exit 1; ( cd "$agit" && git init -q && echo "echo orig" > tracked.sh && git add tracked.sh && git commit -q -m init
  echo doc > README.md && git add README.md && echo "echo changed" > tracked.sh && mkdir .specops )
out=$(mkstdin "git commit -am wip" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$agit" bash "$HOOK" 2>/dev/null)
check "T18 commit -am unstaged-code 우회 → deny" '"permissionDecision":"deny"' "$out"
rm -rf "$agit"

# T19~T22 F-1/F-2 신규 우회 deny (codesandbox 코드-staged 로 docs-only 면제 미발동)
out=$(mkstdin "git -c k=v commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T19 git -c k=v commit 우회 → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git --no-pager commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T20 git --no-pager commit 우회 → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "FOO=bar git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T21 bare VAR=val prefix commit 우회 → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "GH_TOKEN=t gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T22 bare VAR=val prefix gh pr create 우회 → deny" '"permissionDecision":"deny"' "$out"
# T21b~T22b 인용 공백값 prefix 우회 차단 (20260716-batch-dogfood widening — `FOO='a b'` 가 prefix 체인을
#   끊어 트리거를 통째로 비껴갔다. rules.jsonl R-1/R-2 도 동기 수정)
out=$(mkstdin "FOO='a b' git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T21b 인용(single) 공백값 prefix commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin 'FOO="a b" gh pr create --fill' "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T22b 인용(double) 공백값 prefix gh pr create → deny" '"permissionDecision":"deny"' "$out"
# T23~T24 신규 false-positive 보존 (서브커맨드 인자 commit — trigger 미매칭 allow)
out=$(mkstdin "git config commit.gpgsign true" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T23 git config commit.X → allow" '"continue":true' "$out"
out=$(mkstdin "git log --grep=commit" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T24 git log --grep=commit → allow" '"continue":true' "$out"

# T25~T26 over-match 제거 (commit=ref명 — allow 목표)
out=$(mkstdin "git --no-pager log commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T25 over-match git <opt> log commit → allow" '"continue":true' "$out"
out=$(mkstdin "git -p show commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T26 over-match git -p show commit → allow" '"continue":true' "$out"
# T27~T28 정당 deny 보존 (=형 옵션 + 다중 옵션)
out=$(mkstdin "git --git-dir=/x commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T27 git --git-dir=/x commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git --work-tree /w --bare commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T28 git --work-tree /w --bare commit → deny" '"permissionDecision":"deny"' "$out"
# T29 VAL 경로 over-match (값받음 옵션 뒤 서브커맨드 — allow) [code-review Minor]
out=$(mkstdin "git -C /repo log commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T29 over-match git -C /repo log commit → allow" '"continue":true' "$out"
# T30 --no-advice under-match 해소 (valueless 글로벌 플래그 deny 보존) [code-review Minor]
out=$(mkstdin "git --no-advice commit" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T30 git --no-advice commit → deny" '"permissionDecision":"deny"' "$out"

# T31~T35 선행자 우회 5종 deny (subshell·brace·cmd-subst·백틱 + gh 대칭) [governance-evasion-residual]
out=$(mkstdin "(git commit -m x)" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T31 subshell commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "{ git commit -m x; }" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T32 brace commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "\$(git commit -m x)" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T33 cmd-subst commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "\`git commit -m x\`" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T34 backtick commit → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "(gh pr create --fill)" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T35 subshell pr create → deny" '"permissionDecision":"deny"' "$out"

# T36 ★ inline prefix bypass — 사유(SPECOPS_BYPASS_REASON) 없으면 면제 안 됨 (F-2 조임 — dogfood 20260716:
#   첫 deny 후 모델이 무사유 BYPASS 를 커밋 3회+PR 생성에 관성 사용. 사유 없는 friction-log 는 무정보 감사 기록)
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36 ★ inline bypass 무사유 → deny" '"permissionDecision":"deny"' "$out"
check "T36-msg deny 메시지가 사유 병기 형식 안내" 'SPECOPS_BYPASS_REASON' "$out"
# T36b 사유 병기 → allow (감사 가능한 우회 — 사유가 friction-log evidence_snippet 에 명령 원문으로 잔존)
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='design 커밋 — verify 선행 단계' git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36b inline bypass + 사유 → allow" '"continue":true' "$out"
# T36c REASON 선행 순서도 인정 (형식 순서 함정으로 false-deny 금지)
out=$(mkstdin "SPECOPS_BYPASS_REASON='태스크 중간 커밋' SPECOPS_GOVERNANCE_BYPASS=1 git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36c REASON-선행 순서 + 사유 → allow" '"continue":true' "$out"
# T36d~f 선행자 클래스 정합 (dogfood 20260717 test2: 사유까지 정직 병기한 compound·함수 wrapper BYPASS 가
#   ^줄시작 앵커에 걸려 false-deny — 트리거는 [;&|({`] 선행자를 인식하는데 bypass 인정만 좁던 비대칭 해소)
out=$(mkstdin "git add a.sh && SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='T4 14/14 PASS 실측' git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36d compound(&&) bypass + 사유 → allow" '"continue":true' "$out"
out=$(mkstdin 'B() { SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON="$1" git commit -m "$2"; }; B "사유" "msg"' "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36e 함수 wrapper bypass + 사유 → allow" '"continue":true' "$out"
out=$(mkstdin "git add a.sh && SPECOPS_GOVERNANCE_BYPASS=1 git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36f compound bypass 무사유 → deny (사유 강제 보존)" 'SPECOPS_BYPASS_REASON' "$out"
# T37 메시지 내 토큰 언급은 면제 안 됨 → deny (F-2 우발면제 차단)
out=$(mkstdin 'git commit -m "docs SPECOPS_GOVERNANCE_BYPASS=1 flag"' "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T37 message token → deny" '"permissionDecision":"deny"' "$out"

# T38~T39 통합 wiring (F-1) — transcript 에 verify skill 부재(lookback 밖 시뮬)인 상태에서
# session-progress 의 /verify PASS 자기보고가 어떻게 취급되는지.
# spgit: 코드(.sh) staged 로 docs-only 면제 차단 + .specops/session-progress.md FID 섹션 주입.
# T38 ★ 기대값 뒤집기 (20260713-verify-exec-gate — 구 기대값 allow):
#   session-progress 는 모델이 쓰는 self-report 라 실행증거 없이는 단독 면제 불가.
#   /verify PASS 가 최신이어도(vp=0) 실행증거(rc=1)가 없으면 deny.
#   정직한 경로(같은 session-progress + 실행증거 → allow)는 T-exec.b 가 커버한다.
spgit=$(mktemp -d) || exit 1
( cd "$spgit" && git init -q && echo "echo x" > a.sh && git add a.sh && mkdir -p .specops )
printf '## 20260626-wire\n- 2026-06-26 10:05 /verify PASS (evidence.md, AC 5/5)\n- 2026-06-26 10:00 /implement DONE (T1)\n' > "$spgit/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$spgit" bash "$HOOK" 2>/dev/null)
check "T38 ★ session-progress verify 최신 + 실행증거 없음 → deny (조임)" '"permissionDecision":"deny"' "$out"
# T39 negative: /implement 가 /verify 보다 위(최신) → 무효 → transcript fallback(verify 없음) → deny
printf '## 20260626-wire\n- 2026-06-26 10:10 /implement DONE (재구현)\n- 2026-06-26 10:05 /verify PASS (AC 5/5)\n' > "$spgit/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$spgit" bash "$HOOK" 2>/dev/null)
check "T39 session-progress implement 최신 → deny (R-1 보존)" '"permissionDecision":"deny"' "$out"
# T39b 통합 (거짓면제 0 불변식): T39 와 동일 stale(implement 최신) 상태 + evidence PASS stamp 동시.
# vp=2(affirmative-stale)면 evidence stamp 무시하고 deny — stamp fallback 은 vp=1(inconclusive)만.
# apply_lookback_rule 의 `_vp -eq 1` 가드 제거 시 이 케이스가 allow 로 회귀(red) → 단위(test-verify-progress)가 못 잡는 구멍 보강.
mkdir -p "$spgit/.specops/20260626-wire"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$spgit/.specops/20260626-wire/evidence.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$spgit" bash "$HOOK" 2>/dev/null)
check "T39b stale + evidence PASS stamp → deny (vp=2 stamp 무시, 거짓면제 0)" '"permissionDecision":"deny"' "$out"
rm -rf "$spgit"

# T40 .specops 부재 repo(specops 관할 밖) → verify 강제 면제 → allow [M2 스코프 가드]
# codesandbox 와 동일 구성이나 .specops 없음 — 차이는 오직 M2 가드. 가드 없으면 deny(red).
nosg=$(mktemp -d) || exit 1; ( cd "$nosg" && git init -q && echo "echo x" > a.sh && git add a.sh )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$nosg" bash "$HOOK" 2>/dev/null)
check "T40 .specops 부재 repo → allow (M2 관할 가드)" '"continue":true' "$out"
rm -rf "$nosg"

# T-exec 자기보고 3경로 균일 gate (20260713-verify-exec-gate — AC-5·AC-6·AC-R-2)
#   자기보고 3경로(session-progress /verify PASS · evidence stamp · Skill 호출)는 전부 모델이 쓰는 것이라
#   실행 증거(하네스 작성 tool_result)를 선행 조건으로 요구한다.
execroot=$(mktemp -d) || exit 1
( cd "$execroot" && git init -q && echo "echo x" > a.sh && git add a.sh )
mkdir -p "$execroot/.specops/20260101-forge"
# T-exec.a ★★ AC-R-2 (지배 경로 red): session-progress 에 수기 /verify PASS + 실행증거 없음 → deny
printf '## 20260101-forge\n\n- 2026-01-01 10:00 /verify PASS (evidence.md)\n' > "$execroot/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-progress-forged.jsonl" | CLAUDE_PROJECT_DIR="$execroot" bash "$HOOK" 2>/dev/null)
check "T-exec.a ★ session-progress 위조 + 실행증거 없음 → deny" '"permissionDecision":"deny"' "$out"
# T-exec.b (AC-6): 같은 session-progress + 실행증거 있음 → allow (정직한 경로 무손상)
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$execroot" bash "$HOOK" 2>/dev/null)
check "T-exec.b session-progress + 실행증거 → allow" '"continue":true' "$out"
# T-exec.c (AC-5): evidence stamp 위조 + 실행증거 없음 → deny
printf '## 20260101-forge\n' > "$execroot/.specops/session-progress.md"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$execroot/.specops/20260101-forge/evidence.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-progress-forged.jsonl" | CLAUDE_PROJECT_DIR="$execroot" bash "$HOOK" 2>/dev/null)
check "T-exec.c evidence stamp 위조 + 실행증거 없음 → deny" '"permissionDecision":"deny"' "$out"
# T-exec.d (AC-6 stamp-positive): 같은 stamp + 실행증거 있음 → allow
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$execroot" bash "$HOOK" 2>/dev/null)
check "T-exec.d evidence stamp + 실행증거 → allow" '"continue":true' "$out"
rm -rf "$execroot"

# T-msg deny 메시지 정확성 (T3 Phase C — false-block 표면)
#   deny 는 의도된 동작이나, 메시지가 작동하지 않는 해법(Skill 호출)을 안내하면 사용자는 BYPASS 를 남발한다.
#   실제로 게이트를 여는 유일한 행동 = run-verification.sh 재실행 → 메시지가 그것을 안내해야 한다.
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-msg.a ★ deny 메시지가 run-verification.sh 재실행을 안내" 'run-verification.sh' "$out"
check "T-msg.b deny 메시지가 '실행 증거 부재'로 정확히 진술" '실행 증거' "$out"
check "T-msg.c deny 메시지에 BYPASS 안내 유지" 'SPECOPS_GOVERNANCE_BYPASS=1' "$out"
# T-msg.d 틀린 해법(Skill 선행) 안내 잔존 금지 — negative
if printf '%s' "$out" | grep -q 'verifying-evidence-ko 선행'; then
  echo "FAIL T-msg.d 틀린 해법(verifying-evidence-ko 선행) 잔존 — in: $out"; fail=$((fail+1))
else
  echo "PASS T-msg.d 틀린 해법 안내 제거됨"; pass=$((pass+1))
fi

# T-qs 인용 문자열 false-block (20260717-quoted-falseblock — dogfood test2 모델 backlog "R-1 블록주석
#   내부 오검출" probe 실재 확정: printf/echo 인용 인자 속 프로즈의 (·| 선행자가 트리거와 오매칭)
qs1='printf "%s\n" "/*" " * 배포 절차: build 후 (git commit 으로 기록)" " */" > note.js'
out=$(mkstdin "$qs1" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.1 ★ 인용 인자 괄호 프로즈 → allow (false-block 해소)" '"continue":true' "$out"
qs2='printf "%s\n" "// pipeline: build | git commit -m x" >> note.js'
out=$(mkstdin "$qs2" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.2 ★ 인용 인자 파이프 주석 프로즈 → allow" '"continue":true' "$out"
qs3='echo "$(git commit -m x)"'
out=$(mkstdin "$qs3" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.3 ★★ 더블쿼트 내 \$() 실행 → deny (보안 불변식 — 제거 금지)" '"permissionDecision":"deny"' "$out"
qs4='git commit -m "back\\slash \" 포함"'
out=$(mkstdin "$qs4" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.4 이스케이프(\\\\·\\\") 포함 메시지의 진짜 commit → deny (트리거 보존)" '"permissionDecision":"deny"' "$out"
qs4b='printf "%s\n" "escape 문서: build 후 (git commit 으로 기록)" > note.md'
out=$(mkstdin "$qs4b" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.4b ★ \\n 포함 printf 프로즈 → allow (blanket-bail 무력화 방지)" '"continue":true' "$out"
qs5='git commit -m "미종결 인용'
out=$(mkstdin "$qs5" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.5 미종결 인용 bail → deny (fail-safe)" '"permissionDecision":"deny"' "$out"
qs6="git commit -m 'fix: 정상 메시지'"
out=$(mkstdin "$qs6" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-qs.6 인용 메시지의 진짜 commit → deny (트리거 보존)" '"permissionDecision":"deny"' "$out"

# T-mp 커밋 메시지 BYPASS 표식 오염 가드 (dogfood test2 61f9e0d "BYPASS fix: ..." — 우회 표식이
#   git 히스토리에 유입. 우회 기록은 REASON+friction-log 담당, conventional commit 훼손 금지)
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='중간 커밋' git commit -m \"BYPASS fix: x\"" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-mp.a ★ bypass + -m \"BYPASS...\" 메시지 오염 → deny" '"permissionDecision":"deny"' "$out"
check "T-mp.b 오염 deny 메시지가 정상 메시지 재작성 안내" 'conventional commit' "$out"
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='중간 커밋' git commit -m \"fix: 정상\"" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-mp.c bypass + 정상 메시지 → allow (오염 가드 오탐 0)" '"continue":true' "$out"

# T-hd heredoc false-block (20260713-heredoc-false-block)
#   grep -E 는 줄 단위 → 멀티라인 Bash command 의 heredoc **본문** 줄도 트리거에 매칭됐다.
#   → 정직한 문서 작성(spec.md 에 git 예시)이 차단되고 BYPASS 를 남발하게 만들었다.
#   전부 codesandbox(코드-staged + .specops) 로 격리한다: docs-only 면제가 발동하지 않으므로
#   **allow 는 오직 트리거 미매칭(=strip 성공)에서만 나온다** (tautology 차단).
hd_doc='cat > /tmp/spec.md <<EOF
커밋 예시:
git commit -m "feat: x"
EOF'
out=$(mkstdin "$hd_doc" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.a ★ heredoc 문서 본문의 git 예시 → allow (AC-1 false-block 해소)" '"continue":true' "$out"
# T-hd.b (AC-3) heredoc 시작 줄에 결합된 진짜 명령은 유지 → deny
hd_start='cat > /tmp/f.md <<EOF; git commit -m x
본문
EOF'
out=$(mkstdin "$hd_start" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.b ★ heredoc 시작 줄 결합 commit → deny (AC-3)" '"permissionDecision":"deny"' "$out"
# T-hd.c (AC-4) heredoc 종료 후의 진짜 명령은 유지 → deny
hd_after='cat > /tmp/f.md <<EOF
본문
EOF
git commit -m x'
out=$(mkstdin "$hd_after" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.c ★ heredoc 종료 후 commit → deny (AC-4)" '"permissionDecision":"deny"' "$out"
# T-hd.d (AC-5 ★ F-3 표면 불변) 셸 실행자 heredoc 은 본문이 **실제 실행**된다 → 제외 금지 → deny
hd_bash='bash <<EOF
git commit -m x
EOF'
out=$(mkstdin "$hd_bash" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.d ★★ bash <<EOF 본문 commit → deny (AC-5 F-3 표면 불변)" '"permissionDecision":"deny"' "$out"
hd_sh='sh <<'"'"'EOF'"'"'
git commit -m x
EOF'
out=$(mkstdin "$hd_sh" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.e ★ sh <<'EOF' 본문 commit → deny (AC-5)" '"permissionDecision":"deny"' "$out"
# T-hd.f (AC-6) python3 본문은 셸 명령이 아니다(내부 subprocess 는 이미 F-3 클래스) → 제외 → allow
hd_py='python3 <<EOF
git commit -m x
EOF'
out=$(mkstdin "$hd_py" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.f python3 <<EOF 본문 → allow (AC-6)" '"continue":true' "$out"
# T-hd.g (AC-8 fail-safe) 미종료 heredoc → 원본 유지 → 차단 보존 (제거 로직 버그가 차단을 뚫으면 안 된다)
hd_unterm='cat > /tmp/f.md <<EOF
git commit -m x'
out=$(mkstdin "$hd_unterm" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.g ★ 미종료 heredoc → deny (AC-8 fail-safe: 원본 후퇴)" '"permissionDecision":"deny"' "$out"
# T-hd.h <<-'EOF' (탭 들여쓰기 + 인용 delimiter) 문서 → allow
hd_dash=$'cat > /tmp/f.md <<-\'EOF\'\n\tgit commit -m "예시"\n\tEOF'
out=$(mkstdin "$hd_dash" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-hd.h <<-'EOF' 탭 들여쓰기 문서 → allow (AC-1 변형)" '"continue":true' "$out"

# ══════════════════════════════════════════════════════════════════════════
# batch PR 뭉개짐 게이트 (20260721-batch-pr-teeth)
#   dogfood test1: 무인 batch 가 7개 per-FR FID 를 BATCH_ID 하나로 뭉갠 채 PR 을 냈고,
#   teeth(batch-state.sh)는 start-all.md 산문에만 있어 아무도 호출하지 않았다.
#   근거: .specops/audit/dogfood-test1-20260721.md HIGH-3
# ══════════════════════════════════════════════════════════════════════════

# batch sandbox 빌더 — $1=라벨, $2=산출물 생성 여부(1/0), $3=ACTIVE 마커 여부(기본 1)
_mk_batch_sandbox() {
  local label="$1" arts="$2" active="${3:-1}" root
  root=$(mktemp -d) || return 1
  ( cd "$root" && git init -q && echo "echo x" > a.sh && git add a.sh )
  mkdir -p "$root/.specops/batch-p" "$root/.specops/memory"
  cat > "$root/.specops/batch-p/queue.md" <<EOF
| FR-ID | FID | 설명 | Status |
|---|---|---|---|
| FR-4 | 20260721-login | 로그인 | $label |
EOF
  printf '| FR-4 | a | M1 | must | s | f |\n' > "$root/.specops/memory/requirements.md"
  [ "$active" = "1" ] && : > "$root/.specops/batch-p/ACTIVE"
  # batch PR 은 feat/<BATCH_ID> 에서 난다 (start-all.md Phase 0). 게이트 판정 조건이므로 기본값으로 맞춘다.
  ( cd "$root" && git checkout -q -b "feat/batch-p" 2>/dev/null )
  if [ "$arts" = "1" ]; then
    mkdir -p "$root/.specops/20260721-login"
    : > "$root/.specops/20260721-login/review-base.sha"
    : > "$root/.specops/20260721-login/review-request.md"
    # Wave B: ACTIVE batch PR 는 RELEASE_READY hard — 정직 fixture는 축 충족해야 false-block 금지
    # 20260829-bare-skip-teeth: SKIP 근거는 라인 인용 필수(skip_cite 축) — 무인용이면 정직 fixture 가
    #   NOT_READY 로 떨어져 T-batch.b 가 red 가 된다. 계약 변경에 fixture 를 맞춘 것이지 완화가 아니다.
    cat > "$root/.specops/20260721-login/evidence.md" <<'EOF'
RUN-VERIFICATION-RESULT: PASS

## /security-review PASS
**결과**: PASS

## /integration-test PASS
**결과**: PASS

## /performance-test SKIP
**결과**: SKIP
**근거**: §NFR L8-12 — 성능 임계값 없음
EOF
    # reconcile DESYNC 방지 — review-request 있으면 evidence=70, 기록도 review 이상
    printf '## 20260721-login\n\n- 2026-07-21 13:53 /verify PASS (evidence.md)\n- 2026-07-21 14:00 /request-review DONE\n' \
      > "$root/.specops/session-progress.md"
  else
    printf '# session progress\n' > "$root/.specops/session-progress.md"
  fi
  printf '%s' "$root"
}

# ── T-batch.a ★ test1 실물: 라벨 DONE + 산출물 부재 batch → PR deny ──
bs_bad=$(_mk_batch_sandbox "DONE" 0)
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_bad" bash "$HOOK" 2>/dev/null)
check "T-batch.a ★ 뭉개진 batch PR → deny" '"permissionDecision":"deny"' "$out"
check "T-batch.a2 deny 사유에 batch 게이트 명시" 'BATCH-GATE' "$out"

# ── T-batch.b ★ 정직한 batch(per-FR 산출물·진행기록 완비) → allow (false-block 금지) ──
#   이 케이스가 열리지 않으면 게이트는 BYPASS 를 강요하는 함정이 된다 — test1 이 겪은 바로 그것.
bs_ok=$(_mk_batch_sandbox "IMPL_DONE" 1)
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_ok" bash "$HOOK" 2>/dev/null)
check "T-batch.b ★ 정직한 batch PR → allow" '"continue":true' "$out"

# ── T-batch.c ★ 인라인 BYPASS 로는 못 뚫는다 (비가역 불변식) ──
#   security Critical/High 와 동급 — start-all-auto.md L56 선례. 없으면 test1 이 한 그대로 우회된다.
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='배치 PR 승인' gh pr create --fill" \
  "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_bad" bash "$HOOK" 2>/dev/null)
check "T-batch.c ★ 인라인 BYPASS + 뭉개진 batch → deny (불인정)" '"permissionDecision":"deny"' "$out"

# ── T-batch.d 세션 env BYPASS 는 인정 (사용자 주권 — 5원칙 4) ──
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 CLAUDE_PROJECT_DIR="$bs_bad" bash "$HOOK" 2>/dev/null)
check "T-batch.d 세션 env BYPASS → allow (주권 보존)" '"continue":true' "$out"

# ── T-batch.e batch 컨텍스트 아님 → 기존 동작 불변 (회귀) ──
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-batch.e 비-batch PR → 기존 deny 사유 유지(batch 무관)" '"permissionDecision":"deny"' "$out"
if printf '%s' "$out" | grep -q 'BATCH-GATE'; then
  echo "FAIL T-batch.e2 — 비-batch PR 에 batch 게이트 오발화"; fail=$((fail+1))
else
  echo "PASS T-batch.e2 비-batch PR 에 batch 게이트 미발화"; pass=$((pass+1))
fi

# ── T-batch.f commit 은 batch 게이트 대상 아님 (PR 전용 — 중간 커밋은 설계된 비용) ──
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_bad" bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q 'BATCH-GATE'; then
  echo "FAIL T-batch.f — commit 에 batch 게이트 오발화(PR 전용이어야)"; fail=$((fail+1))
else
  echo "PASS T-batch.f commit 에 batch 게이트 미발화 (PR 전용)"; pass=$((pass+1))
fi
# ── T-batch.g ★★ ghost-block 금지 — 진행 중이 아닌 과거 batch 는 무관한 PR 을 막지 않는다 ──
#   .specops/* 는 gitignore 라 뭉개진 batch 디렉토리가 디스크에 무기한 남는다. glob-latest 로
#   아무 batch 나 집으면, 그 batch 와 **아무 상관 없는** 단일 FID 작업의 PR 이 과거 라벨 오염으로
#   차단된다. 실측 재현(specops-test1): 무관한 PR 이 batch-20260721b 의 `DONE` 때문에 deny.
#   게다가 이 게이트는 인라인 BYPASS 앞이라, 탈출구가 "세션 전체 거버넌스 해제"뿐이 된다 —
#   false-block 의 유일한 출구가 보호 장치 무력화라는 최악의 형태다.
#   따라서 게이트는 **진행 중(ACTIVE 마커) batch 만** 판정한다.
bs_stale=$(_mk_batch_sandbox "DONE" 0 0)
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_stale" bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q 'BATCH-GATE'; then
  echo "FAIL T-batch.g ★★ ghost-block — 진행 중 아닌 과거 batch 가 무관한 PR 차단"; fail=$((fail+1))
else
  echo "PASS T-batch.g ★★ ACTIVE 마커 없는 과거 batch → 게이트 미발화 (ghost-block 금지)"; pass=$((pass+1))
fi
# ── T-batch.h ★★ 마커가 있어도 이 PR 이 그 batch 의 PR 이 아니면 판정하지 않는다 ──
#   마커는 "batch 가 진행 중인가"에만 답한다. 게이트가 필요한 답은 "이 PR 이 그 batch 의 PR 인가"다.
#   특히 **중단된 batch**: 마커는 PR 성공(Step D)에서만 지워지는데, 게이트는 뭉개진 batch 를 막는 것이
#   목적이라 막힌 batch 는 Step D 에 도달하지 못한다 → 마커가 영구히 남는다 → 이후 모든 무관한 PR 이
#   영구 차단된다. 게이트가 잘 막을수록 오염 마커가 쌓이는 역설.
#   판별자는 브랜치다 — batch PR 은 feat/<BATCH_ID> 에서 난다(start-all.md Phase 0).
#   불일치는 skip(fail-open) — false-block 회피가 옳은 오류 방향이다.
bs_other=$(_mk_batch_sandbox "DONE" 0)
( cd "$bs_other" && git checkout -q -b "feat/20260721-unrelated" )
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-with-verify-exec.jsonl" | CLAUDE_PROJECT_DIR="$bs_other" bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q 'BATCH-GATE'; then
  echo "FAIL T-batch.h ★★ 마커 있으나 무관한 브랜치 PR 차단 (중단 batch 영구 ghost-block)"; fail=$((fail+1))
else
  echo "PASS T-batch.h ★★ 무관한 브랜치 PR → 게이트 미발화 (batch PR 만 판정)"; pass=$((pass+1))
fi
rm -rf "$bs_bad" "$bs_ok" "$bs_stale" "$bs_other"

# ── T-msg deny 메시지 정확성 (HIGH-1) ──
#   기존 문안은 "러너를 실행한 뒤 재시도하세요"만 안내한다. 그런데 실행 증거는 **필요조건일 뿐**이고,
#   FID-scoped 진행 기록 앵커가 없으면 여전히 열리지 않는다(governance-lib.sh:481-500).
#   test1 은 안내대로 러너를 재실행하고도 같은 메시지로 또 막혀 BYPASS 로 갔다.
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-msg ★ deny 메시지가 진행 기록 앵커 요건도 안내" 'session-progress' "$out"

# ── T-bypass-log: 세션-env BYPASS friction-log 기록 (감사 상한 3호) ──
bslog=$(mktemp -d); mkdir -p "$bslog/.specops"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 CLAUDE_PROJECT_DIR="$bslog" bash "$HOOK" 2>/dev/null)
check "T-bypass-log.a 세션-env BYPASS → allow" '"continue":true' "$out"
if [ -f "$bslog/.specops/friction-log.jsonl" ] && grep -q "BYPASS-ENV" "$bslog/.specops/friction-log.jsonl"; then
  echo "PASS T-bypass-log.b friction-log BYPASS-ENV 기록 생성"; pass=$((pass+1))
else echo "FAIL T-bypass-log.b — 기록 없음"; fail=$((fail+1)); fi
rm -rf "$bslog"
bsno=$(mktemp -d)
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 CLAUDE_PROJECT_DIR="$bsno" bash "$HOOK" 2>/dev/null)
check "T-bypass-log.c 비-specops BYPASS → allow" '"continue":true' "$out"
if [ ! -d "$bsno/.specops" ]; then echo "PASS T-bypass-log.d .specops 미생성(관할 한정)"; pass=$((pass+1))
else echo "FAIL T-bypass-log.d — .specops 생성됨(월권)"; fail=$((fail+1)); fi
rm -rf "$bsno"

# ── T-inline-bypass-log: **인라인** BYPASS 사유의 friction-log 감사 기록 (실사용 검증 3호) ──
# 20260807 실측 결함: deny 메시지(pretool:159)와 주석(:135)이 "사유는 **명령 원문째**
#   friction-log evidence_snippet 에 남는다" 고 약속하는데, 인라인 경로(:151-158)는
#   `_record_bypass_metric` 만 부르고 `log_friction` 을 **부르지 않았다**.
#   실측: 실제 bypass 커밋 전후 BYPASS-ENV 기록 0 → 0, metrics 만 1건
#   (`{"phase":"governance-bypass","fallback":true}` — 사유·명령 원문 없음).
#   세션-env 경로(T-bypass-log.b)는 부르는데 인라인만 빠졌다 — 우회의 **책임 추적이 통째로 공백**.
ibl=$(mktemp -d); mkdir -p "$ibl/.specops"
_inline_cmd="SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='게이트 결함 수정 부트스트랩' git commit -m x"
out=$(mkstdin "$_inline_cmd" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$ibl" bash "$HOOK" 2>/dev/null)
check "T-inline-bypass-log.a 사유 병기 인라인 BYPASS → allow" '"continue":true' "$out"
if [ -f "$ibl/.specops/friction-log.jsonl" ] && grep -q "BYPASS-ENV" "$ibl/.specops/friction-log.jsonl"; then
  echo "PASS T-inline-bypass-log.b 인라인 BYPASS friction-log 기록 생성"; pass=$((pass+1))
else echo "FAIL T-inline-bypass-log.b — 기록 없음 (deny 메시지의 감사 약속 불이행)"; fail=$((fail+1)); fi
# ★ 핵심: 기록만이 아니라 **사유 문자열이 실제로** 들어 있어야 한다.
#   식별자만 남기면 "우회 횟수만 아는 무정보 감사"(:134 주석이 지적한 바로 그것)가 된다.
if grep -q "게이트 결함 수정 부트스트랩" "$ibl/.specops/friction-log.jsonl" 2>/dev/null; then
  echo "PASS T-inline-bypass-log.c 사유 원문이 evidence_snippet 에 보존"; pass=$((pass+1))
else echo "FAIL T-inline-bypass-log.c — 사유 원문 유실 (식별자만 남음 = 무정보 감사)"; fail=$((fail+1)); fi
rm -rf "$ibl"
# 관할 한정 — 비-specops repo 는 인라인 BYPASS 여도 .specops 를 만들지 않는다 (세션-env T-bypass-log.d 와 대칭)
ibno=$(mktemp -d)
out=$(mkstdin "$_inline_cmd" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$ibno" bash "$HOOK" 2>/dev/null)
if [ ! -d "$ibno/.specops" ]; then
  echo "PASS T-inline-bypass-log.d 비-specops 는 .specops 미생성(관할 한정)"; pass=$((pass+1))
else echo "FAIL T-inline-bypass-log.d — .specops 생성됨(월권)"; fail=$((fail+1)); fi
rm -rf "$ibno"

# ── T-inline-bypass-log.e: 사유가 명령 **뒤쪽**에 있어도 evidence 에 남는가 (4호) ──
# 20260807 실측: 3호 수정이 `${tool_cmd:0:200}` **앞부분 절단**이라, 앞에 cd·echo 같은
#   전처리가 붙으면 200자가 거기서 소진돼 **사유가 통째로 잘렸다**.
#   실제 기록: "inline SPECOPS_GOVERNANCE_BYPASS: cd /Users/… echo …건 ===\"\nSPE" ← 여기서 끝
#   "사유는 명령 앞쪽에 온다"는 3호 커밋의 근거 자체가 틀렸다 — compound·전처리가 붙으면 뒤로 밀린다.
#   위치 무관 **추출**이어야 한다.
ible=$(mktemp -d); mkdir -p "$ible/.specops"
# ⚠️ 200자를 **실제로** 넘겨야 결함이 재현된다. 짧은 pad 로는 테스트가 공허해진다(첫 시도 실측 — PASS 로 통과했다).
#    bash ${var:0:200} 은 문자 단위라 한글도 1자로 센다. 넉넉히 250자+ 를 만든다.
_pad="echo AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA && echo BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB && echo CCCCCCCCCCCCCCCCCCCCCCCCCCCCCC && echo DDDDDDDDDDDDDDDDDDDDDDDDDDDDDD && echo EEEEEEEEEEEEEEEEEEEEEEEEEEEEEE && echo FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF && echo GGGGGGGGGGGGGGGGGGGGGGGGGGGGGG &&"
[ "${#_pad}" -gt 200 ] || { echo "FAIL T-inline-bypass-log.e0 — pad 가 200자 미만(${#_pad}) 이라 결함 미재현"; fail=$((fail+1)); }
_late_cmd="$_pad SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='사유가뒤쪽에온다' git commit -m x"
out=$(mkstdin "$_late_cmd" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$ible" bash "$HOOK" 2>/dev/null)
check "T-inline-bypass-log.e1 뒤쪽 사유 인라인 BYPASS → allow" '"continue":true' "$out"
if grep -q "사유가뒤쪽에온다" "$ible/.specops/friction-log.jsonl" 2>/dev/null; then
  echo "PASS T-inline-bypass-log.e2 위치 무관 사유 추출 (앞부분 절단 아님)"; pass=$((pass+1))
else
  echo "FAIL T-inline-bypass-log.e2 — 사유 유실. evidence=$(grep -h 'BYPASS-ENV' "$ible/.specops/friction-log.jsonl" 2>/dev/null | head -c 200)"; fail=$((fail+1))
fi
rm -rf "$ible"
# 큰따옴표·무따옴표 형식도 동일하게 추출되는가 (형식 함정 false-negative 금지)
for _q in 'dq' 'bare'; do
  _d=$(mktemp -d); mkdir -p "$_d/.specops"
  case "$_q" in
    dq)   _c="SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON=\"큰따옴표사유\" git commit -m x"; _want='큰따옴표사유' ;;
    bare) _c="SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON=무따옴표사유 git commit -m x";     _want='무따옴표사유' ;;
  esac
  out=$(mkstdin "$_c" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$_d" bash "$HOOK" 2>/dev/null)
  # ★ substring 이 아니라 `reason=<값>` 정확 매칭 — 따옴표가 **벗겨졌는지**까지 본다.
  #   느슨하게 보면 무따옴표 fallback 이 `reason="값"` 으로 뽑아도 통과해
  #   따옴표 분기가 무검증 코드가 된다(변이 생존 실측 20260807).
  if grep -q "reason=$_want " "$_d/.specops/friction-log.jsonl" 2>/dev/null; then
    echo "PASS T-inline-bypass-log.e3-$_q $_q 형식 사유 추출(따옴표 제거)"; pass=$((pass+1))
  else
    echo "FAIL T-inline-bypass-log.e3-$_q — $_q 형식 미정규화. got=$(grep -o 'reason=[^|]*' "$_d/.specops/friction-log.jsonl" 2>/dev/null | head -1)"; fail=$((fail+1))
  fi
  rm -rf "$_d"
done

# ── T-compound-split: Wave C — git add&&commit deny 사유에 분리 안내 포함 ──
out=$(mkstdin "git add a.sh && git commit -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T-compound-split.a compound add+commit → deny" '"permissionDecision":"deny"' "$out"
check "T-compound-split.b deny 사유에 분리 안내" '별도 Bash 호출' "$out"
# commit-only deny 에는 compound 안내가 없어야 한다 (오안내 방지)
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
if printf '%s' "$out" | grep -q '"permissionDecision":"deny"' \
   && ! printf '%s' "$out" | grep -q '별도 Bash 호출'; then
  echo "PASS T-compound-split.c commit-only 에 compound 안내 없음"; pass=$((pass+1))
else
  echo "FAIL T-compound-split.c — unexpected compound hint or allow: $out"; fail=$((fail+1))
fi

# ── T-bypass-metric: BYPASS 시 metrics.jsonl에 식별자만 기록 (사유 원문 없음) ──
bsm=$(mktemp -d)
mkdir -p "$bsm/.specops/20260803-bypass-metric"
printf '<!-- active-fid: 20260803-bypass-metric -->\n## 20260803-bypass-metric\n' \
  > "$bsm/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" \
  | SPECOPS_GOVERNANCE_BYPASS=1 CLAUDE_PROJECT_DIR="$bsm" bash "$HOOK" 2>/dev/null)
check "T-bypass-metric.a 세션-env BYPASS → allow" '"continue":true' "$out"
if [ -f "$bsm/.specops/20260803-bypass-metric/metrics.jsonl" ] \
   && jq -e '.phase=="governance-bypass" and .fallback==true' \
        "$bsm/.specops/20260803-bypass-metric/metrics.jsonl" >/dev/null; then
  echo "PASS T-bypass-metric.b phase=governance-bypass 기록"; pass=$((pass+1))
else
  echo "FAIL T-bypass-metric.b — metric=$(cat "$bsm/.specops/20260803-bypass-metric/metrics.jsonl" 2>/dev/null)"
  fail=$((fail+1))
fi
rm -rf "$bsm"

# ── T-no-selfcontam: suite 전체가 실제 repo friction-log 를 오염시키지 않았는지 최종 락 ──
# 재-glob: suite 중간에 새로 생긴 friction-log 도 잡는다(baseline glob 은 부재 시 빈값 → 0 이므로 신규 오염이 여전히 count>0 로 검출됨).
_repo_fl=$(ls "$PLUGIN/.specops"/*/friction-log.jsonl 2>/dev/null)
_repo_bypass_after=0
[ -n "$_repo_fl" ] && _repo_bypass_after=$(cat $_repo_fl 2>/dev/null | grep -c 'BYPASS-ENV')
if [ "$_repo_bypass_after" -eq "$_repo_bypass_before" ]; then
  echo "PASS T-no-selfcontam repo friction-log BYPASS-ENV 무변경 (${_repo_bypass_before}->${_repo_bypass_after})"; pass=$((pass+1))
else
  echo "FAIL T-no-selfcontam — repo friction-log 자기오염 (${_repo_bypass_before}->${_repo_bypass_after})"; fail=$((fail+1))
fi

# ── deny 안내문 보강 (20260807-bg-verify-evidence) ──
# 백그라운드 실행이 증거로 인정되게 바뀌면서, "왜 막혔는지" 를 원인별로 구분해 안내해야 한다.
# 구분이 없으면 사용자는 방금 러너를 돌리고도 "실행 기록이 없습니다" 를 보고 원인을 모른다.
_PT_SRC=$(cat "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/hooks/pretool-governance.sh")

# P-bg1 — 포그라운드 timeout 지침 (AC-5)
check "P-bg1 deny 메시지에 포그라운드 timeout 지침" 'timeout' "$_PT_SRC"
check "P-bg1b 포그라운드 문구" '포그라운드' "$_PT_SRC"

# P-bg2 — 백그라운드 미회수 구분 안내 (AC-7) — **behavioral**
#   ★ 소스 문자열 grep 으로 검사하면 배선이 끊겨도 통과한다(Phase B 적발: _EXEC_BG_PENDING_PATH 를
#   서브셸에서 설정해 부모로 전파되지 않았는데 정적 grep 은 PASS 했다). 훅을 실제로 실행해
#   deny 메시지를 검사한다.
_PT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
_bgtr=$(mktemp)
_BGOUT='/private/tmp/x/tasks/pbg2.output'
_BGSTUB="Command running in background with ID: pbg2. Output is being written to: ${_BGOUT}. You will be notified when it completes."
jq -nc --arg cmd 'bash scripts/tests/run-all.sh' \
  '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_PB1",name:"Bash",input:{command:$cmd}}]}}' > "$_bgtr"
jq -nc --arg out "$_BGSTUB" \
  '{type:"user",message:{role:"user",content:[{type:"tool_result",tool_use_id:"toolu_PB1",is_error:false,content:$out}]}}' >> "$_bgtr"
# ★ codesandbox 격리 — 실 repo working tree 가 docs-only dirty 이면 docs 면제로 allow 가 나와
#   위양성 FAIL 이 된다(Phase B 2회차 Important). 파일 상단 격리 규약을 동일 적용.
_bgres=$(CLAUDE_PROJECT_DIR="$codesandbox" mkstdin 'git commit -m "x"' "$_bgtr" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$_PT_ROOT/hooks/pretool-governance.sh" 2>&1)
check "P-bg2 bg 스텁만 있으면 미회수 구분 안내" '백그라운드 실행은 감지됐으나' "$_bgres"
check "P-bg2b 회수할 경로 안내" "$_BGOUT" "$_bgres"
rm -f "$_bgtr"

# T-cscope.a/b: R-1 커밋 게이트 스코프 축소 end-to-end (20260813-r1-docs-only-scope)
#   verify 증거 없는 픽스처를 써야 게이트가 실제로 판정한다(빈 transcript = fail-open allow).
_G=$(printf 'g%sit' ''); _C=$(printf 'c%sommit' '')
scopesandbox=$(mktemp -d) || exit 1
# 기존 trap(:40 codesandbox·allowsandbox)에 병합한다 — 스위트 중단 시 임시 디렉토리 누수 방지.
trap 'rm -rf "$codesandbox" "$allowsandbox" "${scopesandbox:-}" "${scopefid:-}"' EXIT
( cd "$scopesandbox" && git init -q && mkdir -p .specops \
  && echo "echo orig" > tracked.sh && git add tracked.sh \
  && git -c user.email=e@t -c user.name=t commit -q -m init \
  && echo doc > README.md && git add README.md \
  && echo "echo changed" > tracked.sh ) >/dev/null 2>&1

_out=$(mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$scopesandbox" bash "$HOOK" 2>&1)
check "T-cscope.a plain 커밋 → allow(AC-1 e2e)" '"continue":true' "$_out"

_out=$(mkstdin "$_G $_C -am x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$scopesandbox" bash "$HOOK" 2>&1)
check "T-cscope.b -am → deny 보존(AC-2 e2e)" 'deny' "$_out"

# T-cscope.c: 축소 적용 allow 시 info 1행 기록 + rule_id 가 R-1 이 아님 (AC-8)
#   ★ detect_fid(governance-lib.sh:52-57)는 .specops/session-progress.md 의 `## <FID>` 헤더를 읽는다.
#     sandbox 에 이 파일이 없으면 FID 가 빈 문자열이라 기록이 설계대로 생략돼 케이스가 영구 FAIL 한다.
scopefid=$(mktemp -d) || exit 1
( cd "$scopefid" && git init -q && mkdir -p .specops/20260101-scopetest \
  && printf '## 20260101-scopetest\n' > .specops/session-progress.md \
  && echo "echo orig" > tracked.sh && git add tracked.sh \
  && git -c user.email=e@t -c user.name=t commit -q -m init \
  && echo doc > README.md && git add README.md \
  && echo "echo changed" > tracked.sh ) >/dev/null 2>&1

mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$scopefid" bash "$HOOK" >/dev/null 2>&1
_log=$(cat "$scopefid"/.specops/*/friction-log.jsonl 2>/dev/null)
_hit=$(printf '%s' "$_log" | jq -s '[.[]|select(.severity=="info" and .rule_id!="R-1")]|length' 2>/dev/null || echo 0)
check "T-cscope.c info 기록 + R-1 미오염(AC-8)" '^1$' "$_hit"

# T-cscope.d: FID 미검출(session-progress.md 부재)에도 allow 는 성립 — 기록은 조용히 생략 (AC-8 후단)
_out=$(mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$scopesandbox" bash "$HOOK" 2>&1)
check "T-cscope.d FID 부재에도 allow(AC-8 후단)" '"continue":true' "$_out"
# T-cscope.e: 그 allow 가 기록을 남기지 않았음 — d 는 allow 만 보므로 로깅 블록이 통째로 없어도 통과한다.
#   AC-8 후단의 "조용히 생략" 절반은 이 줄이 잠근다 (파일 자체가 생기지 않아야 한다).
_none=$(ls "$scopesandbox"/.specops/*/friction-log.jsonl 2>/dev/null | wc -l | tr -d ' ')
check "T-cscope.e FID 부재 → 기록 생략(AC-8 후단)" '^0$' "$_none"
# 정리는 위 trap 이 담당한다 (중단 시에도 실행).

# T-fsc.a~d: scope_class 배선 e2e (20260813-friction-staged-record)
_G=$(printf 'g%sit' ''); _C=$(printf 'c%sommit' '')
_fsc_sandbox() {  # $1 staged(docs|code|none) → stdout=sandbox 경로
  local td; td=$(mktemp -d)
  ( cd "$td" && git init -q && mkdir -p .specops/20260101-fsc \
    && printf '## 20260101-fsc\n' > .specops/session-progress.md \
    && echo x > seed.md && git add seed.md \
    && git -c user.email=e@t -c user.name=t commit -q -m init
    case "$1" in docs) echo y > README.md; git add README.md ;;
                 code) echo y > app.sh; git add app.sh ;;
                 *) : ;; esac ) >/dev/null 2>&1
  printf '%s' "$td"
}
_fsc_class() {  # $1 sandbox  $2 rule_id → stdout=scope_class
  jq -r --arg r "$2" 'select(.rule_id==$r)|.scope_class // "ABSENT"' \
    "$1"/.specops/*/friction-log.jsonl 2>/dev/null | tail -1
}

# a~c: BYPASS-ENV 는 3값 전부 도달 가능 (AC-2)
for _st in docs code none; do
  case "$_st" in docs) _exp=docs-only ;; code) _exp=code ;; *) _exp=empty ;; esac
  _sb=$(_fsc_sandbox "$_st")
  mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
    | SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON=test \
      CLAUDE_PROJECT_DIR="$_sb" bash "$HOOK" >/dev/null 2>&1
  check "T-fsc BYPASS staged=$_st → $_exp (AC-2)" "^$_exp\$" "$(_fsc_class "$_sb" BYPASS-ENV)"
  rm -rf "$_sb"
done

# d: R-1 block 은 code (AC-3)
_sb=$(_fsc_sandbox code)
mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$_sb" bash "$HOOK" >/dev/null 2>&1
check "T-fsc.d R-1 block → code (AC-3)" '^code$' "$(_fsc_class "$_sb" R-1)"
_d_all=$(jq -r 'select(.rule_id=="R-1")|.scope_class // "ABSENT"' "$_sb"/.specops/*/friction-log.jsonl 2>/dev/null | sort -u | tr '\n' ',')
rm -rf "$_sb"

# e: block 지점에 docs-only 는 구조적으로 나올 수 없다 (AC-3 후단 — 나오면 버그 신호)
if printf '%s' "$_d_all" | grep -q 'docs-only'; then
  echo "FAIL T-fsc.e block 에 docs-only 출현 — :191 이 allow 했어야 함 (버그 신호)"; fail=$((fail+1))
else
  echo "PASS T-fsc.e block docs-only 미출현 (AC-3)"; pass=$((pass+1))
fi

# g: ★ 인라인 BYPASS 경로(:165) 배선 검증 — env 미설정 + 명령 내 인라인 토큰
#   T-fsc.a~c 는 env 를 세팅해 :56 세션-env 경로에서 단락되므로 :165 에 도달하지 않는다.
#   실측상 인라인 BYPASS 가 태스크 중간커밋의 지배 경로라(:213 주석), 이 배선이 빠지면
#   1차 표적의 최대 데이터원이 무검증으로 남는다(plan-reviewer 2회차 Important).
_sb=$(_fsc_sandbox docs)
mkstdin "SPECOPS_BYPASS_REASON=t SPECOPS_GOVERNANCE_BYPASS=1 $_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$_sb" bash "$HOOK" >/dev/null 2>&1
check "T-fsc.g 인라인 BYPASS(:165) → docs-only (AC-2)" '^docs-only$' "$(_fsc_class "$_sb" BYPASS-ENV)"
rm -rf "$_sb"

# f: staged·working-tree 모두 빈 상태 → empty (AC-3)
_sb=$(_fsc_sandbox none)
mkstdin "$_G $_C -m x" "$FIX/pretool-no-verify.jsonl" \
  | CLAUDE_PROJECT_DIR="$_sb" bash "$HOOK" >/dev/null 2>&1
check "T-fsc.f R-1 block staged 없음 → empty (AC-3)" '^empty$' "$(_fsc_class "$_sb" R-1)"
rm -rf "$_sb"

echo "==== Results: PASS=$pass FAIL=$fail ===="
[ "$fail" -eq 0 ]
