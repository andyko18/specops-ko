#!/usr/bin/env bash
# 태스크 receipt 게이트 판정.
# Usage: check-task-receipt.sh <FID> <task-id>
# Exit: 0=면제 가능 · 1=receipt 있으나 무효(deny) · 2=부재/판정불가(legacy fallthrough)
set -u

FID="${1:-}"; TASK="${2:-}"
[ -n "$FID" ] && [ -n "$TASK" ] || { echo "usage: $0 <FID> <task-id>" >&2; exit 2; }

printf '%s' "$FID" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || exit 2
printf '%s' "$TASK" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$' || exit 2

SPECOPS="${SPECOPS_ROOT:-.specops}"
receipt="$SPECOPS/$FID/receipts/$TASK.json"
[ -f "$receipt" ] || exit 2
[ -L "$receipt" ] && { echo "check-task-receipt: receipt symlink 거부" >&2; exit 1; }

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=/dev/null
source "$PLUGIN/scripts/dag/parse-dag.sh"
# shellcheck source=/dev/null
source "$PLUGIN/scripts/_internal/verification-state.sh"

verdict=$(jq -r '.verdict // empty' "$receipt" 2>/dev/null) || exit 1
rfid=$(jq -r '.fid // empty' "$receipt" 2>/dev/null) || exit 1
rtask=$(jq -r '.task // empty' "$receipt" 2>/dev/null) || exit 1
[ "$verdict" = "PASS" ] || { echo "check-task-receipt: verdict!=PASS" >&2; exit 1; }
[ "$rfid" = "$FID" ] && [ "$rtask" = "$TASK" ] || { echo "check-task-receipt: fid/task mismatch" >&2; exit 1; }

TASKS="$SPECOPS/$FID/tasks.md"
[ -f "$TASKS" ] || { echo "check-task-receipt: tasks.md 부재" >&2; exit 1; }
yaml=$(dag::extract_yaml "$TASKS")
cur_cmd=$(dag::get_task_test_command "$yaml" "$TASK" 2>/dev/null)
[ -n "$cur_cmd" ] || { echo "check-task-receipt: test_command 없음" >&2; exit 1; }
cur_hash=$(printf '%s' "$cur_cmd" | git hash-object --stdin 2>/dev/null) \
  || cur_hash=$(printf '%s' "$cur_cmd" | shasum -a 256 | awk '{print $1}')
rec_hash=$(jq -r '.test_command_hash // empty' "$receipt")
[ "$cur_hash" = "$rec_hash" ] || { echo "check-task-receipt: test_command drift" >&2; exit 1; }

# staged ⊆ outputs (공집합 staged 거부). bash 3.2 호환 — mapfile 미사용.
staged=$(git diff --cached --name-only --no-renames 2>/dev/null || true)
[ -n "$staged" ] || { echo "check-task-receipt: staged empty" >&2; exit 1; }
outs=$(jq -r '.outputs[]?' "$receipt" 2>/dev/null)
[ -n "$outs" ] || { echo "check-task-receipt: outputs empty" >&2; exit 1; }
while IFS= read -r f; do
  [ -z "$f" ] && continue
  printf '%s\n' "$outs" | grep -Fxq -- "$f" \
    || { echo "check-task-receipt: staged outside outputs: $f" >&2; exit 1; }
done <<< "$staged"

rec_tree=$(jq -r '.tree_hash // empty' "$receipt")
cur_tree=$(vs::workspace_fingerprint)
[ -n "$rec_tree" ] && [ "$rec_tree" = "$cur_tree" ] \
  || { echo "check-task-receipt: tree stale" >&2; exit 1; }

exit 0
