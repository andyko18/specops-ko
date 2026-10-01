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

# T5.a .specops 디렉토리 symlink → 외부 write-through 차단 (#144 대칭)
work5="$TMP/work5"; outside5="$TMP/outside5"; mkdir -p "$work5" "$outside5"
(cd "$work5" && git init -q && git -c user.email=t@t.t -c user.name=t commit --allow-empty -m init -q)
ln -s "$outside5" "$work5/.specops"
echo "z" > "$work5/baz.sh"; (cd "$work5" && git add baz.sh)
tr5="$TMP/tr5.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"고쳐줘"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"baz.sh"}}]}}' > "$tr5"
out=$(echo "{\"transcript_path\":\"$tr5\",\"cwd\":\"$work5\"}" | bash "$HOOK" 2>/dev/null)
if echo "$out" | grep -q '"continue":true' && [ ! -f "$outside5/pending-capture.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T5.a .specops symlink write 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (외부 write 관통 또는 continue 아님)"
fi

# T5.b pending-capture.jsonl 파일 symlink → append 거부 (#144 대칭, 파일 벡터)
work6="$TMP/work6"; outside6="$TMP/outside6"; mkdir -p "$work6/.specops" "$outside6"
(cd "$work6" && git init -q && git -c user.email=t@t.t -c user.name=t commit --allow-empty -m init -q)
ln -s "$outside6/leak.jsonl" "$work6/.specops/pending-capture.jsonl"
echo "w" > "$work6/qux.sh"; (cd "$work6" && git add qux.sh)
tr6="$TMP/tr6.jsonl"
printf '%s\n' \
  '{"type":"user","message":{"content":[{"type":"text","text":"고쳐줘"}]}}' \
  '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"qux.sh"}}]}}' > "$tr6"
out=$(echo "{\"transcript_path\":\"$tr6\",\"cwd\":\"$work6\"}" | bash "$HOOK" 2>/dev/null)
if echo "$out" | grep -q '"continue":true' && [ ! -f "$outside6/leak.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T5.b pending 파일 symlink append 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.b (파일 symlink 관통)"
fi


# ═══ redact.sh 관문 · capture 훅 마스킹 (FID 20261001-redact-capture) ═══
# 가짜 시크릿은 실행 중에 조각을 이어 붙여 만든다 — 저장소에 실제 형태의 리터럴을 두지 않는다 (SAST self-check·gitleaks)
REDACT="$PLUGIN/scripts/_internal/redact.sh"
pass() { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1${2:+ — $2}"; }
rep() { local n=$1 c=$2 s="" i=0; while [ "$i" -lt "$n" ]; do s="$s$c"; i=$((i+1)); done; printf '%s' "$s"; }
K_AWS="AK""IA$(rep 16 A)"
K_GH="gh""p_$(rep 36 a)"
K_ANT="s""k-an""t-$(rep 24 c)"
K_OAI="s""k-$(rep 24 b)"
K_SLK="xo""xb-$(rep 12 1)"
K_JWT="ey""J$(rep 10 a).$(rep 10 b).$(rep 10 c)"
K_STR="s""k_li""ve_$(rep 20 d)"
K_GGL="AI""za$(rep 35 e)"
VQ=$(rep 12 q)   # 키=값 테스트의 값 — 리터럴이면 gitleaks generic-api-key 가 잡는다
PEM_B="-----BEG""IN RSA PRIVATE KEY-----"
PEM_E="-----END RSA PRIVATE KEY-----"
PRIV_O="<priv""ate>"
PRIV_C="</priv""ate>"

# T7.a 고정 시그니처 8종(PEM 은 T7.c) — 원문 부재 + 종류별 마커 + 주변 문장 보존 (AC-1)
in="앞문장 $K_AWS 중간 $K_GH 와 $K_ANT 그리고 $K_OAI 또 $K_SLK 그리고 $K_JWT 와 $K_STR 및 $K_GGL 뒷문장"
out=$(printf '%s' "$in" | bash "$REDACT" 2>/dev/null); rc=$?
ok=1; [ "$rc" -eq 0 ] || ok=0
for k in "$K_AWS" "$K_GH" "$K_ANT" "$K_OAI" "$K_SLK" "$K_JWT" "$K_STR" "$K_GGL"; do
  case "$out" in *"$k"*) ok=0 ;; esac
done
for m in aws github anthropic openai slack jwt stripe google; do
  case "$out" in *"[REDACTED:$m]"*) ;; *) ok=0 ;; esac
done
case "$out" in "앞문장 "*" 뒷문장") ;; *) ok=0 ;; esac
[ "$ok" -eq 1 ] && pass "T7.a 시그니처 8종 마스킹·주변 보존" || fail "T7.a" "rc=$rc out=$out"

