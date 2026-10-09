#!/usr/bin/env bash
# library-only — sourced by 거버넌스 테스트 스위트
# 실행 증거 픽스처를 **그 샌드박스의 FID** 것으로 만든다 (20261009).
#   transcript 픽스처의 러너는 `run-verification.sh 20260101-x` 인데, 다른 FID 의 PASS 는 이 FID 의 실행 증거가 아니다
#   (`_verify_exec_evidence` 의 fid_ok — test-pretool T-fidbind). 샌드박스의 활성 FID(active-fid 표지 → 첫 `## FID` 헤더 —
#   detect_fid 와 같은 순서)로 바꾼 사본 경로를 낸다. FID 가 없는 샌드박스는 원본 그대로다(FID 대조 자체가 없다).
# usage: _tr_for <샌드박스 루트> <픽스처 경로>  → stdout: transcript 경로
_TRF_DIR=$(mktemp -d) || exit 1
_tr_for() {
  local sp="$1/.specops/session-progress.md" f out
  f=$(grep -m1 -oE 'active-fid:[[:space:]]*[0-9]{8}-[a-z0-9-]+' "$sp" 2>/dev/null | grep -oE '[0-9]{8}-[a-z0-9-]+$')
  [ -n "$f" ] || f=$(grep -m1 -oE '^## [0-9]{8}-[a-z0-9-]+' "$sp" 2>/dev/null | sed 's/^## //')
  [ -n "$f" ] || { printf '%s' "$2"; return 0; }
  out="$_TRF_DIR/$(basename "$2" .jsonl).$f.jsonl"
  sed "s/20260101-x/$f/g" "$2" > "$out"; printf '%s' "$out"
}
