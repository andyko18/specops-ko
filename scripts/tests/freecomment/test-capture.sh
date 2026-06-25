#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
HOOK="$PLUGIN/hooks/freecomment-capture.sh"
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# T1.a 변경 없는 세션 → continue:true + pending 미생성 (AC-2)
tr_empty="$TMP/empty.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}' > "$tr_empty"
out=$(echo "{\"transcript_path\":\"$tr_empty\",\"cwd\":\"$TMP\"}" | bash "$HOOK" 2>/dev/null)
if echo "$out" | grep -q '"continue":true' && [ ! -f "$TMP/.specops/pending-capture.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a 변경없음 skip"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (out=$out)"
fi

# T1.b 손상 transcript → fail-open continue:true (AC-7)
out=$(echo '{"transcript_path":"/nonexistent","cwd":"'"$TMP"'"}' | bash "$HOOK" 2>/dev/null)
if echo "$out" | grep -q '"continue":true'; then
  PASS=$((PASS+1)); echo "PASS T1.b fail-open"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (out=$out)"
fi

# T2.a 자유작업 감지 → pending stub 기록 + type 분류 (AC-3)
work="$TMP/work"; mkdir -p "$work"
(cd "$work" && git init -q && git -c user.email=test@specops.test -c user.name=test commit --allow-empty -m init -q)
echo "x" > "$work/foo.sh"
(cd "$work" && git add foo.sh)
tr2="$TMP/tr2.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"이 버그 고쳐줘"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"foo.sh"}}]}}' > "$tr2"
echo "{\"transcript_path\":\"$tr2\",\"cwd\":\"$work\"}" | bash "$HOOK" 2>/dev/null
if [ -f "$work/.specops/pending-capture.jsonl" ] && \
   grep -q '"type":"fix"' "$work/.specops/pending-capture.jsonl"; then
  PASS=$((PASS+1)); echo "PASS T2.a pending stub + type=fix"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a"
fi

# T2.b 공백 파일명 → files_json 에 정확히 1항목 (분할 안 됨)
work2="$TMP/work2"; mkdir -p "$work2"
(cd "$work2" && git init -q && git -c user.email=test@specops.test -c user.name=test commit --allow-empty -m init -q)
printf 'x' > "$work2/a b.sh"
(cd "$work2" && git add "a b.sh")
tr2b="$TMP/tr2b.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"고쳐줘"}]}}' \
  "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"$work2/a b.sh\"}}]}}" > "$tr2b"
echo "{\"transcript_path\":\"$tr2b\",\"cwd\":\"$work2\"}" | bash "$HOOK" 2>/dev/null
if [ -f "$work2/.specops/pending-capture.jsonl" ]; then
  count=$(jq -r '.files | length' "$work2/.specops/pending-capture.jsonl" 2>/dev/null)
  first=$(jq -r '.files[0]' "$work2/.specops/pending-capture.jsonl" 2>/dev/null)
  if [ "$count" = "1" ] && [ "$first" = "a b.sh" ]; then
    PASS=$((PASS+1)); echo "PASS T2.b 공백파일명 1항목"
  else
    FAIL=$((FAIL+1)); echo "FAIL T2.b (count=$count first=$first)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b pending 미생성"
fi

# T2.c substring 오탐 방지 — changed=app.sh, edit=pp.sh → pending 미생성
work3="$TMP/work3"; mkdir -p "$work3"
(cd "$work3" && git init -q && git -c user.email=test@specops.test -c user.name=test commit --allow-empty -m init -q)
printf 'x' > "$work3/app.sh"
(cd "$work3" && git add app.sh)
tr2c="$TMP/tr2c.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"수정"}]}}' \
  "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"input\":{\"file_path\":\"$work3/pp.sh\"}}]}}" > "$tr2c"
echo "{\"transcript_path\":\"$tr2c\",\"cwd\":\"$work3\"}" | bash "$HOOK" 2>/dev/null
if [ ! -f "$work3/.specops/pending-capture.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T2.c substring 오탐 없음"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.c (pending 생성됨 — 오탐)"
fi

# T4.a fid 필드 존재 — detect_fid 결과 기록 (AC-1, AC-2)
work4="$TMP/work4"; mkdir -p "$work4"
(cd "$work4" && git init -q && git -c user.email=t@t.t -c user.name=t commit --allow-empty -m init -q)
mkdir -p "$work4/.specops"
printf '## 20260625-live\n- 2026-06-25 10:00 /implement 진행\n' > "$work4/.specops/session-progress.md"
echo "y" > "$work4/bar.sh"; (cd "$work4" && git add bar.sh)
tr4="$TMP/tr4.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"리팩터"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"bar.sh"}}]}}' > "$tr4"
echo "{\"transcript_path\":\"$tr4\",\"cwd\":\"$work4\"}" | bash "$HOOK" 2>/dev/null
got=$(jq -r '.fid' "$work4/.specops/pending-capture.jsonl" 2>/dev/null)
if [ "$got" = "20260625-live" ]; then
  PASS=$((PASS+1)); echo "PASS T4.a fid 필드=$got"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (fid=$got)"
fi

echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