# T7.b 키=값 휴리스틱·Bearer·URL 자격증명·CLI 플래그 (AC-2) — JSON 형태·달러 시작 비밀번호 포함. 값 없는 단어만 있는 문장은 불변
in="password=hunter2 secret: s3 api_key = $VQ token: ${VQ}x Authorization: Bearer ${VQ}${VQ} \"password\": \"hunter2\" 'api_key': '$VQ' password=\$up3rS3cret! DB_PASSWORD=abc secret_key=abc postgres://user:${VQ}@host/db --password hunter2 \"Authorization\": \"Bearer ${VQ}\""
out=$(printf '%s' "$in" | bash "$REDACT" 2>/dev/null)
ok=1
for v in hunter2 "$VQ" up3rS3cret "DB_PASSWORD=abc" "secret_key=abc"; do case "$out" in *"$v"*) ok=0 ;; esac; done
case "$out" in *"password="*"secret:"*"api_key"*"Bearer"*) ;; *) ok=0 ;; esac
plain2='password 는 비밀번호라는 뜻이고 token 이야기도 한다'
[ "$(printf '%s' "$plain2" | bash "$REDACT" 2>/dev/null)" = "$plain2" ] || ok=0
[ "$ok" -eq 1 ] && pass "T7.b 키=값·JSON·Bearer·URL·CLI 마스킹, 값 없는 문장 불변" || fail "T7.b" "out=$out"

# T7.c private 구간(닫힘·여러 줄·미닫힘·복수)·PEM 블록 제거 (AC-1 PEM · AC-3)
in=$(printf 'a %sS1\nS2%s b\n%sS3%s c %sS4\nS5' "$PRIV_O" "$PRIV_C" "$PRIV_O" "$PRIV_C" "$PRIV_O")
out=$(printf '%s' "$in" | bash "$REDACT" 2>/dev/null)
ok=1
for v in S1 S2 S3 S4 S5; do case "$out" in *"$v"*) ok=0 ;; esac; done
case "$out" in "a "*" b"*" c "*) ;; *) ok=0 ;; esac
inp=$(printf 'k %s\nMIIEdata\nabc\n%s z' "$PEM_B" "$PEM_E")
outp=$(printf '%s' "$inp" | bash "$REDACT" 2>/dev/null)
case "$outp" in *MIIEdata*) ok=0 ;; esac
case "$outp" in "k [REDACTED:pem]"*" z") ;; *) ok=0 ;; esac
inu=$(printf 'k %s\nQQQ\nRRR' "$PEM_B")
case "$(printf '%s' "$inu" | bash "$REDACT" 2>/dev/null)" in *QQQ*|*RRR*) ok=0 ;; esac
[ "$ok" -eq 1 ] && pass "T7.c private·PEM 구간 제거" || fail "T7.c" "out=$out | pem=$outp"

# T7.d 오탐 완화 + 멱등 (AC-9)
in="password=x secret: s3 api_key=$VQ token=abcd tk=\$TOKEN api_key={{KEY}} password=[REDACTED:kv]"
o1=$(printf '%s' "$in" | bash "$REDACT" 2>/dev/null)
o2=$(printf '%s' "$o1" | bash "$REDACT" 2>/dev/null)
ok=1
case "$o1" in *"password=[REDACTED:kv] secret: [REDACTED:kv] api_key=[REDACTED:kv] token=abcd tk=\$TOKEN api_key={{KEY}} password=[REDACTED:kv]") ;; *) ok=0 ;; esac
[ "$o1" = "$o2" ] || ok=0
[ "$ok" -eq 1 ] && pass "T7.d 키별 최소 길이·플레이스홀더 제외·멱등" || fail "T7.d" "o1=$o1"

# T7.e oversize — 스캔 없이 대체, 시간 상한 (AC-7)
big="$TMP/big.txt"; yes "$K_AWS token=$VQ" | head -c 1100000 > "$big"
t0=$(date +%s); out=$(bash "$REDACT" < "$big" 2>/dev/null); rc=$?; t1=$(date +%s)
[ "$rc" -eq 0 ] && [ "$out" = "[REDACTED:oversize]" ] && [ $((t1-t0)) -le 10 ] \
  && pass "T7.e 1.1MB oversize 대체" || fail "T7.e" "rc=$rc out=${out:0:40} sec=$((t1-t0))"

# T7.f 상한 이하·매치 수만 건도 선형 시간 (AC-7)
mid="$TMP/mid.txt"; yes "$K_AWS token=$VQ" | head -c 900000 > "$mid"
t0=$(date +%s); out=$(bash "$REDACT" < "$mid" 2>/dev/null); rc=$?; t1=$(date +%s)
case "$out" in *"$K_AWS"*) leak=1 ;; *) leak=0 ;; esac
[ "$rc" -eq 0 ] && [ "$leak" -eq 0 ] && [ -n "$out" ] && [ $((t1-t0)) -le 10 ] \
  && pass "T7.f 900KB 다수 매치 선형 시간" || fail "T7.f" "rc=$rc leak=$leak sec=$((t1-t0))"

