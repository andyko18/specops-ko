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
codesandbox=$(mktemp -d)
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
tmproot=$(mktemp -d)
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
dgit=$(mktemp -d); ( cd "$dgit" && git init -q && echo x > CHANGELOG.md && git add CHANGELOG.md )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$dgit" bash "$HOOK" 2>/dev/null)
check "T16 docs-only → allow" '"continue":true' "$out"
rm -rf "$dgit"
# T17 코드 혼합(.md+.sh staged) → deny [보안 불변식, AC-R-2]
mgit=$(mktemp -d); ( cd "$mgit" && git init -q && echo x > a.md && echo y > b.sh && git add a.md b.sh )
out=$(mkstdin "git commit -m x" "$FIX/pretool-no-verify.jsonl" | CLAUDE_PROJECT_DIR="$mgit" bash "$HOOK" 2>/dev/null)
check "T17 코드혼합 → deny" '"permissionDecision":"deny"' "$out"
rm -rf "$mgit"
# T18 staged docs + unstaged tracked 코드 + `git commit -am` → deny [commit -am 우회 차단, 보안 Critical]
agit=$(mktemp -d); ( cd "$agit" && git init -q && echo "echo orig" > tracked.sh && git add tracked.sh && git commit -q -m init
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

echo "==== Results: PASS=$pass FAIL=$fail ===="
[ "$fail" -eq 0 ]
