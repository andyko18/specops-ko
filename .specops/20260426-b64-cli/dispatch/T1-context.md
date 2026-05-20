# Dispatch Context: T1 (FID 20260426-b64-cli)

> leaf subagent가 받는 5 컨텍스트. 부모(implementing-ko)가 dispatch 직전 작성.

## 1. 담당 AC

- AC-1: Given b64enc.sh 실행 권한 / When `b64enc.sh "hello"` / Then stdout `aGVsbG8=` + exit 0
- AC-2: Given b64enc.sh 실행 권한 / When `printf '%s' "hello" | b64enc.sh` / Then stdout `aGVsbG8=` + exit 0
- AC-3: Given b64enc.sh 실행 권한 / When `b64enc.sh --help` / Then usage 메시지 + exit 0
- AC-11: Given b64enc.sh 실행 권한 / When `b64enc.sh ""` / Then 빈 출력 + exit 0

## 2. 관련 spec.md 섹션

- `.specops/20260426-b64-cli/spec.md` §4 기능 요구사항 FR-1, FR-2
- `.specops/20260426-b64-cli/acceptance-criteria.md` AC-1, AC-2, AC-3, AC-11

## 3. 테스트 명령

```bash
bash scripts/tests/test-b64enc.sh
```

기대 출력: `PASS=5 FAIL=0`

## 4. 수정 허용 파일 (whitelist)

- `scripts/b64enc.sh`
- `scripts/tests/test-b64enc.sh`

> ⚠️ 위 외 파일 수정 금지. spec/AC/plan/tasks 같은 sprint contract은 read-only.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260426-b64-cli-T1/`

> ⚠️ leaf는 이 디렉터리 안에서만 작업. 부모 main worktree 직접 수정 금지.

---

## 구현 지시

다음 TDD 5스텝을 순서대로 실행한다:

**스텝 1 RED**: `scripts/tests/test-b64enc.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

```bash
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/b64enc.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T1.a: 인자 인코딩 "hello" → "aGVsbG8=" (AC-1)
out=$("$SCRIPT" "hello"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "aGVsbG8=" ] \
  && ok "T1.a 인자 인코딩" || fail "T1.a (rc=$rc out='$out')"

# T1.b: stdin 인코딩 (AC-2)
out=$(printf '%s' "hello" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "aGVsbG8=" ] \
  && ok "T1.b stdin 인코딩" || fail "T1.b (rc=$rc out='$out')"

# T1.c: --help → exit 0 + "Usage" 포함 (AC-3)
out=$("$SCRIPT" --help 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "Usage" \
  && ok "T1.c --help usage" || fail "T1.c (rc=$rc out='$out')"

# T1.d: 빈 인자 → 빈 출력 exit 0 (AC-11)
out=$("$SCRIPT" ""); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "" ] \
  && ok "T1.d 빈 문자열 exit 0" || fail "T1.d (rc=$rc out='$out')"

# T1.e: 공백 포함 문자열 (AC-1 확장)
expected=$(printf '%s' "hello world" | base64 | tr -d '\n')
out=$("$SCRIPT" "hello world"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "$expected" ] \
  && ok "T1.e 공백 포함 인코딩" || fail "T1.e (rc=$rc out='$out' expected='$expected')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
```

**스텝 2 FAIL 검증**: `bash scripts/tests/test-b64enc.sh` 실행 → FAIL 확인

**스텝 3 GREEN**: `scripts/b64enc.sh` 를 아래 내용으로 생성하고 `chmod +x` 부여:

```bash
#!/usr/bin/env bash
set -u

usage() {
  printf 'Usage: b64enc.sh [STRING]\n'
  printf '       echo STRING | b64enc.sh\n\n'
  printf 'Base64 encode a string (single-line output, no line wrapping).\n'
}

encode() {
  printf '%s' "$1" | base64 | tr -d '\n'
  printf '\n'
}

if [ $# -ge 1 ]; then
  case "$1" in
    --help) usage; exit 0 ;;
    *)      encode "$1" ;;
  esac
elif [ -t 0 ]; then
  usage; exit 1
else
  input=$(cat)
  encode "$input"
fi
```

**스텝 4 PASS 검증**: `bash scripts/tests/test-b64enc.sh` 실행 → `PASS=5 FAIL=0` 확인

**스텝 5 COMMIT**: 아래 명령으로 커밋:

```bash
git add scripts/b64enc.sh scripts/tests/test-b64enc.sh
git commit -m "feat(b64enc): Base64 인코더 CLI

인자+stdin 겸용, 한 줄 출력(줄바꿈 없음), --help.
빈 문자열 인코딩 exit 0.

관련 AC: AC-1, AC-2, AC-3, AC-11"
```