# T7.g --max — 글자 단위 절단(한글 안 깨짐) + 마스킹 뒤에 자른다 (FR-6)
out=$(printf '%s' "$(rep 20 가)" | bash "$REDACT" --max 5 2>/dev/null)
ok=1; [ "$out" = "가가가가가…[TRUNCATED]" ] || ok=0
out2=$(printf '%s%s' "$(rep 7 x)" "$K_AWS" | bash "$REDACT" --max 12 2>/dev/null)
case "$out2" in *AKIA*) ok=0 ;; esac
[ "$ok" -eq 1 ] && pass "T7.g --max 글자 절단·선마스킹" || fail "T7.g" "out=$out out2=$out2"

# T7.h 평범한 입력은 바이트 단위 보존(개행 유무 포함) — 단어 속 sk-·Basic·secretary·PWD·total_tokens·평문 Authorization·환경변수 참조 음성 케이스
plain='평범한 한글 문장입니다 commit 0123456789abcdef0123456789abcdef01234567 token 이야기와 password 설명 task-20261001-redact-capture risk-adjusted-returns-for-the-quarter Basic authentication secretary: Kim PWD=/Users/x total_tokens: 15000000 Authorization: required passwords: 3개 password=$TOKEN password=${TOKEN} api_key={{KEY}}'
ok=1
printf '%s' "$plain" | bash "$REDACT" 2>/dev/null | cmp -s - <(printf '%s' "$plain") || ok=0
printf 'a\nb\n' | bash "$REDACT" 2>/dev/null | cmp -s - <(printf 'a\nb\n') || ok=0
[ "$ok" -eq 1 ] && pass "T7.h 평범한 입력 바이트 보존" || fail "T7.h"

# T7.i 마스킹 불가 → rc 3·stdout 비움: 패턴 파일 부재, 패턴 문법 오류(sed 실패) · 인자 오류 rc 2 (FR-1 · AC-6)
np="$TMP/np"; mkdir -p "$np"; cp "$REDACT" "$np/redact.sh" 2>/dev/null   # 패턴 파일은 일부러 복사하지 않는다
out=$(printf 'x' | bash "$np/redact.sh" 2>/dev/null); rc=$?
np2="$TMP/np2"; mkdir -p "$np2"; cp "$REDACT" "$np2/redact.sh" 2>/dev/null; printf 's/(/x/\n' > "$np2/redact-patterns.sed"
out2=$(printf 'x' | bash "$np2/redact.sh" 2>/dev/null); rc3=$?
bash "$REDACT" --max abc </dev/null >/dev/null 2>&1; rc2=$?
[ "$rc" -eq 3 ] && [ -z "$out" ] && [ "$rc3" -eq 3 ] && [ -z "$out2" ] && [ "$rc2" -eq 2 ] \
  && pass "T7.i 패턴 부재·문법 오류 rc3·인자 오류 rc2" || fail "T7.i" "rc=$rc rc3=$rc3 rc2=$rc2"

# T7.j jq 부재 — --max 는 rc 3(fail-closed), --max 없으면 jq 불필요 (Q3)
nj="$TMP/nojq-bin"; mkdir -p "$nj"
for t in wc tr od awk sed mktemp tail head cat cp rm dirname; do ln -sf "$(command -v "$t")" "$nj/$t"; done
out=$(printf 'abcdef' | PATH="$nj" /bin/bash "$REDACT" --max 3 2>/dev/null); rc=$?
out2=$(printf 'abcdef' | PATH="$nj" /bin/bash "$REDACT" 2>/dev/null); rc2=$?
[ "$rc" -eq 3 ] && [ -z "$out" ] && [ "$rc2" -eq 0 ] && [ "$out2" = "abcdef" ] \
  && pass "T7.j jq 부재: --max rc3 · 무상한 통과" || fail "T7.j" "rc=$rc rc2=$rc2 out2=$out2"

# T7.k --last-line — 마스킹이 끝난 뒤 마지막 줄만 남긴다: 줄 자르기가 앞서면 여러 줄 private 구간이 샌다 (FR-6·AC-4 선행)
in=$(printf 'a %sS1\nS2%s end' "$PRIV_O" "$PRIV_C")
out=$(printf '%s\n' "$in" | bash "$REDACT" --last-line 2>/dev/null)
[ "$out" = " end" ] && pass "T7.k --last-line 마스킹 뒤 마지막 줄" || fail "T7.k" "out=$out"
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
