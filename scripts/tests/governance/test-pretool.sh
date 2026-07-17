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

out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T1 commit no-verify → deny" '"permissionDecision":"deny"' "$out"
# T2: Skill 호출 + 실제 실행증거 = 정직한 경로 → allow
#   (20260713-verify-exec-gate fixture 보강 — 조임 후 Skill 호출'만'으로는 부족. 구 fixture 는 T2b 로 이관)
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify-exec.jsonl" | bash "$HOOK" 2>/dev/null)
check "T2 commit with-verify(+exec) → allow" '"continue":true' "$out"
# T2b ★ 조임 — Skill 호출만(실행증거 없음) → deny (구 T2 가 allow 하던 것)
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2b ★ Skill 호출만(실행증거 없음) → deny" '"permissionDecision":"deny"' "$out"
# T2c·T2d 심층 필터 통합 잠금 (verify-exec-gate 잔여 backlog — 단위 T9·T10 은 인라인 fixture 라
#   pretool 통합 경로(훅 전체 파이프)의 is_error·negative guard 배선은 별도 파일 fixture 로 잠근다)
out=$(mkstdin "git commit -m x" "$FIX/pretool-verify-exec-error.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2c 러너 is_error 결과(PASS 문자열) → deny (에러 실행 불인정)" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git commit -m x" "$FIX/pretool-verify-exec-partial-mixed.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T2d PASS/PARTIAL 혼재 출력 → deny (negative guard)" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 bash "$HOOK" 2>/dev/null)
check "T3 env bypass → allow" '"continue":true' "$out"
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

echo "==== Results: PASS=$pass FAIL=$fail ===="
[ "$fail" -eq 0 ]
