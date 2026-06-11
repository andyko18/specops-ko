#!/usr/bin/env bash
# 학습 환류 루프 — gitignore 영속성 + skill 본문 통합 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

# T3.a learnings.jsonl 은 ignore 대상 아님 (영속 자산 — AC-11)
if git -C "$PLUGIN" check-ignore -q .specops/memory/learnings.jsonl; then
  FAIL=$((FAIL+1)); echo "FAIL T3.a learnings.jsonl 이 여전히 ignore 됨"
else
  PASS=$((PASS+1)); echo "PASS T3.a learnings.jsonl 비-ignore"
fi

# T3.b 일반 FID 산출물은 여전히 ignore (배포 불포함 규약 유지)
if git -C "$PLUGIN" check-ignore -q .specops/20990101-future/spec.md; then
  PASS=$((PASS+1)); echo "PASS T3.b FID 산출물 ignore 유지"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b FID 산출물이 ignore 안 됨"
fi

# T3.c memory 내 다른 파일은 ignore (learnings 만 예외)
if git -C "$PLUGIN" check-ignore -q .specops/memory/other-file.md; then
  PASS=$((PASS+1)); echo "PASS T3.c memory 기타 파일 ignore 유지"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.c memory 기타 파일이 ignore 안 됨"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
