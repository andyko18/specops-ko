#!/usr/bin/env bash
set -euo pipefail
FID="${1:?FID required}"
# FID 가드 — git ref 금지문자(공백·~·^·:·.. 등) 차단. emit-context.sh 와 동일 규칙
if ! printf '%s' "$FID" | grep -Eq '^[A-Za-z0-9._-]+$'; then
  echo "ERROR: invalid FID format: '$FID' (허용: A-Za-z0-9._-)" >&2
  exit 1
fi
BRANCH="feat/$FID"
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
echo "branch: $BRANCH"
