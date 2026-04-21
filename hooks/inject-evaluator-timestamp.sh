#!/usr/bin/env bash
# specops-ko v0.2 · post-evaluator hook
# Evaluator 산출물의 timestamp 플레이스홀더를 UTC ISO-8601로 치환
# 대상 패턴: "<YYYY-MM-DDTHH:MM:SSZ>" 또는 "<ISO8601>"
# 사용 예: hooks/inject-evaluator-timestamp.sh .specops/<FID>/analysis.md
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/is-hook-enabled.sh" inject-evaluator-timestamp || exit 0

if [ "$#" -ne 1 ]; then
  echo "usage: inject-evaluator-timestamp.sh <evaluator-artifact>" >&2
  exit 1
fi

f=$1
if [ ! -f "$f" ]; then
  echo "error: $f not found" >&2
  exit 1
fi

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp=$(mktemp)

# 두 placeholder 동시 치환. 이미 실제 값이 들어간 경우 match 되지 않아 noop.
sed -E \
  -e "s/\"<YYYY-MM-DDTHH:MM:SSZ>\"/\"${ts}\"/g" \
  -e "s/\"<ISO8601>\"/\"${ts}\"/g" \
  "$f" > "$tmp"

mv "$tmp" "$f"
echo "$ts"
