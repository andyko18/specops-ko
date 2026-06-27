#!/usr/bin/env bash
set -euo pipefail
FID="${1:?FID required}"
# FID 가드 — git ref 금지문자(공백·~·^·: 등) + 연속 점(..) 차단. emit-context.sh 규칙 + .. 보강
# 빈 슬러그(trailing dash = `YYYYMMDD-`) + 과길이(60자 초과)도 2차 차단 (LLM FID 생성 가드)
if ! printf '%s' "$FID" | grep -Eq '^[A-Za-z0-9._-]+$' \
   || printf '%s' "$FID" | grep -q '\.\.' \
   || printf '%s' "$FID" | grep -qE -- '-$' \
   || [ "${#FID}" -gt 60 ]; then
  echo "ERROR: invalid FID format: '$FID' (허용: A-Za-z0-9._- · '..'·trailing '-' 금지 · ≤60자)" >&2
  exit 1
fi
BRANCH="feat/$FID"
if git checkout -b "$BRANCH" 2>/dev/null; then
  echo "branch: $BRANCH"
else
  # 기존 브랜치 재사용 — 같은 FID 재진입(정당) 또는 슬러그 충돌(주의) 양쪽 가능. 무경고 덮어쓰기 방지 가시화(H1).
  echo "WARN: 기존 브랜치 '$BRANCH' 재사용 — 다른 기능이면 FID 슬러그를 바꿔 재실행" >&2
  git checkout "$BRANCH"
  echo "branch: $BRANCH (재사용)"
fi
