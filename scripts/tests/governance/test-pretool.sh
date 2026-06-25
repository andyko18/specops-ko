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
( cd "$codesandbox" && git init -q && echo "echo x" > a.sh && git add a.sh )
trap 'rm -rf "$codesandbox"' EXIT

out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T1 commit no-verify → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "git commit -m x" "$FIX/pretool-with-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T2 commit with-verify → allow" '"continue":true' "$out"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | SPECOPS_GOVERNANCE_BYPASS=1 bash "$HOOK" 2>/dev/null)
check "T3 env bypass → allow" '"continue":true' "$out"
out=$(mkstdin "gh pr create --fill" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T4 pr no-verify → deny" '"permissionDecision":"deny"' "$out"
out=$(mkstdin "ls -la" "$FIX/pretool-no-verify.jsonl" | bash "$HOOK" 2>/dev/null)
check "T5 unmatched → allow" '"continue":true' "$out"
out=$(printf 'NOT JSON' | bash "$HOOK" 2>/dev/null)
check "T6 bad json → allow" '"continue":true' "$out"
tmproot=$(mktemp -d) || exit 1
mkdir -p "$tmproot/.specops/20260101-auto-fixture"
printf '## 20260101-auto-fixture\n' > "$tmproot/.specops/session-progress.md"
printf '# spec\n**§auto**: true\n' > "$tmproot/.specops/20260101-auto-fixture/spec.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$tmproot" bash "$HOOK" 2>/dev/null)
check "T7 §auto exempt → allow" '"continue":true' "$out"
rm -rf "$tmproot"

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

# T16 docs-only(.md staged) → allow [면제, AC-R-1]
dgit=$(mktemp -d) || exit 1; ( cd "$dgit" && git init -q && echo x > CHANGELOG.md && git add CHANGELOG.md )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$dgit" bash "$HOOK" 2>/dev/null)
check "T16 docs-only → allow" '"continue":true' "$out"
rm -rf "$dgit"
# T17 코드 혼합(.md+.sh staged) → deny [보안 불변식, AC-R-2]
mgit=$(mktemp -d) || exit 1; ( cd "$mgit" && git init -q && echo x > a.md && echo y > b.sh && git add a.md b.sh )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$mgit" bash "$HOOK" 2>/dev/null)
check "T17 코드혼합 → deny" '"permissionDecision":"deny"' "$out"
rm -rf "$mgit"
# T18 staged docs + unstaged tracked 코드 + `git commit -am` → deny [commit -am 우회 차단, 보안 Critical]
agit=$(mktemp -d) || exit 1; ( cd "$agit" && git init -q && echo "echo orig" > tracked.sh && git add tracked.sh && git commit -q -m init
  echo doc > README.md && git add README.md && echo "echo changed" > tracked.sh )
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

# T36 inline prefix bypass → allow (F-2)
out=$(mkstdin "SPECOPS_GOVERNANCE_BYPASS=1 git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T36 inline bypass prefix → allow" '"continue":true' "$out"
# T37 메시지 내 토큰 언급은 면제 안 됨 → deny (F-2 우발면제 차단)
out=$(mkstdin 'git commit -m "docs SPECOPS_GOVERNANCE_BYPASS=1 flag"' "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$codesandbox" bash "$HOOK" 2>/dev/null)
check "T37 message token → deny" '"permissionDecision":"deny"' "$out"

# T38~T39 통합 wiring (F-1) — transcript 에 verify skill 부재(lookback 밖 시뮬)인데
# session-progress 에 /verify PASS 가 최신이면 ALLOW (positive), /implement 가 더 최신이면 deny (negative).
# spgit: 코드(.sh) staged 로 docs-only 면제 차단 + .specops/session-progress.md FID 섹션 주입.
# T38 positive: /verify PASS 가 /implement 보다 위(최신) → _verify_passed_in_progress=0 → allow
spgit=$(mktemp -d) || exit 1
( cd "$spgit" && git init -q && echo "echo x" > a.sh && git add a.sh && mkdir -p .specops )
printf '## 20260626-wire\n- 2026-06-26 10:05 /verify PASS (evidence.md, AC 5/5)\n- 2026-06-26 10:00 /implement DONE (T1)\n' > "$spgit/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$spgit" bash "$HOOK" 2>/dev/null)
check "T38 session-progress verify 최신 → allow (통합 positive)" '"continue":true' "$out"
# T39 negative: /implement 가 /verify 보다 위(최신) → 무효 → transcript fallback(verify 없음) → deny
printf '## 20260626-wire\n- 2026-06-26 10:10 /implement DONE (재구현)\n- 2026-06-26 10:05 /verify PASS (AC 5/5)\n' > "$spgit/.specops/session-progress.md"
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$spgit" bash "$HOOK" 2>/dev/null)
check "T39 session-progress implement 최신 → deny (R-1 보존)" '"permissionDecision":"deny"' "$out"
rm -rf "$spgit"

echo "==== Results: PASS=$pass FAIL=$fail ===="
[ "$fail" -eq 0 ]
