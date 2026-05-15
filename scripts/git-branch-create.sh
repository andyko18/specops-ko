#!/usr/bin/env bash
set -euo pipefail
FID="${1:?FID required}"
BRANCH="feat/$FID"
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
echo "branch: $BRANCH"
